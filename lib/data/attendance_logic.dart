import '../models/attendance.dart';

/// 출석 날짜 목록으로부터 스트릭/요약을 계산하는 공용 로직.
class AttendanceLogic {
  /// 음료 리워드를 받기 위한 연속 출석 횟수.
  static const int coffeeStreak = 2;

  /// 스트릭 트랙에 표시할 칸 수(보상 기준과 별개로 시각적 길이 유지).
  static const int streakTrackDays = 5;

  /// 보상 단계 (더벤티 음료 쿠폰).
  static const List<RewardTier> defaultTiers = [
    RewardTier(coffeeStreak, '더벤티 음료 쿠폰'),
  ];

  /// [days]는 출석한 날짜들(자정 정규화 권장).
  ///
  /// [schedule]이 주어지면 **모임 예정일 기준**으로 연속 출석을 센다:
  /// 오늘까지의 예정일을 최신순으로 훑어, 출석한 예정일이 연속되는 동안
  /// 카운트하고 첫 결석에서 멈춘다(주 단위 등 하루 간격이 아닌 일정에 맞음).
  /// [schedule]이 없으면 달력상 연속일 기준(개인 출석 등 하위호환).
  static AttendanceSummary summarize(List<DateTime> days,
      {List<DateTime>? schedule}) {
    final daySet = days.map(AttendanceRecord.dayOf).toSet();
    final normalized = daySet.toList()..sort();

    final today = AttendanceRecord.dayOf(DateTime.now());
    final checkedInToday = daySet.contains(today);

    int streak = 0;
    if (schedule != null && schedule.isNotEmpty) {
      // 오늘까지의 예정일(내림차순). 단, 오늘 모임은 아직 진행 중이므로
      // 미출석이면 '결석'으로 간주하지 않고 건너뛴다.
      final past = schedule
          .map(AttendanceRecord.dayOf)
          .toSet()
          .where((d) =>
              !d.isAfter(today) && !(d == today && !checkedInToday))
          .toList()
        ..sort((a, b) => b.compareTo(a));
      for (final d in past) {
        if (daySet.contains(d)) {
          streak++;
        } else {
          break;
        }
      }
    } else {
      // 오늘(또는 어제)부터 하루씩 거슬러 올라가며 카운트.
      var cursor =
          checkedInToday ? today : today.subtract(const Duration(days: 1));
      while (daySet.contains(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }

    return AttendanceSummary(
      currentStreak: streak,
      totalDays: normalized.length,
      checkedInToday: checkedInToday,
      recentDays: normalized,
    );
  }
}
