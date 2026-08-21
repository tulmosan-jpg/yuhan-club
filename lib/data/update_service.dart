import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_config.dart';
import '../l10n/app_strings.dart';

/// 앱 업데이트 안내.
///
/// Firestore `config/app` 문서에 최신 빌드번호와 스토어 URL을 두고,
/// 현재 앱 빌드번호와 비교해 더 높으면 업데이트 안내 다이얼로그를 띄운다.
/// 새 버전을 스토어에 올린 뒤 `config/app.latestBuild` 를 그 빌드번호로
/// 올리면 기존 사용자에게 알림이 뜬다. (force=true 면 '나중에' 없이 강제)
class UpdateService {
  static bool _shownThisSession = false;

  static Future<void> maybePrompt(BuildContext context) async {
    // 웹/목업은 스토어 앱이 아니므로 건너뜀. 세션당 1회만.
    if (kIsWeb || AppConfig.useMock || _shownThisSession) return;
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('app')
          .get();
      final data = doc.data();
      if (data == null) return;
      final latest = (data['latestBuild'] as num?)?.toInt() ?? 0;
      if (latest <= current) return;

      final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
      final url = (isIOS ? data['iosUrl'] : data['androidUrl']) as String?;
      final force = data['force'] == true;
      if (!context.mounted) return;
      _shownThisSession = true;

      await showDialog<void>(
        context: context,
        barrierDismissible: !force,
        builder: (dctx) => AlertDialog(
          title: Text(tr(dctx, 'update_title'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(tr(dctx, 'update_body')),
          actions: [
            if (!force)
              TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: Text(tr(dctx, 'update_later')),
              ),
            FilledButton(
              onPressed: () async {
                if (url != null && url.isNotEmpty) {
                  await launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                }
              },
              child: Text(tr(dctx, 'update_now')),
            ),
          ],
        ),
      );
    } catch (_) {
      // 네트워크/설정 없음 → 조용히 무시.
    }
  }
}
