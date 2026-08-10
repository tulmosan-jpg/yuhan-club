import 'package:flutter/material.dart';
import '../models/activity.dart';

/// 대외활동 종류별 색/아이콘.
class ActivityStyle {
  static Color color(ActivityType t) {
    switch (t) {
      case ActivityType.fair:
        return const Color(0xFF2E7DD1);
      case ActivityType.contest:
        return const Color(0xFFE8743B);
      case ActivityType.intern:
        return const Color(0xFF27AE60);
      case ActivityType.program:
        return const Color(0xFF9B51E0);
      case ActivityType.seminar:
        return const Color(0xFF16A085);
    }
  }

  static IconData icon(ActivityType t) {
    switch (t) {
      case ActivityType.fair:
        return Icons.storefront_outlined;
      case ActivityType.contest:
        return Icons.emoji_events_outlined;
      case ActivityType.intern:
        return Icons.work_outline;
      case ActivityType.program:
        return Icons.groups_outlined;
      case ActivityType.seminar:
        return Icons.record_voice_over_outlined;
    }
  }
}
