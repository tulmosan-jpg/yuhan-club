import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/activity_style.dart';
import '../../models/activity.dart';

/// 대외활동 썸네일. imageUrl 이 있으면 이미지를, 없으면(위비티 등)
/// 브랜드 톤 배경 + 타입 아이콘으로 대체한다. 로딩/실패도 폴백 처리.
class ActivityThumb extends StatelessWidget {
  const ActivityThumb({
    super.key,
    required this.imageUrl,
    required this.type,
    this.size = 92,
    this.radius = 16,
  });

  final String? imageUrl;
  final ActivityType type;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: (url == null || url.isEmpty)
            ? _fallback()
            : Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _fallback(loading: true);
                },
                errorBuilder: (_, _, _) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback({bool loading = false}) {
    return Container(
      color: AppTheme.brandTonal,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.brand500,
              ),
            )
          : Icon(ActivityStyle.icon(type),
              size: size * 0.36, color: AppTheme.brandOnTonal),
    );
  }
}
