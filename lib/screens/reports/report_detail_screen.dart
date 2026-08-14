import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/report.dart';

/// 관리자용 동아리 보고서 상세(읽기 전용). 회원이 작성한 보고서를 확인한다.
class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({
    super.key,
    required this.report,
    this.onDelete,
  });

  final MentoringReport report;
  final Future<bool> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final submitted = report.status == ReportStatus.submitted;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'report_detail_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFE53E3E)),
              tooltip: tr(context, 'delete'),
              onPressed: () async {
                final deleted = await onDelete!();
                if (deleted && context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 상태 + 역할 배지
          Row(
            children: [
              _pill(
                reportStatusLabel(context, report.status),
                submitted ? AppTheme.brandOnTonal : const Color(0xFFD97706),
                submitted ? AppTheme.brandTonal : const Color(0xFFFEF3C7),
              ),
              const SizedBox(width: 6),
              _pill(reportRoleLabel(context, report.role),
                  const Color(0xFF52525B), const Color(0xFFF4F4F5)),
            ],
          ),
          const SizedBox(height: 14),
          Text(report.title,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, height: 1.3)),
          const SizedBox(height: 20),

          _row(context, Icons.account_circle_outlined, tr(context, 'author'),
              report.authorName),
          if (report.partnerName.trim().isNotEmpty)
            _row(context, Icons.people_alt_outlined,
                tr(context, 'report_partner'), report.partnerName),
          _row(context, Icons.event_outlined,
              tr(context, 'report_activity_date'),
              DateFormat('yyyy.MM.dd (E) HH:mm', 'ko').format(report.activityDate)),
          _row(context, Icons.schedule, tr(context, 'report_hours'),
              tr(context, 'hours', {'n': '${report.activityHours}'})),

          const Divider(height: 32),
          Text(tr(context, 'report_content'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(report.content.trim().isEmpty
              ? tr(context, 'report_no_content')
              : report.content,
              style: const TextStyle(height: 1.6, color: Color(0xFF3F3F46))),

          if ((report.feedback ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(tr(context, 'report_feedback_field'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(report.feedback!,
                style: const TextStyle(height: 1.6, color: Color(0xFF3F3F46))),
          ],

          if (report.photos.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(tr(context, 'report_photos'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: report.photos.map((b64) {
                final bytes = base64Decode(b64);
                return GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(16),
                      child: InteractiveViewer(
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(bytes,
                        width: 100, height: 100, fit: BoxFit.cover),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 28),
          if (onDelete != null)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: const Color(0xFFE53E3E),
                side: const BorderSide(color: Color(0xFFE53E3E)),
              ),
              icon: const Icon(Icons.delete_outline),
              label: Text(tr(context, 'delete')),
              onPressed: () async {
                final deleted = await onDelete!();
                if (deleted && context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          SizedBox(
            width: 76,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
