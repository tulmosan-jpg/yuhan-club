import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../models/activity.dart';
import '../../app/activity_style.dart';

/// 대외활동/박람회 상세 화면.
class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({super.key, required this.activity});
  final Activity activity;

  Future<void> _openUrl(BuildContext context) async {
    final raw = activity.url!;
    final uri = Uri.parse(raw.startsWith('http') ? raw : 'https://$raw');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('링크를 열 수 없습니다.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy.MM.dd (E)', 'ko');
    final showSoon = activity.closingSoon && !activity.closed;
    return Scaffold(
      appBar: AppBar(
        title: Text(activity.type.label,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.brandTonal,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(ActivityStyle.icon(activity.type),
                    color: AppTheme.brandOnTonal, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _typeTag(),
                        if (activity.closed) ...[
                          const SizedBox(width: 6),
                          _statusTag('마감', const Color(0xFF9CA3AF),
                              const Color(0xFFF4F4F5)),
                        ] else if (showSoon) ...[
                          const SizedBox(width: 6),
                          _statusTag('마감임박', const Color(0xFFE53E3E),
                              const Color(0xFFFFF0F0)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(activity.title,
                        style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _row(Icons.apartment_outlined, '주최/주관', activity.organizer),
          if (activity.startDate != null)
            _row(Icons.event_outlined, '행사일',
                df.format(activity.startDate!)),
          if (activity.deadline != null)
            _row(Icons.schedule, '신청마감', df.format(activity.deadline!),
                highlight: showSoon),
          if (activity.location != null)
            _row(Icons.place_outlined, '장소', activity.location!),
          const Divider(height: 32),
          const Text('상세 내용',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(activity.description,
              style: const TextStyle(height: 1.6)),
          const SizedBox(height: 28),
          if (activity.url != null)
            FilledButton.icon(
              onPressed: () => _openUrl(context),
              icon: const Icon(Icons.open_in_new),
              label: const Text('신청/상세 페이지 열기'),
            ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: highlight ? const Color(0xFFE53E3E) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.brandTonal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(activity.type.label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.brandOnTonal)),
    );
  }

  Widget _statusTag(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}
