import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase Email/Password 인증 래퍼.
///
/// 이름은 [User.displayName]에 저장한다(별도 users 컬렉션 없이 단순 구성).
/// [FirebaseRepository]가 currentUser의 uid/displayName을 동적으로 읽는다.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// 로그인/로그아웃 상태 스트림. AuthGate에서 구독.
  Stream<User?> get authState => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// 회원가입 후 이름을 displayName에 저장.
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user?.updateDisplayName(name.trim());
    await cred.user?.reload();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  /// FirebaseAuthException 코드를 한국어 메시지로 변환.
  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return '이메일 형식이 올바르지 않습니다.';
        case 'user-disabled':
          return '비활성화된 계정입니다.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return '이메일 또는 비밀번호가 올바르지 않습니다.';
        case 'email-already-in-use':
          return '이미 가입된 이메일입니다.';
        case 'weak-password':
          return '비밀번호는 6자 이상이어야 합니다.';
        case 'network-request-failed':
          return '네트워크 연결을 확인해주세요.';
        case 'too-many-requests':
          return '잠시 후 다시 시도해주세요.';
      }
      return error.message ?? '인증 오류가 발생했습니다.';
    }
    if (kDebugMode) return error.toString();
    return '알 수 없는 오류가 발생했습니다.';
  }
}
