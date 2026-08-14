import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/repository.dart';
import '../../l10n/app_strings.dart';
import '../../models/report.dart';
import '../reports/report_detail_screen.dart';

/// 관리자: 특정 그룹의 보고서 목록(읽기 전용 + 삭제).
class GroupReportsScreen extends StatefulWidget {
  const GroupReportsScreen(
      {super.key,
      required this.groupId,
      required this.groupName,
      this.embedded = false});
  final String groupId;
  final String groupName;
  final bool embedded; // 탭 안에 임베드되면 AppBar 생략

  @override
  State<GroupReportsScreen> createState() => _GroupReportsScreenState();
}

class _GroupReportsScreenState extends State<GroupReportsScreen> {
  late Future<List<MentoringReport>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<AppRepository>().fetchGroupReports(widget.groupId);
  }

  Future<bool> _delete(MentoringReport r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr(context, 'delete_report_title')),
        content: Text(tr(context, 'delete_report_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE53E3E)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return false;
    await context.read<AppRepository>().deleteReport(r.id);
    if (!mounted) return true;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'report_deleted'))));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<List<MentoringReport>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snap.data ?? [];
          if (reports.isEmpty) {
            return Center(
              child: Text(tr(context, 'reports_empty'),
                  style: TextStyle(color: Colors.grey.shade500)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              itemCount: reports.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final r = reports[i];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ReportDetailScreen(
                        report: r,
                        onDelete: () => _delete(r),
                      ),
                    )),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(color: const Color(0x0F000000)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _pill(reportStatusLabel(context, r.status),
                                  r.status == ReportStatus.submitted),
                              const Spacer(),
                              Text(
                                  DateFormat('yyyy.MM.dd')
                                      .format(r.activityDate),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(r.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.account_circle_outlined,
                                  size: 15, color: AppTheme.brand600),
                              const SizedBox(width: 5),
                              Text(
                                  '${tr(context, 'author')}: ${r.authorName}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.brand700)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(
            tr(context, 'group_reports_title', {'name': widget.groupName}),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: body,
    );
  }

  Widget _pill(String text, bool submitted) {
    final bg = submitted ? AppTheme.brandTonal : const Color(0xFFFEF3C7);
    final fg = submitted ? AppTheme.brandOnTonal : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}
