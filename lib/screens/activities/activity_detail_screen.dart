import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../app/text_utils.dart';
import '../../models/activity.dart';
import '../../app/activity_style.dart';
import '../../l10n/app_strings.dart';

/// 대외활동/박람회 상세 화면.
class ActivityDetailScreen extends StatelessWidget {
  const ActivityDetailScreen({super.key, required this.activity});
  final Activity activity;

  Future<void> _openUrl(BuildContext context) async {
    final raw = activity.url!;
    final uri = Uri.parse(raw.startsWith('http') ? raw : 'https://$raw');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'cannot_open_link'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final df = DateFormat('yyyy.MM.dd (E)', lang);
    final showSoon = activity.closingSoon && !activity.closed;
    return Scaffold(
      appBar: AppBar(
        title: Text(activityTypeLabel(context, activity.type),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (activity.imageUrl != null && activity.imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  activity.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : Container(
                          color: AppTheme.brandTonal,
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.brand500),
                          ),
                        ),
                  errorBuilder: (_, _, _) => Container(
                    color: AppTheme.brandTonal,
                    alignment: Alignment.center,
                    child: Icon(ActivityStyle.icon(activity.type),
                        size: 48, color: AppTheme.brandOnTonal),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
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
                        _typeTag(context),
                        if (activity.closed) ...[
                          const SizedBox(width: 6),
                          _statusTag(tr(context, 'closed'),
                              const Color(0xFF9CA3AF), const Color(0xFFF4F4F5)),
                        ] else if (showSoon) ...[
                          const SizedBox(width: 6),
                          _statusTag(tr(context, 'closing_soon'),
                              const Color(0xFFE53E3E), const Color(0xFFFFF0F0)),
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
          _row(Icons.apartment_outlined, tr(context, 'detail_organizer'),
              activity.organizer),
          if (activity.startDate != null)
            _row(Icons.event_outlined, tr(context, 'detail_eventdate'),
                df.format(activity.startDate!)),
          if (activity.deadline != null)
            _row(Icons.schedule, tr(context, 'detail_deadline'),
                df.format(activity.deadline!),
                highlight: showSoon),
          if (activity.location != null)
            _row(Icons.place_outlined, tr(context, 'detail_location'),
                activity.location!),
          if (cleanText(activity.description).isNotEmpty) ...[
            const Divider(height: 32),
            Text(tr(context, 'detail_content'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(cleanText(activity.description),
                style: const TextStyle(height: 1.6, color: Color(0xFF3F3F46))),
          ],
          const SizedBox(height: 28),
          if (activity.url != null) ...[
            Text(
              tr(context, 'detail_more_hint'),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _openUrl(context),
              icon: const Icon(Icons.open_in_new),
              label: Text(tr(context, 'detail_open_link')),
            ),
          ],
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

  Widget _typeTag(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.brandTonal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(activityTypeLabel(context, activity.type),
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
