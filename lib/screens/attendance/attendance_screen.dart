import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/theme.dart';
import '../../data/repository.dart';
import '../../data/attendance_logic.dart';
import '../../l10n/app_strings.dart';
import '../../models/attendance.dart';
import '../../models/group.dart';

/// 그룹별 출석 화면. 내 그룹의 출석일에만 출석 가능.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  Future<AttendanceSummary>? _future;
  bool _checking = false;
  List<DateTime> _dates = [];
  Map<String, String> _topics = {}; // 날짜키 → 주제
  Map<String, Rsvp> _rsvp = {};
  List<GroupInfo> _groups = [];
  String? _gid;
  bool _loadingGroups = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    List<GroupInfo> groups = [];
    try {
      groups = await context.read<AppRepository>().fetchMyGroups();
    } catch (_) {
      // 실패해도 무한로딩되지 않도록 빈 목록으로 처리.
    }
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _gid = groups.isNotEmpty ? groups.first.id : null;
      _loadingGroups = false;
    });
    if (_gid != null) _reload();
  }

  void _reload() {
    final gid = _gid;
    if (gid == null) return;
    final repo = context.read<AppRepository>();
    _future = repo.fetchMyGroupAttendance(gid);
    repo.fetchGroupSchedule(gid).then((entries) {
      if (!mounted) return;
      setState(() {
        _dates = entries.map((e) => e.date).toList();
        _topics = {
          for (final e in entries)
            AttendanceRecord.keyOf(e.date): e.topic,
        };
      });
    });
    repo.fetchMyRsvp(gid).then((r) {
      if (mounted) setState(() => _rsvp = r);
    });
  }

  /// 참석/불참 응답 다이얼로그.
  Future<void> _openRsvp(DateTime day) async {
    final gid = _gid;
    if (gid == null) return;
    final key = AttendanceRecord.keyOf(AttendanceRecord.dayOf(day));
    final existing = _rsvp[key];
    bool available = existing?.available ?? true;
    final reasonCtrl = TextEditingController(text: existing?.reason ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setLocal) => AlertDialog(
          title: Text(tr(context, 'rsvp_title',
              {'date': DateFormat('M/d (E)', 'ko').format(day)})),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(tr(context, 'rsvp_available'))),
                  ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: Text(tr(context, 'rsvp_unavailable'))),
                ],
                selected: {available},
                onSelectionChanged: (s) => setLocal(() => available = s.first),
              ),
              if (!available) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: tr(context, 'rsvp_reason'),
                    hintText: tr(context, 'rsvp_reason_hint'),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dctx, false),
                child: Text(tr(context, 'cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(dctx, true),
                child: Text(tr(context, 'save'))),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    await context.read<AppRepository>().setRsvp(
        gid, day, available, available ? '' : reasonCtrl.text);
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'rsvp_saved'))));
  }

  bool get _todayScheduled =>
      _dates.contains(AttendanceRecord.dayOf(DateTime.now()));

  /// 오늘 이후의 가장 가까운 출석일.
  DateTime? get _nextScheduled {
    final today = AttendanceRecord.dayOf(DateTime.now());
    final upcoming = _dates.where((d) => !d.isBefore(today)).toList()..sort();
    return upcoming.isEmpty ? null : upcoming.first;
  }

  Future<void> _checkIn() async {
    final gid = _gid;
    if (gid == null) return;
    setState(() => _checking = true);
    final repo = context.read<AppRepository>();
    try {
      final ok = await repo.checkInGroupToday(gid);
      if (!mounted) return;
      final summary = await repo.fetchMyGroupAttendance(gid);
      if (!mounted) return;

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(context, 'already_checked'))));
      } else {
        final reached = summary.currentStreak == AttendanceLogic.coffeeStreak;
        if (reached) {
          _showRewardDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(tr(context, 'checkin_success',
                    {'n': '${summary.currentStreak}'}))),
          );
        }
      }
      setState(_reload);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showRewardDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Text('☕', style: TextStyle(fontSize: 40)),
        title: Text(tr(context, 'coffee_achieved_title')),
        content: Text(tr(context, 'coffee_achieved_body',
            {'n': '${AttendanceLogic.coffeeStreak}'})),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'ok_great')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tiers = context.read<AppRepository>().rewardTiers;
    return Scaffold(
      appBar: AppBar(
          title: Text(tr(context, 'attendance_appbar'),
              style: const TextStyle(fontWeight: FontWeight.bold))),
      body: _buildBody(context, tiers),
    );
  }

  Widget _buildBody(BuildContext context, List<RewardTier> tiers) {
    if (_loadingGroups) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(tr(context, 'no_group_join_first'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }
    return FutureBuilder<AttendanceSummary>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting ||
              _future == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(tr(context, 'attendance_error'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
            );
          }
          final s = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_groups.length > 1) ...[
                  _GroupSelector(
                    groups: _groups,
                    selected: _gid,
                    onChanged: (v) => setState(() {
                      _gid = v;
                      _dates = [];
                      _topics = {};
                      _rsvp = {};
                      _reload();
                    }),
                  ),
                  const SizedBox(height: 16),
                ],
                _StreakCard(summary: s),
                const SizedBox(height: 16),
                _ScheduleCard(
                  dates: _dates,
                  topics: _topics,
                  attended: s.recentDays,
                  rsvp: _rsvp,
                  onTapDate: _openRsvp,
                ),
                const SizedBox(height: 16),
                _CalendarCard(summary: s, scheduled: _dates),
                const SizedBox(height: 16),
                _ProgressCard(summary: s, tiers: tiers),
                const SizedBox(height: 16),
                _CheckInButton(
                  checkedIn: s.checkedInToday,
                  loading: _checking,
                  scheduled: _todayScheduled,
                  nextDateLabel: _nextScheduled == null
                      ? null
                      : DateFormat('M/d (E)', 'ko').format(_nextScheduled!),
                  onTap: _checkIn,
                ),
                const SizedBox(height: 24),
                _InfoNote(),
              ],
            ),
          );
        },
      );
  }
}

/// 여러 그룹에 속한 경우 그룹 선택 드롭다운.
class _GroupSelector extends StatelessWidget {
  const _GroupSelector(
      {required this.groups, required this.selected, required this.onChanged});
  final List<GroupInfo> groups;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: InputDecoration(
        labelText: tr(context, 'my_group'),
        filled: true,
        fillColor: Colors.white,
      ),
      items: groups
          .map((g) => DropdownMenuItem(value: g.id, child: Text(g.name)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// 멘토가 잡아둔 출석 일정 + 참석 응답(RSVP). 날짜를 탭하면 참석/불참 응답.
class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.dates,
    required this.topics,
    required this.attended,
    required this.rsvp,
    required this.onTapDate,
  });
  final List<DateTime> dates;
  final Map<String, String> topics;
  final List<DateTime> attended;
  final Map<String, Rsvp> rsvp;
  final void Function(DateTime day) onTapDate;

  @override
  Widget build(BuildContext context) {
    if (dates.isEmpty) return const SizedBox.shrink();
    final today = AttendanceRecord.dayOf(DateTime.now());
    final attendedSet = attended.map(AttendanceRecord.dayOf).toSet();
    final sorted = [...dates]..sort();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note, size: 18, color: AppTheme.brand600),
              const SizedBox(width: 6),
              Text(tr(context, 'attendance_schedule'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...sorted.map((d) {
            final done = attendedSet.contains(d);
            final isToday = d == today;
            final key = AttendanceRecord.keyOf(d);
            final r = rsvp[key];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onTapDate(d),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppTheme.brandTonal
                        : const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isToday
                            ? AppTheme.brand200
                            : const Color(0xFFEEEEEE)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        done
                            ? Icons.check_circle
                            : Icons.calendar_today_outlined,
                        size: 16,
                        color: done ? AppTheme.brand600 : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('M/d (E)', 'ko').format(d),
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                            if ((topics[key] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(topics[key]!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _rsvpBadge(context, r),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right,
                          size: 18, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (sorted.any((d) {
            final r = rsvp[AttendanceRecord.keyOf(d)];
            return r != null && !r.available && r.reason.isNotEmpty;
          }))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: sorted
                    .where((d) {
                      final r = rsvp[AttendanceRecord.keyOf(d)];
                      return r != null && !r.available && r.reason.isNotEmpty;
                    })
                    .map((d) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${DateFormat('M/d', 'ko').format(d)} 불참: ${rsvp[AttendanceRecord.keyOf(d)]!.reason}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rsvpBadge(BuildContext context, Rsvp? r) {
    late Color fg;
    late Color bg;
    late String text;
    if (r == null) {
      fg = const Color(0xFF9CA3AF);
      bg = const Color(0xFFF4F4F5);
      text = tr(context, 'rsvp_none');
    } else if (r.available) {
      fg = AppTheme.brandOnTonal;
      bg = AppTheme.brandTonal;
      text = tr(context, 'rsvp_available');
    } else {
      fg = const Color(0xFFE53E3E);
      bg = const Color(0xFFFFF0F0);
      text = tr(context, 'rsvp_unavailable');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.summary});
  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final streak = summary.currentStreak;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF24B57A), AppTheme.brand600],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brand500.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      streak > 0
                          ? tr(context, 'streak_now', {'n': '$streak'})
                          : tr(context, 'streak_start'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(tr(context, 'total_days', {'n': '${summary.totalDays}'}),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_fire_department,
                    color: AppTheme.streakFlame, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _StreakTrack(streak: streak),
        ],
      ),
    );
  }
}

/// 스트릭 노드 트랙 (칸 수는 고정, 커피 보상 지점만 표시).
class _StreakTrack extends StatelessWidget {
  const _StreakTrack({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final trackDays = AttendanceLogic.streakTrackDays;
    final rewardIndex = AttendanceLogic.coffeeStreak - 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(trackDays, (i) {
        final done = i < streak;
        final isReward = i == rewardIndex;
        return Column(
          children: [
            Container(
              width: isReward ? 34 : 28,
              height: isReward ? 34 : 28,
              decoration: BoxDecoration(
                color: isReward
                    ? AppTheme.streakFlame
                    : (done
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.18)),
                shape: BoxShape.circle,
                border: !done && !isReward
                    ? Border.all(color: Colors.white.withValues(alpha: 0.35))
                    : null,
              ),
              child: Icon(
                isReward ? Icons.local_cafe : Icons.check,
                size: isReward ? 17 : 14,
                color: isReward
                    ? const Color(0xFF854D0E)
                    : (done ? AppTheme.brand600 : Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isReward
                  ? tr(context, 'reward')
                  : tr(context, 'day_n', {'n': '${i + 1}'}),
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    done || isReward ? FontWeight.bold : FontWeight.w500,
                color: isReward
                    ? AppTheme.streakFlame
                    : Colors.white.withValues(alpha: done ? 1 : 0.6),
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// 출석일 + 예정일을 달력에 표시.
class _CalendarCard extends StatefulWidget {
  const _CalendarCard({required this.summary, this.scheduled = const []});
  final AttendanceSummary summary;
  final List<DateTime> scheduled;

  @override
  State<_CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<_CalendarCard> {
  DateTime _focused = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final attended = widget.summary.recentDays
        .map(AttendanceRecord.dayOf)
        .toSet();
    final scheduledSet =
        widget.scheduled.map(AttendanceRecord.dayOf).toSet();
    final today = AttendanceRecord.dayOf(DateTime.now());

    bool isAttended(DateTime day) =>
        attended.contains(AttendanceRecord.dayOf(day));
    bool isScheduled(DateTime day) =>
        scheduledSet.contains(AttendanceRecord.dayOf(day));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          children: [
            TableCalendar<void>(
              locale: 'ko_KR',
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2100, 12, 31),
              focusedDay: _focused,
              currentDay: today,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                    fontFamily: 'Pretendard', fontWeight: FontWeight.w600),
                weekendStyle: TextStyle(
                    fontFamily: 'Pretendard', fontWeight: FontWeight.w600),
              ),
              calendarStyle: const CalendarStyle(
                defaultTextStyle: TextStyle(fontFamily: 'Pretendard'),
                weekendTextStyle: TextStyle(fontFamily: 'Pretendard'),
                outsideTextStyle: TextStyle(
                    fontFamily: 'Pretendard', color: Color(0xFFBDBDBD)),
              ),
              availableGestures: AvailableGestures.horizontalSwipe,
              onPageChanged: (day) => _focused = day,
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  if (isAttended(day)) {
                    return _attendedCell(day, primary);
                  }
                  if (isScheduled(day)) {
                    // 출석 예정일: 점선 느낌의 옅은 원형 강조.
                    return Center(
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.brandTonal,
                          border: Border.all(
                              color: AppTheme.brand200, width: 1),
                        ),
                        child: Text('${day.day}',
                            style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w600,
                                color: AppTheme.brandOnTonal)),
                      ),
                    );
                  }
                  return null;
                },
                todayBuilder: (context, day, focusedDay) {
                  if (isAttended(day)) {
                    return _attendedCell(day, primary, isToday: true);
                  }
                  return Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: primary, width: 1.5),
                      ),
                      child: Text('${day.day}',
                          style: const TextStyle(fontFamily: 'Pretendard')),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                Text(tr(context, 'attended_day'),
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attendedCell(DateTime day, Color color, {bool isToday = false}) {
    return Center(
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isToday
              ? Border.all(color: AppTheme.brand900, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '${day.day}',
          style: const TextStyle(
              fontFamily: 'Pretendard',
              color: Colors.white,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.summary, required this.tiers});
  final AttendanceSummary summary;
  final List<RewardTier> tiers;

  @override
  Widget build(BuildContext context) {
    final target = AttendanceLogic.coffeeStreak;
    final current = summary.currentStreak.clamp(0, target);
    final progress = target == 0 ? 0.0 : current / target;
    final remaining = (target - summary.currentStreak).clamp(0, target);
    final achieved = summary.currentStreak >= target;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.brandTonal.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.brand500.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.card_giftcard,
                size: 28, color: AppTheme.brand500),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(tr(context, 'coffee_goal'),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF18181B))),
                    ),
                    Text(
                        tr(context, 'count_of',
                            {'c': '$current', 't': '$target'}),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.brand600)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  achieved
                      ? tr(context, 'coffee_ready')
                      : tr(context, 'coffee_hint', {
                          'goal': '${AttendanceLogic.coffeeStreak}',
                          'n': '$remaining'
                        }),
                  style: TextStyle(
                      fontSize: 11.5,
                      color: achieved
                          ? AppTheme.brand600
                          : Colors.grey.shade600,
                      fontWeight:
                          achieved ? FontWeight.bold : FontWeight.normal),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white,
                    valueColor:
                        const AlwaysStoppedAnimation(AppTheme.brand500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInButton extends StatelessWidget {
  const _CheckInButton({
    required this.checkedIn,
    required this.loading,
    required this.scheduled,
    required this.nextDateLabel,
    required this.onTap,
  });
  final bool checkedIn;
  final bool loading;
  final bool scheduled;
  final String? nextDateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (checkedIn) {
      return FilledButton.icon(
        onPressed: null,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.brandTonal,
          disabledBackgroundColor: AppTheme.brandTonal,
          disabledForegroundColor: AppTheme.brandOnTonal,
        ),
        icon: const Icon(Icons.check_circle),
        label: Text(tr(context, 'checked_done'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      );
    }
    // 오늘이 등록된 출석일이 아니면 비활성 + 안내.
    if (!scheduled) {
      return Column(
        children: [
          FilledButton.icon(
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF4F4F5),
              disabledBackgroundColor: const Color(0xFFF4F4F5),
              disabledForegroundColor: const Color(0xFF9CA3AF),
            ),
            icon: const Icon(Icons.event_busy),
            label: Text(tr(context, 'not_attendance_day'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (nextDateLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              tr(context, 'next_attendance_date', {'date': nextDateLabel!}),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.brand600),
            ),
          ],
        ],
      );
    }
    return FilledButton.icon(
      onPressed: loading ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.brand500,
        foregroundColor: Colors.white,
      ),
      icon: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.touch_app),
      label: Text(tr(context, 'check_in_today'),
          style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _InfoNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr(context, 'attendance_note'),
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
