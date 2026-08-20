import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/auth_service.dart';
import '../../data/repository.dart';
import '../../l10n/app_strings.dart';
import '../../models/report.dart';
import '../attendance/attendance_screen.dart';
import 'report_detail_screen.dart';
import 'report_editor_screen.dart';

/// 동아리 보고서 화면. [adminView]=true 면 관리자 전용(전체 보고서 확인·삭제).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.adminView = false, this.onNeedMentor});
  final bool adminView;

  /// 멘토 미선택 상태에서 새 보고서를 누르면 호출(멘토 선택 화면으로 이동).
  final VoidCallback? onNeedMentor;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _ReportFilter { all, draft, submitted, mentor, mentee }

String _filterLabel(BuildContext context, _ReportFilter f) => switch (f) {
      _ReportFilter.all => tr(context, 'rf_all'),
      _ReportFilter.draft => tr(context, 'rf_draft'),
      _ReportFilter.submitted => tr(context, 'rf_submitted'),
      _ReportFilter.mentor => tr(context, 'rf_mentor'),
      _ReportFilter.mentee => tr(context, 'rf_mentee'),
    };

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<List<MentoringReport>> _future;
  _ReportFilter _filter = _ReportFilter.all;

  bool get _isAdmin => widget.adminView;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = context.read<AppRepository>();
    _future = _isAdmin ? repo.fetchAllReports() : repo.fetchReports();
  }

  Future<void> _openEditor([MentoringReport? report]) async {
    String? groupId = report?.groupId;
    // 새 보고서: 멘토(그룹) 미선택이면 멘토 선택 화면을 띄우고,
    // 선택(가입)하면 곧바로 보고서 작성창으로 이어간다.
    if (report == null && !_isAdmin) {
      var mine = await context.read<AppRepository>().fetchMyGroups();
      if (!mounted) return;
      if (mine.isEmpty) {
        final joined = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const MentorPickScreen()),
        );
        if (!mounted || joined != true) return;
        mine = await context.read<AppRepository>().fetchMyGroups();
        if (!mounted || mine.isEmpty) return;
      }
      groupId = mine.first.id;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportEditorScreen(existing: report, groupId: groupId),
      ),
    );
    if (saved == true && mounted) setState(_reload);
  }

  /// 관리자: 회원 보고서를 읽기 전용 상세로 확인(+삭제).
  Future<void> _openDetail(MentoringReport report) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportDetailScreen(
          report: report,
          onDelete: () => _deleteReport(report),
        ),
      ),
    );
  }

  Future<bool> _deleteReport(MentoringReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr(context, 'delete_report_title')),
        content: Text(tr(context, 'delete_report_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53E3E)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    await context.read<AppRepository>().deleteReport(report.id);
    if (!mounted) return true;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'report_deleted'))));
    return true;
  }

  List<MentoringReport> _apply(List<MentoringReport> all) {
    return switch (_filter) {
      _ReportFilter.all => all,
      _ReportFilter.draft =>
        all.where((r) => r.status == ReportStatus.draft).toList(),
      _ReportFilter.submitted =>
        all.where((r) => r.status == ReportStatus.submitted).toList(),
      _ReportFilter.mentor =>
        all.where((r) => r.role == ReportRole.mentor).toList(),
      _ReportFilter.mentee =>
        all.where((r) => r.role == ReportRole.mentee).toList(),
    };
  }

  Future<void> _logout() async {
    await context.read<AuthService>().signOut();
    // AuthGate가 로그인 화면으로 자동 전환.
  }

  @override
  Widget build(BuildContext context) {
    final adminSession = _isAdmin;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(tr(context, 'reports_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (adminSession)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: tr(context, 'logout'),
              onPressed: _logout,
            ),
        ],
      ),
      body: FutureBuilder<List<MentoringReport>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const _Empty(error: true);
          }
          final all = snap.data ?? [];
          final draftCount =
              all.where((r) => r.status == ReportStatus.draft).length;
          final reports = _apply(all);
          return Column(
            children: [
              if (_isAdmin) _AdminBanner(),
              _FilterBar(
                selected: _filter,
                draftCount: draftCount,
                onSelected: (f) => setState(() => _filter = f),
              ),
              Expanded(
                child: reports.isEmpty
                    ? const _Empty()
                    : RefreshIndicator(
                        onRefresh: () async => setState(_reload),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                          itemCount: reports.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, i) => _ReportCard(
                            report: reports[i],
                            isAdmin: _isAdmin,
                            onTap: () => _isAdmin
                                ? _openDetail(reports[i])
                                : _openEditor(reports[i]),
                            onDelete: () => _deleteReport(reports[i]),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      // 관리자는 작성 없이 관리만 → FAB 숨김.
      floatingActionButton: adminSession
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              backgroundColor: AppTheme.brand500,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.edit_outlined),
              label: Text(tr(context, 'new_report'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.draftCount,
    required this.onSelected,
  });
  final _ReportFilter selected;
  final int draftCount;
  final ValueChanged<_ReportFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          for (final f in _ReportFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(
                _filterLabel(context, f),
                f == selected,
                () => onSelected(f),
                badge: f == _ReportFilter.draft && draftCount > 0
                    ? '$draftCount'
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap,
      {String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.brand500 : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppTheme.brand500 : const Color(0xFFE4E4E7),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.brand500.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? Colors.white : const Color(0xFF52525B))),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Text(badge,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : const Color(0xFFD97706))),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.brandTonal,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.brand200),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined,
              size: 18, color: AppTheme.brandOnTonal),
          const SizedBox(width: 8),
          Text(tr(context, 'admin_mode'),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.brandOnTonal)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({this.error = false});
  final bool error;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(error ? Icons.error_outline : Icons.description_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
              error
                  ? tr(context, 'reports_load_failed')
                  : tr(context, 'reports_empty'),
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          if (!error)
            Text(tr(context, 'reports_empty_hint'),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.onTap,
    this.isAdmin = false,
    this.onDelete,
  });
  final MentoringReport report;
  final VoidCallback onTap;
  final bool isAdmin;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isMentor = report.role == ReportRole.mentor;
    final submitted = report.status == ReportStatus.submitted;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: const Color(0x0F000000)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _roleBadge(reportRoleLabel(context, report.role)),
                  const SizedBox(width: 6),
                  _statusPill(
                      reportStatusLabel(context, report.status), submitted),
                  const Spacer(),
                  Icon(Icons.schedule,
                      size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 3),
                  Text(tr(context, 'hours', {'n': '${report.activityHours}'}),
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                  if (onDelete != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onDelete,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.delete_outline,
                            size: 18, color: Color(0xFFE53E3E)),
                      ),
                    ),
                  ],
                ],
              ),
              if (isAdmin) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.account_circle_outlined,
                        size: 15, color: AppTheme.brand600),
                    const SizedBox(width: 5),
                    Text(
                      '${tr(context, 'author')}: ${report.authorName}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.brand700),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Text(report.title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      color: Color(0xFF18181B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF4F4F5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (report.partnerName.trim().isNotEmpty) ...[
                    Icon(Icons.person_outline,
                        size: 15, color: Colors.grey.shade500),
                    const SizedBox(width: 5),
                    Text(
                      '${tr(context, isMentor ? 'role_mentee' : 'role_mentor')} ${report.partnerName}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700),
                    ),
                  ],
                  const Spacer(),
                  Icon(Icons.calendar_today_outlined,
                      size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 5),
                  Text(
                    DateFormat('yyyy.MM.dd').format(report.activityDate),
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF52525B))),
    );
  }

  Widget _statusPill(String text, bool submitted) {
    final Color bg = submitted ? AppTheme.brandTonal : const Color(0xFFFEF3C7);
    final Color fg = submitted ? AppTheme.brandOnTonal : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(submitted ? Icons.check_circle : Icons.circle,
              size: 10, color: fg),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
        ],
      ),
    );
  }
}
