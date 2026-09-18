import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app/app_config.dart';
import 'app/auth_gate.dart';
import 'app/intro_screen.dart';
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

  // App Check: 정품 앱에서 온 요청만 통과시키기 위한 토큰을 발급/전송한다.
  // 서버(Functions·Firestore) 강제는 신 빌드가 스토어에 보급된 뒤 켠다
  // — 지금 켜면 토큰을 안 보내는 기존 버전이 전부 막힌다.
  //
  // 디버그/시뮬레이터: Play Integrity·DeviceCheck 가 동작하지 않으므로
  // debug provider 사용(콘솔에 디버그 토큰 등록 필요).
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? AndroidDebugProvider()
          : AndroidPlayIntegrityProvider(),
      providerApple:
          kDebugMode ? AppleDebugProvider() : AppleDeviceCheckProvider(),
    );
  } catch (_) {
    // 활성화 실패(네트워크 등)해도 앱은 계속 뜨게 둔다.
  }

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
          home: const _Entry(),
        ),
      ),
    );
  }
}

/// 인트로 모션 → 본 화면(AuthGate).
///
/// AuthGate 를 인트로 뒤에 붙이는 이유: AuthGate 진입 시 업데이트 안내
/// 다이얼로그가 뜨는데, 인트로와 겹치면 안 되기 때문이다.
class _Entry extends StatefulWidget {
  const _Entry();

  @override
  State<_Entry> createState() => _EntryState();
}

class _EntryState extends State<_Entry> {
  bool _introDone = false;

  @override
  void initState() {
    super.initState();
    // 재시작(자동 로그인) 시 지난 세션의 유형(관리자/회원)을 복원한다.
    // 인트로가 도는 동안 로드되므로 화면 깜빡임이 없다.
    LoginPrefs.adminSessionEnabled().then((v) {
      if (mounted && FirebaseAuth.instance.currentUser != null) {
        context.read<AuthService>().loggedInAsAdmin = v;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_introDone) return const AuthGate();
    return IntroScreen(
      onDone: () {
        if (mounted) setState(() => _introDone = true);
      },
    );
  }
}
