import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/theme.dart';
import '../../data/repository.dart';
import '../../data/attendance_logic.dart';
import '../../models/attendance.dart';

/// 연속 출석 & 커피 보상 화면.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late Future<AttendanceSummary> _future;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<AppRepository>().fetchAttendance();
  }

  Future<void> _checkIn() async {
    setState(() => _checking = true);
    final repo = context.read<AppRepository>();
    try {
      final ok = await repo.checkInToday();
      if (!mounted) return;
      final summary = await repo.fetchAttendance();
      if (!mounted) return;

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('오늘은 이미 출석했습니다.')));
      } else {
        final reached = summary.currentStreak == AttendanceLogic.coffeeStreak;
        if (reached) {
          _showRewardDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '출석 완료! 연속 ${summary.currentStreak}일째 🎉')),
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
        title: const Text('커피 보상 달성!'),
        content: Text(
            '${AttendanceLogic.coffeeStreak}일 연속 출석을 달성했어요!\n'
            '학과 사무실에서 커피 기프티콘을 받아가세요.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('좋아요!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tiers = context.read<AppRepository>().rewardTiers;
    return Scaffold(
      appBar: AppBar(title: const Text('출석 체크')),
      body: FutureBuilder<AttendanceSummary>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('출석 정보를 불러오지 못했습니다.',
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
                _StreakCard(summary: s),
                const SizedBox(height: 16),
                _CalendarCard(summary: s),
                const SizedBox(height: 16),
                _ProgressCard(summary: s, tiers: tiers),
                const SizedBox(height: 16),
                _CheckInButton(
                  checkedIn: s.checkedInToday,
                  loading: _checking,
                  onTap: _checkIn,
                ),
                const SizedBox(height: 24),
                _InfoNote(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.summary});
  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final goal = AttendanceLogic.coffeeStreak;
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
                      streak > 0 ? '현재 $streak일 연속 출석 중!' : '오늘 출석을 시작해보세요',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('누적 출석 ${summary.totalDays}일',
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
          _StreakTrack(streak: streak.clamp(0, goal), goal: goal),
        ],
      ),
    );
  }
}

/// 스트릭 노드 트랙 (월~금 + 커피 리워드).
class _StreakTrack extends StatelessWidget {
  const _StreakTrack({required this.streak, required this.goal});
  final int streak;
  final int goal;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(goal, (i) {
        final done = i < streak;
        final isReward = i == goal - 1;
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
              isReward ? '리워드' : '${i + 1}일',
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

/// 출석일을 달력에 표시.
class _CalendarCard extends StatefulWidget {
  const _CalendarCard({required this.summary});
  final AttendanceSummary summary;

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
    final today = AttendanceRecord.dayOf(DateTime.now());

    bool isAttended(DateTime day) =>
        attended.contains(AttendanceRecord.dayOf(day));

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
              ),
              availableGestures: AvailableGestures.horizontalSwipe,
              onPageChanged: (day) => _focused = day,
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  if (isAttended(day)) {
                    return _attendedCell(day, primary);
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
                      child: Text('${day.day}'),
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
                Text('출석한 날',
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
              color: Colors.white, fontWeight: FontWeight.bold),
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
                    const Expanded(
                      child: Text('커피 기프티콘 목표',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF18181B))),
                    ),
                    Text('$current/$target회',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.brand600)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  achieved
                      ? '🎉 학과 사무실에서 커피를 수령하세요!'
                      : '5회 연속 출석 시 학과회비로 제공 ($remaining일 남음)',
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
    required this.onTap,
  });
  final bool checkedIn;
  final bool loading;
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
        label: const Text('오늘 출석 완료  ☕',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
      label: const Text('오늘 출석하기',
          style: TextStyle(fontWeight: FontWeight.bold)),
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
              '연속 출석이 끊기면 다시 1일부터 시작됩니다. '
              '보상 커피는 학과회비로 제공되며 학과 사무실에서 수령할 수 있습니다.',
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
