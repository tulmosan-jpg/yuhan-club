import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 언어(한국어/영어) 상태. 선택은 기기에 저장되어 재실행 시 유지된다.
class LocaleProvider extends ChangeNotifier {
  static const _kKey = 'app_locale';
  static const supported = [Locale('ko'), Locale('en')];

  Locale _locale = const Locale('ko');
  Locale get locale => _locale;

  /// 앱 시작 시 저장된 언어를 불러온다.
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final code = p.getString(_kKey);
    if (code == 'en' || code == 'ko') {
      _locale = Locale(code!);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale.languageCode == locale.languageCode) return;
    _locale = locale;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kKey, locale.languageCode);
  }

  Future<void> toggle() =>
      setLocale(_locale.languageCode == 'ko' ? const Locale('en') : const Locale('ko'));
}
