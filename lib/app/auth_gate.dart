import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/auth_service.dart';
import '../data/update_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home_screen.dart';
import 'app_config.dart';

/// 로그인 상태에 따라 화면을 전환하는 진입점.
///
/// - Mock 모드(USE_MOCK=true): 로그인 없이 바로 홈(오프라인/디자인 확인용).
/// - 실제 모드: Firebase Auth authStateChanges 를 구독해
///   미로그인 → [LoginScreen], 로그인 → [HomeScreen].
///
/// AppRepository 는 main.dart 최상위(MaterialApp 위)에서 제공하므로
/// push 된 화면들도 접근할 수 있다. FirebaseRepository 가 uid 를 동적으로 읽어
/// 사용자별 재생성이 필요 없다.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // 앱 진입 직후(= 로그인 화면 포함) 업데이트 안내.
    // 여기서 띄워야 로그인 전 사용자와 관리자(대시보드를 거치지 않음) 모두
    // 안내를 받는다. config/app 은 로그아웃 상태에서도 읽을 수 있어야 한다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.maybePrompt(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (AppConfig.useMock) return const HomeScreen();

    return StreamBuilder<User?>(
      stream: context.read<AuthService>().authState,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == null
            ? const LoginScreen()
            : const HomeScreen();
      },
    );
  }
}
