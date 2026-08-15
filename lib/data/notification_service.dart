import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 로컬 알림 서비스.
///
/// - 출석일 아침 리마인더 / RSVP(참석응답) 마감 리마인더를 기기에서 예약 발송한다.
/// - 서버 트리거(새 보고서·공지 등)는 무료(Spark) 구성에서 다루지 않는다.
/// - 알림 설정 화면의 SharedPreferences 토글을 그대로 존중한다.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'yuhan_reminders';
  static const _channelName = '동아리 리마인더';
  static const _channelDesc = '출석일·참석응답 리마인더 알림';

  // 알림 ID 대역(리마인더 종류별로 겹치지 않게).
  static const _attendBase = 100000; // 출석일 리마인더
  static const _rsvpBase = 200000; // RSVP 리마인더

  /// 앱 시작 시 1회 호출. 플러그인 + 타임존 초기화.
  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    // 한국 고정(앱 사용자 기준). 실패해도 UTC 로 폴백.
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } catch (_) {}

    const android = AndroidInitializationSettings('ic_notification');
    // iOS: 권한은 나중에 명시적으로 요청(여기선 false).
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
    );
    _initialized = true;
  }

  /// OS 알림 권한 요청. "허용하시겠습니까" 시스템 창을 띄운다.
  /// 반환값: 허용되면 true.
  Future<bool> requestPermission() async {
    if (!_initialized) await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
          alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return false;
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
        iOS: DarwinNotificationDetails(),
      );

  Future<bool> _pref(SharedPreferences p, String key) async =>
      p.getBool(key) ?? true;

  /// 예정 출석일/내 RSVP 응답을 바탕으로 리마인더를 다시 예약한다.
  /// 기존 예약을 모두 지우고 향후 일정만 다시 건다(멱등).
  ///
  /// - [attendanceDates]: 그룹의 출석 예정일 목록.
  /// - [respondedDays]: 이미 RSVP 응답한 날짜 키(yyyy-MM-dd) 집합.
  Future<void> syncReminders({
    required List<DateTime> attendanceDates,
    required Set<String> respondedDays,
  }) async {
    if (!_initialized) await init();
    // 웹 등 미지원 플랫폼은 조용히 무시.
    if (kIsWeb) return;

    await _plugin.cancelAll();

    final p = await SharedPreferences.getInstance();
    final master = await _pref(p, 'notif_enabled');
    if (!master) return;
    final attendOn = await _pref(p, 'n_attend_reminder');
    final rsvpOn = await _pref(p, 'n_rsvp_reminder');

    final now = tz.TZDateTime.now(tz.local);
    final upcoming = attendanceDates.map(_dayOnly).toList()..sort();

    var attendIdx = 0;
    var rsvpIdx = 0;
    for (final day in upcoming) {
      // 출석일 당일 오전 8시 리마인더.
      if (attendOn) {
        final when = tz.TZDateTime(
            tz.local, day.year, day.month, day.day, 8, 0);
        if (when.isAfter(now) && attendIdx < 30) {
          await _plugin.zonedSchedule(
            id: _attendBase + attendIdx,
            title: '오늘 동아리 출석일이에요',
            body: '오늘 모임에 출석 체크하는 것을 잊지 마세요.',
            scheduledDate: when,
            notificationDetails: _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
          attendIdx++;
        }
      }
      // 아직 참석응답 안 한 예정일: 전날 오후 6시 RSVP 리마인더.
      final key = _keyOf(day);
      if (rsvpOn && !respondedDays.contains(key)) {
        final prev = day.subtract(const Duration(days: 1));
        final when = tz.TZDateTime(
            tz.local, prev.year, prev.month, prev.day, 18, 0);
        if (when.isAfter(now) && rsvpIdx < 30) {
          await _plugin.zonedSchedule(
            id: _rsvpBase + rsvpIdx,
            title: '참석 여부를 응답해 주세요',
            body: '내일 모임 참석 여부를 아직 응답하지 않았어요.',
            scheduledDate: when,
            notificationDetails: _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
          rsvpIdx++;
        }
      }
    }
  }

  /// 모든 예약 알림 취소(로그아웃 등).
  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _keyOf(DateTime d) {
    final day = _dayOnly(d);
    final mm = day.month.toString().padLeft(2, '0');
    final dd = day.day.toString().padLeft(2, '0');
    return '${day.year}-$mm-$dd';
  }
}
