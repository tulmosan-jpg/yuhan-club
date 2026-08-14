import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 화면의 "아이디 저장" / "자동 로그인" 설정을 로컬에 보관.
class LoginPrefs {
  static const _kRememberEmail = 'remember_email';
  static const _kSavedEmail = 'saved_email';
  static const _kAutoLogin = 'auto_login';

  final bool rememberEmail;
  final String savedEmail;
  final bool autoLogin;

  const LoginPrefs({
    required this.rememberEmail,
    required this.savedEmail,
    required this.autoLogin,
  });

  static Future<LoginPrefs> load() async {
    final p = await SharedPreferences.getInstance();
    return LoginPrefs(
      rememberEmail: p.getBool(_kRememberEmail) ?? false,
      savedEmail: p.getString(_kSavedEmail) ?? '',
      autoLogin: p.getBool(_kAutoLogin) ?? false,
    );
  }

  /// 자동 로그인 여부만 빠르게 확인 (콜드 스타트 게이트용).
  static Future<bool> autoLoginEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kAutoLogin) ?? false;
  }

  /// 로그인 성공 시 호출해 설정을 저장.
  static Future<void> save({
    required bool rememberEmail,
    required String email,
    required bool autoLogin,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kRememberEmail, rememberEmail);
    await p.setBool(_kAutoLogin, autoLogin);
    if (rememberEmail) {
      await p.setString(_kSavedEmail, email.trim());
    } else {
      await p.remove(_kSavedEmail);
    }
  }
}
