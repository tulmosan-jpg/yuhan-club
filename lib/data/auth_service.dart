import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'messaging_service.dart';
import 'notification_service.dart';

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

  /// 이번 세션이 "관리자 로그인"으로 진입했는지. 관리자 UI 노출 기준.
  ///
  /// ValueNotifier 인 이유: 로그인 화면이 `signIn()` 을 호출하는 순간
  /// authStateChanges 가 먼저 터져 AuthGate → HomeScreen 이 이미 만들어진다.
  /// 그 뒤에 관리자 검증이 끝나므로, 플래그가 켜지면 화면이 다시 그려져야 한다.
  final ValueNotifier<bool> adminSession = ValueNotifier<bool>(false);

  bool get loggedInAsAdmin => adminSession.value;
  set loggedInAsAdmin(bool v) => adminSession.value = v;

  /// 로그인/로그아웃 상태 스트림. AuthGate에서 구독.
  /// 매번 새 스트림을 만들면 AuthGate 리빌드마다 재구독 → 로딩 스피너가
  /// 깜빡이므로 한 번만 만들어 재사용한다.
  late final Stream<User?> authState = _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// 현재 로그인 사용자가 관리자(admins/{uid} 존재)인지.
  ///
  /// 로그인 직후에는 인증 토큰이 Firestore 에 아직 반영되지 않아
  /// permission-denied / unavailable 이 한 번 날 수 있다. 그때 바로 false 로
  /// 단정하면 관리자가 일반 회원 화면으로 들어가 버리므로 짧게 재시도한다.
  Future<bool> checkIsAdmin({int retries = 2}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    for (var attempt = 0;; attempt++) {
      try {
        final doc = await _db.collection('admins').doc(uid).get();
        return doc.exists;
      } catch (e) {
        if (attempt >= retries) rethrow;
        await Future<void>.delayed(
            Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
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

  Future<void> signOut() async {
    loggedInAsAdmin = false;
    // 이 기기 FCM 토큰 제거(로그아웃한 계정에 푸시가 가지 않도록).
    await MessagingService.instance.removeToken();
    await NotificationService.instance.cancelAll();
    await _auth.signOut();
  }

  // ── 관리자 관리 (기존 관리자만) ──

  /// 새 관리자 계정을 만들고 Firebase Authentication + admins 컬렉션에 등록.
  /// 보조 FirebaseApp으로 계정을 생성해 현재 관리자 세션은 유지된다.
  ///
  /// 계정 생성과 admins 문서 작성은 두 단계라, 예전에는 중간에 실패하면
  /// Authentication 에만 계정이 남고 관리자 목록에는 안 들어갔다. 그 상태로
  /// 다시 시도하면 email-already-in-use 로 영영 등록되지 않았다.
  /// 이제 이미 있는 계정이면 로그인해 uid 를 얻어 admins 문서만 마저 쓴다.
  Future<void> createAdmin({
    required String email,
    required String password,
    required String name,
  }) async {
    // 앱 이름을 매번 다르게: 이전 시도가 정리되지 않아도 duplicate-app 이 안 난다.
    final appName =
        'adminCreator_${DateTime.now().microsecondsSinceEpoch}';
    final secondary = await Firebase.initializeApp(
      name: appName,
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try {
      final secAuth = FirebaseAuth.instanceFor(app: secondary);
      User? user;
      try {
        final cred = await secAuth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        user = cred.user;
        await user?.updateDisplayName(name.trim());
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') rethrow;
        // 계정은 이미 있다(이전 시도의 잔여물이거나 기존 회원).
        // 비밀번호가 맞으면 uid 를 얻어 관리자 등록만 마저 진행한다.
        final cred = await secAuth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        user = cred.user;
      }

      final uid = user?.uid;
      if (uid == null) {
        throw FirebaseAuthException(
            code: 'admin-create-no-uid',
            message: '계정 uid 를 확인하지 못했습니다.');
      }

      // 현재 로그인된 관리자 권한으로 admins 문서 작성.
      final doc = _db.collection('admins').doc(uid);
      await doc.set({
        'email': email.trim(),
        'name': name.trim(),
        'grantedAt': FieldValue.serverTimestamp(),
      });

      // 서버에 실제로 반영됐는지 확인한다.
      // Firestore 는 오프라인 캐시가 기본이라 서버가 거부한 쓰기도 로컬에는
      // 즉시 반영된다. 그러면 추가한 기기 목록에만 보이고 다른 기기에서는
      // 안 보이는 상태가 된다 — 여기서 잡아 실패로 알린다.
      final saved = await doc.get(const GetOptions(source: Source.server));
      if (!saved.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'admin-write-not-synced',
          message: '관리자 등록이 서버에 저장되지 않았습니다. 네트워크를 확인해주세요.',
        );
      }
      await secAuth.signOut();
    } finally {
      await secondary.delete();
    }
  }

  /// 현재 관리자 목록.
  Future<List<AdminInfo>> listAdmins() async {
    // 서버에서 직접 읽는다. 캐시를 읽으면 서버가 거부한 로컬 쓰기가
    // 그 기기 목록에만 남아 다른 기기와 어긋난다.
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _db
          .collection('admins')
          .get(const GetOptions(source: Source.server));
    } catch (_) {
      snap = await _db.collection('admins').get(); // 오프라인이면 캐시
    }
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

  Future<void> sendPasswordReset(String email) async {
    // 재설정 메일과 링크가 여는 페이지(만료/오류 안내 포함)를 한국어로.
    await _auth.setLanguageCode('ko');
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

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
