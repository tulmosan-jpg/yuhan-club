import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/auth_service.dart';
import '../data/repository.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home_screen.dart';
import 'app_config.dart';

/// 로그인 상태에 따라 화면을 전환하는 진입점.
///
/// - Mock 모드(USE_MOCK=true): 로그인 없이 바로 홈(오프라인/디자인 확인용).
/// - 실제 모드: Firebase Auth authStateChanges 를 구독해
///   미로그인 → [LoginScreen], 로그인 → 해당 사용자 기준 [HomeScreen].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock 모드에선 Auth 를 건너뛴다.
    if (AppConfig.useMock) {
      return Provider<AppRepository>(
        create: (_) => AppConfig.createRepository(),
        child: const HomeScreen(),
      );
    }

    return StreamBuilder<User?>(
      stream: context.read<AuthService>().authState,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }
        // 사용자가 바뀌면 key 로 Provider(및 저장소)를 재생성한다.
        // 사용자 uid/이름은 FirebaseRepository 가 Auth 에서 직접 읽는다.
        return Provider<AppRepository>(
          key: ValueKey(user.uid),
          create: (_) => AppConfig.createRepository(),
          child: const HomeScreen(),
        );
      },
    );
  }
}
