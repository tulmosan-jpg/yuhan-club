import 'package:cloud_firestore/cloud_firestore.dart';

/// 하루 출석 기록
class AttendanceRecord {
  final String id;
  final String userId;
  final DateTime date; // 날짜(자정 기준)

  const AttendanceRecord({
    required this.id,
    required this.userId,
    required this.date,
  });

  /// 자정 기준으로 정규화한 날짜 키(yyyy-MM-dd 비교용)
  static DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Firestore 문서 ID로 쓰는 날짜 키 'yyyy-MM-dd'.
  static String keyOf(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> map) {
    return AttendanceRecord(
      id: id,
      userId: map['userId'] as String? ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'date': Timestamp.fromDate(date),
      };
}

/// 관리자 출석 확인용: 회원 1명의 출석 요약
class MemberAttendance {
  final String userId;
  final String name;
  final AttendanceSummary summary;

  const MemberAttendance({
    required this.userId,
    required this.name,
    required this.summary,
  });
}

/// 참석 응답(RSVP): 특정 출석일에 대한 참석 가능/불가능 + 사유.
class Rsvp {
  final String userId;
  final String userName;
  final DateTime day;
  final bool available; // true=참석 가능, false=불가능
  final String reason; // 불가능 사유

  const Rsvp({
    required this.userId,
    required this.userName,
    required this.day,
    required this.available,
    this.reason = '',
  });
}

/// 연속 출석 보상 단계 (학과회비로 상품 제공)
class RewardTier {
  final int streak; // 필요한 연속 출석 횟수
  final String reward; // 상품명

  const RewardTier(this.streak, this.reward);
}

/// 출석 현황 요약 (스트릭 계산 결과)
class AttendanceSummary {
  final int currentStreak; // 현재 연속 출석
  final int totalDays; // 누적 출석일
  final bool checkedInToday;
  final List<DateTime> recentDays; // 최근 출석일(달력 표시용)

  const AttendanceSummary({
    required this.currentStreak,
    required this.totalDays,
    required this.checkedInToday,
    required this.recentDays,
  });

  /// 다음으로 달성 가능한 보상 단계
  RewardTier? nextTier(List<RewardTier> tiers) {
    for (final t in tiers) {
      if (currentStreak < t.streak) return t;
    }
    return null;
  }

  /// 현재 달성한 보상 단계들
  List<RewardTier> achievedTiers(List<RewardTier> tiers) =>
      tiers.where((t) => currentStreak >= t.streak).toList();
}
