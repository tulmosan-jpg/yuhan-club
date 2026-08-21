import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/repository.dart';
import '../../l10n/app_strings.dart';
import 'admin_member_accounts_screen.dart';
import '../../models/attendance.dart';
import '../../models/report.dart';
import '../../widgets/app_dialog.dart';
import 'group_reports_screen.dart';

/// 관리자: 그룹 상세 — 보고서 / 출석 / 통계 탭.
class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen(
      {super.key, required this.groupId, required this.groupName});
  final String groupId;
  final String groupName;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(groupName,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.manage_accounts_outlined),
              tooltip: tr(context, 'member_accounts'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AdminMemberAccountsScreen(
                    groupId: groupId, groupName: groupName),
              )),
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(text: tr(context, 'admin_nav_reports')),
            Tab(text: tr(context, 'admin_nav_attendance')),
            Tab(text: tr(context, 'admin_nav_stats')),
          ]),
        ),
        body: TabBarView(
          children: [
            GroupReportsScreen(
                groupId: groupId, groupName: groupName, embedded: true),
            _GroupAttendanceAdmin(groupId: groupId),
            _GroupStats(groupId: groupId, groupName: groupName),
          ],
        ),
      ),
    );
  }
}

/// 그룹 출석 관리: 날짜 등록/삭제 + 회원 출석 현황.
class _GroupAttendanceAdmin extends StatefulWidget {
  const _GroupAttendanceAdmin({required this.groupId});
  final String groupId;

  @override
  State<_GroupAttendanceAdmin> createState() => _GroupAttendanceAdminState();
}

class _GroupAttendanceAdminState extends State<_GroupAttendanceAdmin> {
  late Future<List<ScheduleEntry>> _schedule;
  late Future<List<MemberAttendance>> _members;
  late Future<List<Rsvp>> _rsvp;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = context.read<AppRepository>();
    _schedule = repo.fetchGroupSchedule(widget.groupId);
    _members = repo.fetchGroupMemberAttendance(widget.groupId);
    _rsvp = repo.fetchGroupRsvp(widget.groupId);
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
    // 그날 진행 주제 입력(선택).
    final topic = await _askTopic(picked);
    if (topic == null || !mounted) return; // 취소
    await context
        .read<AppRepository>()
        .addGroupAttendanceDate(widget.groupId, picked, topic: topic);
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'date_added'))));
  }

  /// 주제 입력 다이얼로그. 취소 시 null, 확인 시 입력값(빈 문자열 가능).
  Future<String?> _askTopic(DateTime day, {String initial = ''}) {
    return showInputDialog(
      context: context,
      title: '${DateFormat('M/d (E)', 'ko').format(day)} '
          '${tr(context, 'schedule_topic')}',
      hint: tr(context, 'schedule_topic_hint'),
      initialText: initial,
      maxLength: 40,
      confirmText: tr(context, 'confirm'),
    );
  }

  Future<void> _editTopic(ScheduleEntry e) async {
    final topic = await _askTopic(e.date, initial: e.topic);
    if (topic == null || !mounted) return;
    await context
        .read<AppRepository>()
        .addGroupAttendanceDate(widget.groupId, e.date, topic: topic);
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _removeDate(DateTime d) async {
    await context
        .read<AppRepository>()
        .removeGroupAttendanceDate(widget.groupId, d);
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(_reload),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
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
                    padding: const EdgeInsets.symmetric(horizontal: 14)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(tr(context, 'schedule_hint'),
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
          const SizedBox(height: 12),
          FutureBuilder<List<ScheduleEntry>>(
            future: _schedule,
            builder: (context, snap) {
              final entries = snap.data ?? [];
              if (entries.isEmpty) {
                return Text(tr(context, 'no_scheduled_dates'),
                    style: TextStyle(color: Colors.grey.shade500));
              }
              final today = AttendanceRecord.dayOf(DateTime.now());
              return Column(
                children: entries.map((e) {
                  final isToday = e.date == today;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    decoration: BoxDecoration(
                      color: isToday ? AppTheme.brandTonal : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x0F000000)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event,
                            size: 18,
                            color: isToday
                                ? AppTheme.brand600
                                : Colors.grey.shade500),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat('M/d (E)', 'ko').format(e.date),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(
                                  e.topic.isEmpty
                                      ? tr(context, 'schedule_no_topic')
                                      : e.topic,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: e.topic.isEmpty
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade700)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_outlined,
                              size: 18, color: Colors.grey.shade600),
                          tooltip: tr(context, 'schedule_topic'),
                          onPressed: () => _editTopic(e),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 18, color: Color(0xFFE53E3E)),
                          onPressed: () => _removeDate(e.date),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const Divider(height: 36),
          // ── 참석 응답 현황 ──
          FutureBuilder<List<Rsvp>>(
            future: _rsvp,
            builder: (context, rsnap) {
              final rsvps = rsnap.data ?? [];
              if (rsvps.isEmpty) return const SizedBox.shrink();
              // 날짜별 그룹핑.
              final byDay = <DateTime, List<Rsvp>>{};
              for (final r in rsvps) {
                (byDay[r.day] ??= []).add(r);
              }
              final days = byDay.keys.toList()..sort();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(context, 'group_rsvp'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...days.map((d) {
                    final list = byDay[d]!;
                    final going = list.where((r) => r.available).length;
                    final notGoing = list.where((r) => !r.available).toList();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x0F000000)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(DateFormat('M/d (E)', 'ko').format(d),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text(
                                  '${tr(context, 'rsvp_available')} $going · ${tr(context, 'rsvp_unavailable')} ${notGoing.length}',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600)),
                            ],
                          ),
                          ...notGoing.map((r) => Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '· ${r.userName}: ${r.reason.isEmpty ? tr(context, 'rsvp_unavailable') : r.reason}',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: const Color(0xFFE53E3E)),
                                ),
                              )),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 36),
                ],
              );
            },
          ),
          FutureBuilder<List<MemberAttendance>>(
            future: _members,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final members = snap.data ?? [];
              if (members.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(tr(context, 'attendance_none'),
                        style: TextStyle(color: Colors.grey.shade500)),
                  ),
                );
              }
              return Column(
                children: members
                    .map((m) => _memberTile(context, m))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _memberTile(BuildContext context, MemberAttendance m) {
    final s = m.summary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: AppTheme.brandTonal, shape: BoxShape.circle),
            child: Text(m.name.isNotEmpty ? m.name.characters.first : '?',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.brandOnTonal)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(m.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          Text(tr(context, 'total_unit', {'n': '${s.totalDays}'}),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: s.checkedInToday
                    ? AppTheme.brandTonal
                    : const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(8)),
            child: Text(
                tr(context,
                    s.checkedInToday ? 'checked_today_yes' : 'checked_today_no'),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: s.checkedInToday
                        ? AppTheme.brandOnTonal
                        : const Color(0xFF9CA3AF))),
          ),
        ],
      ),
    );
  }
}

/// 그룹 통계: 출석률·보고서·응답률 + 회원별 표 + CSV 내보내기.
class _GroupStats extends StatefulWidget {
  const _GroupStats({required this.groupId, required this.groupName});
  final String groupId;
  final String groupName;

  @override
  State<_GroupStats> createState() => _GroupStatsState();
}

class _GroupStatsState extends State<_GroupStats> {
  late Future<_StatsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StatsData> _load() async {
    final repo = context.read<AppRepository>();
    final results = await Future.wait([
      repo.fetchGroupMemberAttendance(widget.groupId),
      repo.fetchGroupAttendanceDates(widget.groupId),
      repo.fetchGroupReports(widget.groupId),
      repo.fetchGroupRsvp(widget.groupId),
    ]);
    return _StatsData(
      members: results[0] as List<MemberAttendance>,
      dates: results[1] as List<DateTime>,
      reports: results[2] as List<MentoringReport>,
      rsvp: results[3] as List<Rsvp>,
    );
  }

  String _buildCsv(_StatsData d) {
    final buf = StringBuffer();
    buf.writeln('이름,출석,출석률(%),보고서수');
    final sessions = d.dates.length;
    // 회원별 보고서 수
    final reportsByUser = <String, int>{};
    for (final r in d.reports) {
      reportsByUser[r.authorName] = (reportsByUser[r.authorName] ?? 0) + 1;
    }
    for (final m in d.members) {
      final rate =
          sessions == 0 ? 0 : (m.summary.totalDays / sessions * 100).round();
      final rc = reportsByUser[m.name] ?? 0;
      buf.writeln('${m.name},${m.summary.totalDays},$rate,$rc');
    }
    return buf.toString();
  }

  Future<void> _exportCsv(_StatsData d) async {
    await Clipboard.setData(ClipboardData(text: _buildCsv(d)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'csv_copied'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StatsData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snap.data;
        if (d == null) {
          return Center(child: Text(tr(context, 'load_failed')));
        }
        final members = d.members.length;
        final sessions = d.dates.length;
        final totalCheckins =
            d.members.fold<int>(0, (s, m) => s + m.summary.totalDays);
        final attendRate = (members * sessions) == 0
            ? 0
            : (totalCheckins / (members * sessions) * 100).round();
        final submitted =
            d.reports.where((r) => r.status == ReportStatus.submitted).length;
        final draft = d.reports.length - submitted;
        final rsvpRate = (members * sessions) == 0
            ? 0
            : (d.rsvp.length / (members * sessions) * 100).round();
        final reportsByUser = <String, int>{};
        for (final r in d.reports) {
          reportsByUser[r.authorName] = (reportsByUser[r.authorName] ?? 0) + 1;
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Row(children: [
              Expanded(child: _stat(context, tr(context, 'stat_members'), '$members')),
              const SizedBox(width: 10),
              Expanded(child: _stat(context, tr(context, 'stat_sessions'), '$sessions')),
              const SizedBox(width: 10),
              Expanded(child: _stat(context, tr(context, 'stat_attendance_rate'), '$attendRate%', highlight: true)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _stat(context, tr(context, 'stat_submitted'), '$submitted')),
              const SizedBox(width: 10),
              Expanded(child: _stat(context, tr(context, 'stat_draft'), '$draft')),
              const SizedBox(width: 10),
              Expanded(child: _stat(context, tr(context, 'stat_rsvp_rate'), '$rsvpRate%')),
            ]),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(tr(context, 'stat_per_member'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportCsv(d),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: Text(tr(context, 'export_csv')),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 회원별 출석률 바
            ...d.members.map((m) {
              final rate = sessions == 0
                  ? 0.0
                  : (m.summary.totalDays / sessions).clamp(0.0, 1.0);
              final rc = reportsByUser[m.name] ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x0F000000)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(m.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                        Text(
                            '${m.summary.totalDays}/$sessions · ${(rate * 100).round()}% · ${tr(context, 'col_reports')} $rc',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: rate.toDouble(),
                        minHeight: 7,
                        backgroundColor: const Color(0xFFF0F0F0),
                        valueColor: const AlwaysStoppedAnimation(
                            AppTheme.brand500),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _stat(BuildContext context, String label, String value,
      {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: highlight ? AppTheme.brandTonal : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: highlight ? AppTheme.brand200 : const Color(0x0F000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: highlight
                      ? AppTheme.brandOnTonal
                      : const Color(0xFF18181B))),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _StatsData {
  final List<MemberAttendance> members;
  final List<DateTime> dates;
  final List<MentoringReport> reports;
  final List<Rsvp> rsvp;
  _StatsData({
    required this.members,
    required this.dates,
    required this.reports,
    required this.rsvp,
  });
}
