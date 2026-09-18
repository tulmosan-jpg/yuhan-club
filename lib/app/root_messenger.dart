import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// 앱 전역 ScaffoldMessenger 키.
///
/// 로그인/회원가입처럼 `signIn()`·`createUser()` 직후 authStateChanges 가
/// 화면을 교체해 State 가 dispose 되는 흐름에서는, 그 State 의 context 로
/// 스낵바를 띄울 수 없다(mounted=false → 에러가 조용히 사라짐).
/// 이 키로 띄우면 화면 교체와 무관하게 항상 표시된다.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// 전역 스낵바. State dispose 여부와 무관하게 표시된다.
void showGlobalSnack(String key, {Map<String, String>? params}) {
  final ctx = rootMessengerKey.currentContext;
  final state = rootMessengerKey.currentState;
  if (ctx == null || state == null) return;
  state.showSnackBar(SnackBar(content: Text(tr(ctx, key, params))));
}
