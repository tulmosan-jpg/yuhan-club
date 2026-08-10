import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../app/app_config.dart';
import '../../app/theme.dart';
import '../../data/auth_service.dart';
import '../../data/repository.dart';
import '../../data/attendance_logic.dart';
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
  }

  Future<_DashboardData> _load() async {
    final repo = context.read<AppRepository>();
    final results = await Future.wait([
      repo.fetchAttendance(),
      repo.fetchActivities(),
      repo.fetchReports(),
    ]);
    return _DashboardData(
      attendance: results[0] as AttendanceSummary,
      activities: results[1] as List<Activity>,
      reports: results[2] as List<MentoringReport>,
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
                _SectionHeader(title: '빠른 실행'),
                const SizedBox(height: 12),
                _QuickActions(onNavigate: widget.onNavigate),
                const SizedBox(height: 28),
                _SectionHeader(
                  title: '마감 임박 대외활동',
                  actionLabel: '전체보기',
                  onAction: () => widget.onNavigate?.call(2),
                ),
                const SizedBox(height: 12),
                if (upcoming.isEmpty)
                  const _EmptyCard(text: '마감 예정 활동이 없습니다.')
                else
                  ...upcoming.take(3).map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ActivityTile(
                          activity: a,
                          onTap: () => widget.onNavigate?.call(2),
                        ),
                      )),
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
class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});
  final String name;

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
                  const Text('유한대학교 식품영양학과',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.brand600)),
                ],
              ),
              const SizedBox(height: 6),
              Text('안녕하세요, $name님 👋',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF18181B))),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: '계정',
          onSelected: (v) async {
            if (v == 'logout' && !AppConfig.useMock) {
              await context.read<AuthService>().signOut();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'name',
              enabled: false,
              child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 18),
                  SizedBox(width: 8),
                  Text('로그아웃'),
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
            ),
            child: const Icon(Icons.person_outline,
                size: 22, color: AppTheme.brandOnTonal),
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
    final goal = AttendanceLogic.coffeeStreak; // 5
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
                          ? '연속 출석 $streak일! 🎉'
                          : '연속 출석 $streak일차!',
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      remaining == 0
                          ? '커피 리워드를 받을 수 있어요.'
                          : '커피 획득까지 $remaining일 남았어요.',
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
          _StreakTrack(streak: streak, goal: goal),
        ],
      ),
    );
  }
}

class _StreakTrack extends StatelessWidget {
  const _StreakTrack({required this.streak, required this.goal});
  final int streak;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final labels = ['월', '화', '수', '목', '금'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(goal, (i) {
        final done = i < streak;
        final isReward = i == goal - 1;
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
              isReward ? '리워드' : label,
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
            label: '보고서 작성',
            onTap: () => onNavigate?.call(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            icon: Icons.confirmation_number_outlined,
            label: '대외활동',
            onTap: () => onNavigate?.call(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            icon: Icons.event_available,
            label: '출석체크',
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
                    Text('${a.deadline!.month}월',
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
                    _tag(a.type),
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
                          '마감 ${DateFormat('MM.dd').format(a.deadline!)}'
                          '${soon ? ' · 마감임박' : ''}',
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

  Widget _tag(ActivityType type) {
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
      child: Text(type.label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
              color: c)),
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
  _DashboardData({
    required this.attendance,
    required this.activities,
    required this.reports,
  });
}
