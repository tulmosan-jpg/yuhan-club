import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_config.dart';
import '../../app/theme.dart';
import '../../data/auth_service.dart';
import '../../data/notification_service.dart';
import '../../data/profile_service.dart';
import '../../data/repository.dart';
import '../../data/attendance_logic.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_provider.dart';
import '../settings/notification_settings_screen.dart';
import '../../models/activity.dart';
import '../../models/attendance.dart';
import '../../models/report.dart';

/// 홈 대시보드: 오늘의 요약 (유한 녹색 브랜드 리디자인).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onNavigate});

  /// 하단 탭 전환 콜백 (0:홈 1:보고서 2:대외활동 3:출석).
  final void Function(int index)? onNavigate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    // 실제 모드 첫 진입 시 알림 권한 요청("허용하시겠습니까" 시스템 창).
    // 이미 응답했으면 OS 가 다시 띄우지 않으므로 매번 호출해도 안전.
    if (!AppConfig.useMock) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.instance.requestPermission();
      });
    }
  }

  Future<_DashboardData> _load() async {
    final repo = context.read<AppRepository>();
    // 출석은 그룹별. 내 첫 그룹의 출석을 홈 스트릭에 반영.
    final myGroups = await repo.fetchMyGroups();
    final results = await Future.wait([
      myGroups.isEmpty
          ? repo.fetchAttendance()
          : repo.fetchMyGroupAttendance(myGroups.first.id),
      repo.fetchActivities(),
      repo.fetchReports(),
    ]);
    // 요약용: 다음 출석일 + 미응답(RSVP) 개수.
    DateTime? nextDate;
    int pendingRsvp = 0;
    String? groupName = myGroups.isEmpty ? null : myGroups.first.name;
    if (myGroups.isNotEmpty) {
      final gid = myGroups.first.id;
      // 출석일·RSVP를 병렬 조회.
      final extra = await Future.wait([
        repo.fetchGroupAttendanceDates(gid),
        repo.fetchMyRsvp(gid),
      ]);
      final dates = extra[0] as List<DateTime>;
      final rsvp = extra[1] as Map<String, Rsvp>;
      final today = AttendanceRecord.dayOf(DateTime.now());
      final upcoming = dates.where((d) => !d.isBefore(today)).toList()..sort();
      nextDate = upcoming.isEmpty ? null : upcoming.first;
      pendingRsvp = upcoming
          .where((d) => !rsvp.containsKey(AttendanceRecord.keyOf(d)))
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
      attendance: results[0] as AttendanceSummary,
      activities: results[1] as List<Activity>,
      reports: results[2] as List<MentoringReport>,
      groupName: groupName,
      nextDate: nextDate,
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
                _StreakCard(summary: d.attendance),
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
                          onTap: () => widget.onNavigate?.call(2),
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
  const _StreakCard({required this.summary});
  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final goal = AttendanceLogic.coffeeStreak; // 2 (연속 2일 → 커피)
    final streak = summary.currentStreak.clamp(0, goal);
    final remaining = (goal - streak).clamp(0, goal);

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
          _StreakTrack(streak: summary.currentStreak),
        ],
      ),
    );
  }
}

class _StreakTrack extends StatelessWidget {
  const _StreakTrack({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final trackDays = AttendanceLogic.streakTrackDays;
    final rewardIndex = AttendanceLogic.coffeeStreak - 1;
    final labels = [
      tr(context, 'wd_mon'),
      tr(context, 'wd_tue'),
      tr(context, 'wd_wed'),
      tr(context, 'wd_thu'),
      tr(context, 'wd_fri'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(trackDays, (i) {
        final done = i < streak;
        final isReward = i == rewardIndex;
        final label = i < labels.length ? labels[i] : '${i + 1}';
        return Column(
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
            Text(
              isReward ? tr(context, 'reward') : label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: done || isReward ? FontWeight.bold : FontWeight.w500,
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

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'cannot_open_link'))));
    }
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
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
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

class _DashboardData {
  final AttendanceSummary attendance;
  final List<Activity> activities;
  final List<MentoringReport> reports;
  final String? groupName;
  final DateTime? nextDate;
  final int pendingRsvp;
  _DashboardData({
    required this.attendance,
    required this.activities,
    required this.reports,
    this.groupName,
    this.nextDate,
    this.pendingRsvp = 0,
  });
}
