import '../models/attendance.dart';

/// 출석 날짜 목록으로부터 스트릭/요약을 계산하는 공용 로직.
class AttendanceLogic {
  /// 커피 보상을 받기 위한 연속 출석 횟수(학과회비로 제공).
  static const int coffeeStreak = 5;

  /// 보상 단계 (커피 한 종류만).
  static const List<RewardTier> defaultTiers = [
    RewardTier(coffeeStreak, '커피 기프티콘'),
  ];

  /// [days]는 출석한 날짜들(자정 정규화 권장).
  static AttendanceSummary summarize(List<DateTime> days) {
    final normalized = days
        .map(AttendanceRecord.dayOf)
        .toSet()
        .toList()
      ..sort();

    final today = AttendanceRecord.dayOf(DateTime.now());
    final checkedInToday = normalized.contains(today);

    // 현재 연속 출석: 오늘(또는 어제)부터 하루씩 거슬러 올라가며 카운트.
    int streak = 0;
    var cursor = checkedInToday
        ? today
        : today.subtract(const Duration(days: 1));
    final daySet = normalized.toSet();
    while (daySet.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return AttendanceSummary(
      currentStreak: streak,
      totalDays: normalized.length,
      checkedInToday: checkedInToday,
      recentDays: normalized,
    );
  }
}
