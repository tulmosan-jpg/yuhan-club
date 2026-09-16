import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_config.dart';
import '../l10n/app_strings.dart';
import '../widgets/app_dialog.dart';

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

      // 앱 공용 브랜드 다이얼로그(흰 카드 + 아이콘 배지 + 나란한 버튼).
      // force 면 '나중에' 없이 액션만, 바깥 탭으로도 닫히지 않는다.
      do {
        final go = await showConfirmDialog(
          context: context,
          icon: Icons.system_update_alt_rounded,
          title: tr(context, 'update_title'),
          message: tr(context, 'update_body'),
          confirmText: tr(context, 'update_now'),
          cancelText: tr(context, 'update_later'),
          showCancel: !force,
          barrierDismissible: !force,
        );
        if (go && url != null && url.isNotEmpty) {
          await launchUrl(Uri.parse(url),
              mode: LaunchMode.externalApplication);
        }
        if (!context.mounted) return;
        // 강제 업데이트면 스토어에 다녀와도 계속 막는다.
      } while (force);
    } catch (_) {
      // 네트워크/설정 없음 → 조용히 무시.
    }
  }
}
