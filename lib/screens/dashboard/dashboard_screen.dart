import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_config.dart';
import '../../app/theme.dart';
import '../../data/auth_service.dart';
import '../../data/notification_service.dart';
import '../../data/update_service.dart';
import '../../data/profile_service.dart';
import '../../data/repository.dart';
import '../../data/attendance_logic.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_provider.dart';
import '../settings/notification_settings_screen.dart';
import '../../models/activity.dart';
import '../activities/activity_detail_screen.dart';
import '../../models/attendance.dart';
import '../../models/report.dart';

/// 홈 대시보드: 오늘의 요약 (유한 녹색 브랜드 리디자인).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen(
      {super.key, this.onNavigate, this.onReward, this.refresh});

  /// 하단 탭 전환 콜백 (0:홈 1:보고서 2:대외활동 3:출석).
  final void Function(int index)? onNavigate;

  /// 리워드 노드 탭 → 출석 탭 리워드 섹션으로 이동.
  final VoidCallback? onReward;

  /// 홈 탭이 보일 때마다 값이 바뀌며 대시보드를 다시 로드한다
  /// (출석/스트릭 등 다른 화면 변경분을 즉시 반영).
  final ValueNotifier<int>? refresh;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    widget.refresh?.addListener(_reload);
    // 실제 모드 첫 진입 시 알림 권한 요청("허용하시겠습니까" 시스템 창).
    // 이미 응답했으면 OS 가 다시 띄우지 않으므로 매번 호출해도 안전.
    if (!AppConfig.useMock) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.instance.requestPermission();
        // 새 버전 있으면 업데이트 안내.
        UpdateService.maybePrompt(context);
      });
    }
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) setState(() => _future = _load());
  }

  Future<_DashboardData> _load() async {
    final repo = context.read<AppRepository>();
    // 그룹과 무관한 조회는 먼저 시작해 겹쳐 로딩(지연 감소).
    // 마감 임박 3개만 소량 조회(전체 571건 로드 방지 → 첫 로딩 가속).
    final activitiesF = repo.fetchUpcomingActivities(limit: 3);
    final reportsF = repo.fetchReports();
    // 출석은 그룹별. 내 첫 그룹의 출석을 홈 스트릭에 반영.
    final myGroups = await repo.fetchMyGroups();
    final attendanceF = myGroups.isEmpty
        ? repo.fetchAttendance()
        : repo.fetchMyGroupAttendance(myGroups.first.id);

    // 요약용: 다음 출석일(+주제) + 미응답(RSVP) 개수.
    DateTime? nextDate;
    String? nextTopic;
    int pendingRsvp = 0;
    String? groupName = myGroups.isEmpty ? null : myGroups.first.name;
    if (myGroups.isNotEmpty) {
      final gid = myGroups.first.id;
      // 일정(주제 포함)·RSVP를 병렬 조회.
      final extra = await Future.wait([
        repo.fetchGroupSchedule(gid),
        repo.fetchMyRsvp(gid),
      ]);
      final schedule = extra[0] as List<ScheduleEntry>;
      final rsvp = extra[1] as Map<String, Rsvp>;
      final dates = schedule.map((e) => e.date).toList();
      final today = AttendanceRecord.dayOf(DateTime.now());
      final upcoming = schedule.where((e) => !e.date.isBefore(today)).toList()
        ..sort((a, b) => a.date.compareTo(b.date));
      nextDate = upcoming.isEmpty ? null : upcoming.first.date;
      nextTopic = upcoming.isEmpty ? null : upcoming.first.topic;
      pendingRsvp = upcoming
          .where((e) => !rsvp.containsKey(AttendanceRecord.keyOf(e.date)))
          .length;
      // 출석일/RSVP 로컬 알림 리마인더 예약(백그라운드, 설정 토글 존중).
      if (!AppConfig.useMock) {
        unawaited(NotificationService.instance.syncReminders(
          attendanceDates: dates,
          respondedDays: rsvp.keys.toSet(),
        ));
      }
    }
    return _DashboardData(
      attendance: await attendanceF,
      activities: await activitiesF,
      reports: await reportsF,
      groupName: groupName,
      nextDate: nextDate,
      nextTopic: nextTopic,
      pendingRsvp: pendingRsvp,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AppRepository>();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return RefreshIndicator(
              onRefresh: () async => setState(() => _future = _load()),
              child: ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.cloud_off,
                            size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(tr(context, 'dashboard_error'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          final d = snap.data!;
          final upcoming = d.activities
              .where((a) => !a.closed && a.deadline != null)
              .toList()
            ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _Greeting(name: repo.currentUserName),
                const SizedBox(height: 20),
                _StreakCard(
                  summary: d.attendance,
                  onReward:
                      widget.onReward ?? () => widget.onNavigate?.call(3),
                ),
                if (d.nextDate != null) ...[
                  const SizedBox(height: 16),
                  _NextSessionCard(
                    date: d.nextDate!,
                    topic: d.nextTopic ?? '',
                    onTap: () => widget.onNavigate?.call(3),
                  ),
                ],
                const SizedBox(height: 28),
                _SectionHeader(title: tr(context, 'quick_actions')),
                const SizedBox(height: 12),
                _QuickActions(onNavigate: widget.onNavigate),
                const SizedBox(height: 28),
                _SectionHeader(
                  title: tr(context, 'closing_soon_section'),
                  actionLabel: tr(context, 'see_all'),
                  onAction: () => widget.onNavigate?.call(2),
                ),
                const SizedBox(height: 12),
                if (upcoming.isEmpty)
                  _EmptyCard(text: tr(context, 'no_upcoming'))
                else
                  ...upcoming.take(3).map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ActivityTile(
                          activity: a,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ActivityDetailScreen(activity: a),
                            ),
                          ),
                        ),
                      )),
                const SizedBox(height: 28),
                _SectionHeader(title: tr(context, 'links_section')),
                const SizedBox(height: 12),
                const _HomepageLinks(),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}

// ── 인사 헤더 ──────────────────────────────────────────────────────
class _Greeting extends StatefulWidget {
  const _Greeting({required this.name});
  final String name;

  @override
  State<_Greeting> createState() => _GreetingState();
}

class _GreetingState extends State<_Greeting> {
  final ProfileService _profile = ProfileService();
  Uint8List? _photo;
  bool _busy = false;

  String get name => widget.name;

  @override
  void initState() {
    super.initState();
    if (!AppConfig.useMock) {
      _profile.load().then((bytes) {
        if (mounted && bytes != null) setState(() => _photo = bytes);
      });
    }
  }

  Future<void> _changePhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _profile.pickFromGallery();
      if (!mounted) return;
      if (bytes != null) {
        setState(() => _photo = bytes);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(context, 'photo_updated'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(context, 'photo_failed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _photo = null);
    if (!AppConfig.useMock) await _profile.remove();
  }

  /// 앱 초기화: 내 서버 데이터 삭제 + 멘토 탈퇴 + 로컬 설정 초기화 + 로그아웃.
  Future<void> _resetApp() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: Color(0xFFE53E3E), size: 36),
        title: Text(tr(dctx, 'reset_app'),
            style: const TextStyle(
                fontFamily: 'Pretendard', fontWeight: FontWeight.bold)),
        content: Text(tr(dctx, 'reset_app_warn'),
            style: const TextStyle(fontFamily: 'Pretendard', height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: Text(tr(dctx, 'cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE53E3E)),
            onPressed: () => Navigator.pop(dctx, true),
            child: Text(tr(dctx, 'reset_confirm')),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<AppRepository>().resetMyAccount();
      if (!AppConfig.useMock) {
        final p = await SharedPreferences.getInstance();
        await p.clear();
        await NotificationService.instance.cancelAll();
        if (!mounted) return;
        await context.read<AuthService>().signOut(); // AuthGate → 로그인 화면
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(context, 'reset_done'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(context, 'reset_failed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset('assets/images/yuhan_emblem.png',
                      width: 16, height: 16),
                  const SizedBox(width: 6),
                  Text(tr(context, 'dept_full'),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.brand600)),
                ],
              ),
              const SizedBox(height: 6),
              Text(tr(context, 'greeting', {'name': name}),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18181B))),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: tr(context, 'account'),
          onSelected: (v) async {
            if (v == 'photo') {
              await _changePhoto();
            } else if (v == 'remove_photo') {
              await _removePhoto();
            } else if (v == 'notif') {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen()));
            } else if (v == 'lang') {
              await context.read<LocaleProvider>().toggle();
            } else if (v == 'logout') {
              if (!AppConfig.useMock) {
                await context.read<AuthService>().signOut();
              }
            } else if (v == 'reset') {
              await _resetApp();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'name',
              enabled: false,
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'photo',
              child: Row(
                children: [
                  const Icon(Icons.photo_library_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(tr(context, 'change_photo')),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'notif',
              child: Row(
                children: [
                  const Icon(Icons.notifications_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(tr(context, 'notif_settings')),
                ],
              ),
            ),
            if (_photo != null)
              PopupMenuItem(
                value: 'remove_photo',
                child: Row(
                  children: [
                    const Icon(Icons.hide_image_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(tr(context, 'remove_photo')),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'lang',
              child: Row(
                children: [
                  const Icon(Icons.translate, size: 18),
                  const SizedBox(width: 8),
                  Text(tr(context, 'switch_lang')),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  const Icon(Icons.logout, size: 18),
                  const SizedBox(width: 8),
                  Text(tr(context, 'logout')),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'reset',
              child: Row(
                children: [
                  const Icon(Icons.restart_alt,
                      size: 18, color: Color(0xFFE53E3E)),
                  const SizedBox(width: 8),
                  Text(tr(context, 'reset_app'),
                      style: const TextStyle(color: Color(0xFFE53E3E))),
                ],
              ),
            ),
          ],
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.brandTonal,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE4E4E7)),
              image: _photo != null
                  ? DecorationImage(
                      image: MemoryImage(_photo!), fit: BoxFit.cover)
                  : null,
            ),
            child: _photo != null
                ? (_busy
                    ? const Center(
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)))
                    : null)
                : (_busy
                    ? const Center(
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.brandOnTonal)))
                    : const Icon(Icons.person_outline,
                        size: 22, color: AppTheme.brandOnTonal)),
          ),
        ),
      ],
    );
  }
}

// ── 연속 출석 스트릭 카드 ───────────────────────────────────────────
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.summary, this.onReward});
  final AttendanceSummary summary;
  final VoidCallback? onReward;

  @override
  Widget build(BuildContext context) {
    final goal = AttendanceLogic.coffeeStreak; // 2 (연속 2회마다 → 음료)
    final streak = summary.currentStreak; // 표시용: 실제 연속출석 수(출석 화면과 동일)
    // 리워드는 2회 '주기'마다 지급 → 다음 보상까지 남은 횟수는 주기 기준.
    // 예) 2회=받을수있음, 3회=1회 남음, 4회=받을수있음.
    final cyclePos = goal == 0 ? 0 : streak % goal;
    final remaining = (streak > 0 && cyclePos == 0) ? 0 : goal - cyclePos;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.brand500, AppTheme.brand600],
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('ATTENDANCE STREAK',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      remaining == 0
                          ? tr(context, 'streak_done', {'n': '$streak'})
                          : tr(context, 'streak_ongoing', {'n': '$streak'}),
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      remaining == 0
                          ? tr(context, 'streak_reward_ready')
                          : tr(context, 'streak_remaining', {'n': '$remaining'}),
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_fire_department,
                    color: AppTheme.streakFlame, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _StreakTrack(streak: summary.currentStreak, onReward: onReward),
        ],
      ),
    );
  }
}

class _StreakTrack extends StatelessWidget {
  const _StreakTrack({required this.streak, this.onReward});
  final int streak;
  final VoidCallback? onReward;

  @override
  Widget build(BuildContext context) {
    final track = AttendanceLogic.streakTrackDays; // 한 번에 보이는 노드 수(5)
    final cycle = AttendanceLogic.coffeeStreak; // 2회마다 리워드
    // 현재 연속출석에 맞춰 창이 이동한다(예: 7회 → 4~8회 노드가 보임).
    // 리워드 마커는 2·4·6·8… 회차에 표시.
    final justReached = streak > 0 && streak % cycle == 0;
    final nextReward = streak == 0
        ? cycle
        : (justReached ? streak : ((streak ~/ cycle) + 1) * cycle);
    final end = nextReward < track ? track : nextReward;
    final start = end - track + 1 < 1 ? 1 : end - track + 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(track, (i) {
        final dayNum = start + i; // 실제 출석 회차 번호
        final done = dayNum <= streak;
        final isReward = dayNum % cycle == 0;
        final label = tr(context, 'day_n', {'n': '$dayNum'});
        final node = Column(
          children: [
            Container(
              width: isReward ? 32 : 26,
              height: isReward ? 32 : 26,
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
                size: isReward ? 16 : 13,
                color: isReward
                    ? const Color(0xFF854D0E)
                    : (done ? AppTheme.brand600 : Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isReward ? tr(context, 'reward') : label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        done || isReward ? FontWeight.bold : FontWeight.w500,
                    color: isReward
                        ? AppTheme.streakFlame
                        : Colors.white.withValues(alpha: done ? 1 : 0.6),
                  ),
                ),
                if (isReward && onReward != null)
                  Icon(Icons.chevron_right,
                      size: 12, color: AppTheme.streakFlame),
              ],
            ),
          ],
        );
        // 리워드 노드는 탭하면 리워드(출석) 화면으로 이동.
        if (isReward && onReward != null) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onReward,
            child: node,
          );
        }
        return node;
      }),
    );
  }
}

// ── 빠른 실행 타일 ─────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions({this.onNavigate});
  final void Function(int index)? onNavigate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.edit_document,
            label: tr(context, 'qa_write_report'),
            onTap: () => onNavigate?.call(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            icon: Icons.confirmation_number_outlined,
            label: tr(context, 'qa_activities'),
            onTap: () => onNavigate?.call(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            icon: Icons.event_available,
            label: tr(context, 'qa_checkin'),
            highlighted: true,
            onTap: () => onNavigate?.call(3),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? AppTheme.brandTonal : const Color(0xFFF4F4F5),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: highlighted ? AppTheme.brand500 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon,
                    size: 24,
                    color:
                        highlighted ? Colors.white : const Color(0xFF3F3F46)),
              ),
              const SizedBox(height: 10),
              Text(label,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: highlighted
                          ? AppTheme.brandOnTonal
                          : const Color(0xFF52525B))),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 섹션 헤더 ──────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18181B))),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel!,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.brand600)),
          ),
      ],
    );
  }
}

// ── 대외활동 리스트 타일 ────────────────────────────────────────────
class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity, required this.onTap});
  final Activity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final soon = a.closingSoon;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x0F000000)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF4F4F5)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                        Localizations.localeOf(context).languageCode == 'en'
                            ? DateFormat('MMM', 'en').format(a.deadline!)
                            : tr(context, 'month_ko',
                                {'n': '${a.deadline!.month}'}),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: soon
                                ? AppTheme.brand600
                                : const Color(0xFF71717A))),
                    Text('${a.deadline!.day}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            color: Color(0xFF27272A))),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _tag(context, a.type),
                    const SizedBox(height: 4),
                    Text(a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF18181B))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(soon ? Icons.schedule : Icons.event,
                            size: 13, color: const Color(0xFFA1A1AA)),
                        const SizedBox(width: 4),
                        Text(
                          '${tr(context, 'due', {'date': DateFormat('MM.dd').format(a.deadline!)})}'
                          '${soon ? ' · ${tr(context, 'closing_soon')}' : ''}',
                          style: TextStyle(
                              fontSize: 12,
                              color: soon
                                  ? AppTheme.brand600
                                  : const Color(0xFF71717A),
                              fontWeight:
                                  soon ? FontWeight.w600 : FontWeight.normal),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(BuildContext context, ActivityType type) {
    final Color c;
    switch (type) {
      case ActivityType.fair:
      case ActivityType.seminar:
        c = AppTheme.tagBlue;
        break;
      case ActivityType.contest:
        c = AppTheme.tagPurple;
        break;
      default:
        c = AppTheme.brand600;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(activityTypeLabel(context, type),
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
              color: c)),
    );
  }
}

// ── 홈페이지 바로가기 ──────────────────────────────────────────────
class _HomepageLinks extends StatelessWidget {
  const _HomepageLinks();

  static const _univUrl = 'https://www.yuhan.ac.kr/index.do';
  static const _deptUrl = 'https://fn.yuhan.ac.kr/index.do';
  static const _instaUrl = 'https://www.instagram.com/yuhan_food_nutrition';

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'cannot_open_link'))));
    }
  }

  /// 인스타그램: 앱이 설치돼 있으면 앱(instagram://)으로, 없으면 웹으로 연다.
  Future<void> _openInstagram(BuildContext context) async {
    final appUri = Uri.parse('instagram://user?username=yuhan_food_nutrition');
    try {
      if (await canLaunchUrl(appUri) && await launchUrl(appUri)) return;
    } catch (_) {
      // 스킴 미등록/미설치 → 웹으로 폴백
    }
    if (context.mounted) await _open(context, _instaUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LinkTile(
          icon: Icons.school_outlined,
          label: tr(context, 'univ_home'),
          onTap: () => _open(context, _univUrl),
        ),
        const SizedBox(height: 10),
        _LinkTile(
          icon: Icons.restaurant_menu_outlined,
          label: tr(context, 'dept_home'),
          onTap: () => _open(context, _deptUrl),
        ),
        const SizedBox(height: 10),
        _LinkTile(
          iconWidget: const _InstagramIcon(size: 22),
          label: tr(context, 'dept_insta'),
          onTap: () => _openInstagram(context),
        ),
      ],
    );
  }
}

/// 인스타그램 로고(라인 스타일). 다른 아웃라인 아이콘과 동일한 선 두께,
/// 인스타그램 브랜드 그라데이션 색으로 그린다.
class _InstagramIcon extends StatelessWidget {
  const _InstagramIcon({this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _InstagramPainter());
}

class _InstagramPainter extends CustomPainter {
  static const _gradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [
      Color(0xFFFEDA75), // 노랑
      Color(0xFFFA7E1E), // 주황
      Color(0xFFD62976), // 마젠타
      Color(0xFF962FBF), // 보라
      Color(0xFF4F5BD5), // 파랑
    ],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final stroke = s * 0.093; // 다른 아이콘과 비슷한 선 두께(≈2 @22)
    final shader = _gradient.createShader(Rect.fromLTWH(0, 0, s, s));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = shader;

    final inset = stroke / 2 + s * 0.03;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, s - inset * 2, s - inset * 2),
      Radius.circular(s * 0.29),
    );
    canvas.drawRRect(body, line); // 외곽 둥근 사각형
    canvas.drawCircle(Offset(s / 2, s / 2), s * 0.21, line); // 렌즈 원

    // 우상단 점(채움)
    final dot = Paint()
      ..style = PaintingStyle.fill
      ..shader = shader;
    canvas.drawCircle(Offset(s * 0.72, s * 0.285), s * 0.05, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.onTap,
  });
  final IconData? icon;

  /// 커스텀 아이콘(예: 인스타그램 로고). 주어지면 [icon] 대신 사용.
  final Widget? iconWidget;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x14000000)),
          ),
          child: Row(
            children: [
              iconWidget ??
                  Icon(icon, size: 22, color: AppTheme.brand600),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3F3F46))),
              ),
              const Icon(Icons.open_in_new,
                  size: 15, color: Color(0xFFA1A1AA)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      child: Center(
        child: Text(text,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
      ),
    );
  }
}

// ── 다음 일정(날짜 + 주제) 카드 ─────────────────────────────────
class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard(
      {required this.date, required this.topic, this.onTap});
  final DateTime date;
  final String topic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final today = AttendanceRecord.dayOf(DateTime.now());
    final diff = date.difference(today).inDays;
    final dLabel = diff == 0
        ? tr(context, 'today')
        : (diff == 1 ? tr(context, 'tomorrow') : 'D-$diff');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: const Color(0x0F000000)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.brandTonal,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.event_available,
                    color: AppTheme.brand600, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(tr(context, 'next_session'),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.brand500,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(dLabel,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(DateFormat('M월 d일 (E)', 'ko').format(date),
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(topic.isEmpty ? tr(context, 'schedule_no_topic') : topic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: topic.isEmpty
                                ? Colors.grey.shade400
                                : AppTheme.brandOnTonal,
                            fontWeight: topic.isEmpty
                                ? FontWeight.normal
                                : FontWeight.w600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardData {
  final AttendanceSummary attendance;
  final List<Activity> activities;
  final List<MentoringReport> reports;
  final String? groupName;
  final DateTime? nextDate;
  final String? nextTopic;
  final int pendingRsvp;
  _DashboardData({
    required this.attendance,
    required this.activities,
    required this.reports,
    this.groupName,
    this.nextDate,
    this.nextTopic,
    this.pendingRsvp = 0,
  });
}
