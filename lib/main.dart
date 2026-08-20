import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app/app_config.dart';
import 'app/auth_gate.dart';
import 'app/theme.dart';
import 'data/auth_service.dart';
import 'data/login_prefs.dart';
import 'data/notification_service.dart';
import 'data/repository.dart';
import 'firebase_options.dart';
import 'l10n/locale_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko');

  // Android 15+ Edge-to-Edge: 시스템바를 투명으로 두고 앱이 화면 끝까지 그린다.
  // (콘텐츠는 각 화면의 SafeArea/AppBar/NavigationBar가 인셋을 처리해 겹치지 않음)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // 밝은 배경 → 어두운 아이콘
    statusBarBrightness: Brightness.light, // iOS
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  ));

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 자동 로그인 게이트: 콜드 스타트 시 자동 로그인을 켜지 않았다면
  // 이전 세션에 남아있는 로그인을 해제해 로그인 화면부터 시작한다.
  // (앱 실행 중 새로 로그인한 세션에는 영향 없음 — 여기는 시작 1회만 실행)
  if (!AppConfig.useMock && FirebaseAuth.instance.currentUser != null) {
    final autoLogin = await LoginPrefs.autoLoginEnabled();
    if (!autoLogin) {
      await FirebaseAuth.instance.signOut();
    }
  }

  // 로컬 알림 플러그인 초기화(권한 요청은 로그인 후 대시보드에서).
  await NotificationService.instance.init();

  final localeProvider = LocaleProvider();
  await localeProvider.load();

  runApp(YuhanFnApp(localeProvider: localeProvider));
}

class YuhanFnApp extends StatelessWidget {
  const YuhanFnApp({super.key, required this.localeProvider});
  final LocaleProvider localeProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        // 최상위에서 제공 → push 된 화면들도 접근 가능.
        Provider<AppRepository>(create: (_) => AppConfig.createRepository()),
        ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, lp, _) => MaterialApp(
          title: AppConfig.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: lp.locale,
          supportedLocales: LocaleProvider.supported,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AuthGate(),
        ),
      ),
    );
  }
}
