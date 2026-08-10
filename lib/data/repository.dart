import '../models/report.dart';
import '../models/activity.dart';
import '../models/attendance.dart';

/// 앱 데이터 접근 추상화. Mock / Firebase 구현 교체 가능.
abstract class AppRepository {
  // 현재 로그인 사용자(간이). 실제 앱에서는 Auth 연동.
  String get currentUserId;
  String get currentUserName;

  // ── 멘토-멘티 보고서 ──
  Future<List<MentoringReport>> fetchReports();
  Future<MentoringReport> saveReport(MentoringReport report);

  // ── 대외활동/박람회 ──
  Future<List<Activity>> fetchActivities({ActivityType? type});

  // ── 연속 출석 ──
  List<RewardTier> get rewardTiers;
  Future<AttendanceSummary> fetchAttendance();

  /// 오늘 출석 체크. 이미 했으면 false 반환.
  Future<bool> checkInToday();
}
