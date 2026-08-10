import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/repository.dart';
import '../../models/report.dart';
import 'report_editor_screen.dart';

/// 멘토링 보고서 목록 화면 (유한 녹색 브랜드 리디자인).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _ReportFilter { all, draft, submitted, mentor, mentee }

extension on _ReportFilter {
  String get label => switch (this) {
        _ReportFilter.all => '전체',
        _ReportFilter.draft => '임시저장',
        _ReportFilter.submitted => '제출완료',
        _ReportFilter.mentor => '멘토',
        _ReportFilter.mentee => '멘티',
      };
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<List<MentoringReport>> _future;
  _ReportFilter _filter = _ReportFilter.all;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<AppRepository>().fetchReports();
  }

  Future<void> _openEditor([MentoringReport? report]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportEditorScreen(existing: report),
      ),
    );
    if (saved == true && mounted) setState(_reload);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('멘토링 보고서',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
                            onTap: () => _openEditor(reports[i]),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: AppTheme.brand500,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('새 보고서 작성',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
                f.label,
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
          Text(error ? '보고서를 불러오지 못했습니다.' : '작성한 보고서가 없습니다.',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          if (!error)
            Text('우측 하단 버튼으로 첫 보고서를 작성해보세요.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});
  final MentoringReport report;
  final VoidCallback onTap;

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
                  _roleBadge(report.role.label),
                  const SizedBox(width: 6),
                  _statusPill(report.status.label, submitted),
                  const Spacer(),
                  Icon(Icons.schedule,
                      size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 3),
                  Text('${report.activityHours}시간',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                ],
              ),
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
                  Icon(Icons.person_outline,
                      size: 15, color: Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Text(
                    '${isMentor ? '멘티' : '멘토'} ${report.partnerName}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700),
                  ),
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
