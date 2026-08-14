import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/attendance_logic.dart';
import '../../data/repository.dart';
import '../../l10n/app_strings.dart';
import '../../models/attendance.dart';

/// 관리자 출석 확인: 회원별 출석 현황(연속·누적·오늘 여부·보상 대상).
class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key, this.showLogout = false, this.onLogout});
  final bool showLogout;
  final VoidCallback? onLogout;

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  late Future<List<MemberAttendance>> _members;
  late Future<List<DateTime>> _dates;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = context.read<AppRepository>();
    _members = repo.fetchAllAttendance();
    _dates = repo.fetchAttendanceDates();
  }

  Future<void> _addDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null || !mounted) return;
    await context.read<AppRepository>().addAttendanceDate(picked);
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'date_added'))));
  }

  Future<void> _removeDate(DateTime d) async {
    await context.read<AppRepository>().removeAttendanceDate(d);
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'date_removed'))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(tr(context, 'admin_attendance_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: tr(context, 'refresh'),
            onPressed: () => setState(_reload),
          ),
          if (widget.showLogout)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: tr(context, 'logout'),
              onPressed: widget.onLogout,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            // ── 출석 일정 관리 ──
            Row(
              children: [
                Expanded(
                  child: Text(tr(context, 'attendance_schedule'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                FilledButton.icon(
                  onPressed: _addDate,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(tr(context, 'add_attendance_date')),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(tr(context, 'schedule_hint'),
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            FutureBuilder<List<DateTime>>(
              future: _dates,
              builder: (context, snap) {
                final dates = snap.data ?? [];
                if (dates.isEmpty) {
                  return Text(tr(context, 'no_scheduled_dates'),
                      style: TextStyle(color: Colors.grey.shade500));
                }
                final today = AttendanceRecord.dayOf(DateTime.now());
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: dates.map((d) {
                    final isToday = d == today;
                    return Chip(
                      backgroundColor:
                          isToday ? AppTheme.brand500 : AppTheme.brandTonal,
                      side: BorderSide.none,
                      label: Text(
                        DateFormat('M/d (E)', 'ko').format(d),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isToday
                                ? Colors.white
                                : AppTheme.brandOnTonal),
                      ),
                      deleteIcon: Icon(Icons.close,
                          size: 16,
                          color: isToday
                              ? Colors.white
                              : AppTheme.brandOnTonal),
                      onDeleted: () => _removeDate(d),
                    );
                  }).toList(),
                );
              },
            ),

            const Divider(height: 36),

            // ── 회원 출석 현황 ──
            FutureBuilder<List<MemberAttendance>>(
              future: _members,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final members = snap.data ?? [];
                if (members.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                          snap.hasError
                              ? tr(context, 'load_failed')
                              : tr(context, 'attendance_none'),
                          style: TextStyle(color: Colors.grey.shade500)),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'admin_attendance_summary',
                          {'n': '${members.length}'}),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 12),
                    ...members.map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MemberCard(member: m),
                        )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member});
  final MemberAttendance member;

  @override
  Widget build(BuildContext context) {
    final s = member.summary;
    final reached = s.currentStreak >= AttendanceLogic.coffeeStreak;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      child: Row(
        children: [
          // 아바타 이니셜
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTheme.brandTonal,
              shape: BoxShape.circle,
            ),
            child: Text(
              member.name.isNotEmpty ? member.name.characters.first : '?',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.brandOnTonal),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF18181B))),
                    ),
                    if (reached) ...[
                      const SizedBox(width: 6),
                      Text(tr(context, 'reward_reached_badge'),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD97706))),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _stat(Icons.local_fire_department,
                        tr(context, 'streak_unit', {'n': '${s.currentStreak}'}),
                        AppTheme.brand600),
                    const SizedBox(width: 12),
                    _stat(Icons.event_available,
                        tr(context, 'total_unit', {'n': '${s.totalDays}'}),
                        Colors.grey.shade500),
                  ],
                ),
              ],
            ),
          ),
          _todayBadge(context, s.checkedInToday),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _todayBadge(BuildContext context, bool checkedIn) {
    final Color fg = checkedIn ? AppTheme.brandOnTonal : const Color(0xFF9CA3AF);
    final Color bg =
        checkedIn ? AppTheme.brandTonal : const Color(0xFFF4F4F5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        tr(context, checkedIn ? 'checked_today_yes' : 'checked_today_no'),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
