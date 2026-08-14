import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// 관리자 1명의 정보(관리자 관리 화면용).
class AdminInfo {
  final String uid;
  final String email;
  final String name;
  const AdminInfo({required this.uid, required this.email, required this.name});
}

/// Firebase Email/Password 인증 래퍼.
///
/// 이름은 [User.displayName]에 저장한다(별도 users 컬렉션 없이 단순 구성).
/// [FirebaseRepository]가 currentUser의 uid/displayName을 동적으로 읽는다.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// 이번 세션이 "관리자 로그인"으로 진입했는지. 관리자 관리 UI 노출 기준.
  bool loggedInAsAdmin = false;

  /// 로그인/로그아웃 상태 스트림. AuthGate에서 구독.
  Stream<User?> get authState => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// 현재 로그인 사용자가 관리자(admins/{uid} 존재)인지.
  Future<bool> checkIsAdmin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final doc = await _db.collection('admins').doc(uid).get();
    return doc.exists;
  }

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

  Future<void> signOut() {
    loggedInAsAdmin = false;
    return _auth.signOut();
  }

  // ── 관리자 관리 (기존 관리자만) ──

  /// 새 관리자 계정을 만들고 Firebase Authentication + admins 컬렉션에 등록.
  /// 보조 FirebaseApp으로 계정을 생성해 현재 관리자 세션은 유지된다.
  Future<void> createAdmin({
    required String email,
    required String password,
    required String name,
  }) async {
    final secondary = await Firebase.initializeApp(
      name: 'adminCreator',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      final secAuth = FirebaseAuth.instanceFor(app: secondary);
      final cred = await secAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(name.trim());
      final uid = cred.user!.uid;
      // 현재 로그인된 관리자 권한으로 admins 문서 작성.
      await _db.collection('admins').doc(uid).set({
        'email': email.trim(),
        'name': name.trim(),
        'grantedAt': FieldValue.serverTimestamp(),
      });
      await secAuth.signOut();
    } finally {
      await secondary.delete();
    }
  }

  /// 현재 관리자 목록.
  Future<List<AdminInfo>> listAdmins() async {
    final snap = await _db.collection('admins').get();
    return snap.docs.map((d) {
      final m = d.data();
      return AdminInfo(
        uid: d.id,
        email: (m['email'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
      );
    }).toList()
      ..sort((a, b) => a.email.compareTo(b.email));
  }

  /// 관리자 권한 해제(admins 문서 삭제). Authentication 계정은 남는다.
  Future<void> removeAdmin(String uid) =>
      _db.collection('admins').doc(uid).delete();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  /// FirebaseAuthException 코드를 번역 사전 키로 변환. (UI에서 tr 로 표시)
  static String errorKey(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'auth_invalid_email';
        case 'user-disabled':
          return 'auth_user_disabled';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'auth_bad_cred';
        case 'email-already-in-use':
          return 'auth_email_in_use';
        case 'weak-password':
          return 'auth_weak_pw';
        case 'network-request-failed':
          return 'auth_network';
        case 'too-many-requests':
          return 'auth_too_many';
      }
      return 'auth_generic';
    }
    if (kDebugMode) return error.toString();
    return 'auth_unknown';
  }
}
