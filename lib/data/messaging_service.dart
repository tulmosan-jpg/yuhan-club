import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// FCM(서버 푸시) 연동.
///
/// - 로그인 후 FCM 토큰을 발급받아 `users/{uid}.fcmTokens` 배열에 저장한다.
/// - 알림 설정(SharedPreferences 토글)을 같은 문서에 동기화 → Cloud Functions 가
///   수신자 필터에 사용한다.
/// - 포그라운드 메시지는 로컬 알림으로 표시한다.
/// - 서버 발송은 Cloud Functions(무료 Blaze 한도 내)에서 수행.
class MessagingService {
  MessagingService._();
  static final MessagingService instance = MessagingService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _wired = false;
  String? _currentToken;

  /// 서버 알림 종류 → SharedPreferences 키.
  /// (Firestore users 문서에도 같은 키로 동기화)
  static const prefKeys = <String>[
    'notif_enabled',
    'n_schedule_added',
    'n_new_notice',
    'n_new_report',
    'n_rsvp_declined',
  ];

  DocumentReference<Map<String, dynamic>>? get _userDoc {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid);
  }

  /// 로그인 직후 호출. 권한 요청 + 토큰 저장 + 리스너 등록.
  Future<void> start() async {
    if (kIsWeb) return;
    try {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);

      await syncPrefs();

      final token = await _fcm.getToken();
      if (token != null) await _saveToken(token);

      if (!_wired) {
        _wired = true;
        _fcm.onTokenRefresh.listen(_saveToken);
        FirebaseMessaging.onMessage.listen((msg) {
          final n = msg.notification;
          if (n != null) {
            NotificationService.instance
                .show(n.title ?? '알림', n.body ?? '');
          }
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('MessagingService.start error: $e');
    }
  }

  /// 알림 설정 토글을 Firestore users 문서에 동기화.
  Future<void> syncPrefs() async {
    final doc = _userDoc;
    if (doc == null) return;
    final p = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final k in prefKeys) {
      data[k] = p.getBool(k) ?? true;
    }
    await doc.set(data, SetOptions(merge: true));
  }

  Future<void> _saveToken(String token) async {
    _currentToken = token;
    final doc = _userDoc;
    if (doc == null) return;
    await doc.set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  /// 로그아웃 시 현재 기기 토큰 제거(다른 기기 토큰은 유지).
  Future<void> removeToken() async {
    try {
      final doc = _userDoc;
      final token = _currentToken ?? await _fcm.getToken();
      if (doc != null && token != null) {
        await doc.set({
          'fcmTokens': FieldValue.arrayRemove([token]),
        }, SetOptions(merge: true));
      }
      await _fcm.deleteToken();
      _currentToken = null;
    } catch (_) {}
  }
}
