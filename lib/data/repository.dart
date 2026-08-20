import '../models/report.dart';
import '../models/activity.dart';
import '../models/attendance.dart';
import '../models/group.dart';
import '../models/reward.dart';

/// 앱 데이터 접근 추상화. Mock / Firebase 구현 교체 가능.
abstract class AppRepository {
  // 현재 로그인 사용자(간이). 실제 앱에서는 Auth 연동.
  String get currentUserId;
  String get currentUserName;

  // ── 동아리 보고서 ──
  Future<List<MentoringReport>> fetchReports();
  Future<MentoringReport> saveReport(MentoringReport report);

  /// 현재 사용자가 관리자인지 여부.
  Future<bool> isAdmin();

  /// 관리자 전용: 모든 회원의 보고서 조회.
  Future<List<MentoringReport>> fetchAllReports();

  /// 보고서 삭제(작성자 본인 또는 관리자).
  Future<void> deleteReport(String reportId);

  /// 관리자 전용: 전체 회원의 출석 현황.
  Future<List<MemberAttendance>> fetchAllAttendance();

  // ── 대외활동/박람회 ──
  Future<List<Activity>> fetchActivities({ActivityType? type});

  // ── 연속 출석 ──
  List<RewardTier> get rewardTiers;
  Future<AttendanceSummary> fetchAttendance();

  /// 오늘 출석 체크. 이미 했으면 false 반환.
  Future<bool> checkInToday();

  // ── 출석 일정(멘토/관리자가 등록한 출석 가능 날짜) ──
  /// 출석 가능한 날짜 목록(자정 정규화).
  Future<List<DateTime>> fetchAttendanceDates();

  /// 관리자: 출석 가능 날짜 추가.
  Future<void> addAttendanceDate(DateTime date);

  /// 관리자: 출석 가능 날짜 삭제.
  Future<void> removeAttendanceDate(DateTime date);

  // ── 그룹(팀) ──
  /// 관리자: 그룹 생성(이름 + 4자리 PIN). 생성된 groupId 반환.
  Future<String> createGroup(String name, String pin);

  /// 관리자: 전체 그룹(PIN 포함).
  Future<List<Group>> fetchGroups();

  /// 관리자: 그룹 삭제.
  Future<void> deleteGroup(String groupId);

  /// 회원: 가입 가능한 그룹(멘토) 이름 목록.
  Future<List<GroupInfo>> fetchGroupIndex();

  /// 회원: 내가 가입한 그룹.
  Future<List<GroupInfo>> fetchMyGroups();

  /// 회원: PIN으로 그룹 가입. 성공 여부 반환.
  Future<bool> joinGroup(String groupId, String pin);

  /// 회원: 그룹(멘토) 탈퇴.
  Future<void> leaveGroup(String groupId);

  /// 관리자: 특정 그룹의 보고서.
  Future<List<MentoringReport>> fetchGroupReports(String groupId);

  // ── 그룹별 출석 ──
  /// 그룹의 출석 가능 날짜.
  Future<List<DateTime>> fetchGroupAttendanceDates(String groupId);

  /// 그룹 일정(날짜 + 주제). 화면 표시용.
  Future<List<ScheduleEntry>> fetchGroupSchedule(String groupId);

  /// 관리자: 그룹 출석 날짜 추가/삭제. topic 은 그날 진행 주제(선택).
  Future<void> addGroupAttendanceDate(String groupId, DateTime date,
      {String topic});
  Future<void> removeGroupAttendanceDate(String groupId, DateTime date);

  /// 회원: 그룹에 오늘 출석. 이미 했으면 false.
  Future<bool> checkInGroupToday(String groupId);

  /// 회원: 내 그룹 출석 요약.
  Future<AttendanceSummary> fetchMyGroupAttendance(String groupId);

  /// 관리자: 그룹 회원들의 출석 현황.
  Future<List<MemberAttendance>> fetchGroupMemberAttendance(String groupId);

  // ── 참석 응답(RSVP) ──
  /// 회원: 특정 출석일 참석 여부 + 사유 설정.
  Future<void> setRsvp(
      String groupId, DateTime day, bool available, String reason);

  /// 회원: 내 RSVP(날짜키 → 응답).
  Future<Map<String, Rsvp>> fetchMyRsvp(String groupId);

  /// 관리자: 그룹 전체 회원의 RSVP.
  Future<List<Rsvp>> fetchGroupRsvp(String groupId);

  // ── 리워드(빽다방 쿠폰) ──
  /// 리워드 설정/재고(사용코드 + 종목별 남은 수량).
  Future<RewardConfig> fetchRewardConfig();

  /// 관리자: 사용완료 코드(4자리) 설정.
  Future<void> setRewardCode(String code);

  /// 관리자: 종목별 재고 설정.
  Future<void> setDrinkStock(String drinkId, int count);

  /// 회원: 내 쿠폰 목록(최신순).
  Future<List<Coupon>> fetchMyCoupons();

  /// 관리자: 전체 발급 쿠폰.
  Future<List<Coupon>> fetchAllCoupons();

  /// 회원: 지금까지 지급받을 자격이 있는 쿠폰 수(스트릭 2회당 1개)에서
  /// 이미 받은 수를 뺀 '지금 받을 수 있는' 개수.
  Future<int> fetchAvailableCoupons(AttendanceSummary summary);

  /// 회원: 음료를 골라 쿠폰 1개 발급(재고 차감, 자격 재확인).
  /// 성공 시 발급된 쿠폰, 재고 소진/자격 없음이면 예외.
  Future<Coupon> claimCoupon(String drinkId, AttendanceSummary summary);

  /// 매장 직원: 코드 입력으로 쿠폰 사용 완료 처리.
  /// 코드 불일치면 false, 성공하면 true.
  Future<bool> redeemCoupon(String couponId, String code);

  // ── 앱 초기화 ──
  /// 내 서버 데이터(보고서·쿠폰·출석·멤버십·프로필/설정) 전체 삭제.
  /// 호출 후 로그아웃을 수행한다.
  Future<void> resetMyAccount();

  // ── 관리자: 멤버 계정 찾기/비밀번호 재설정 ──
  /// 관리자: 그룹 멤버들의 로그인 아이디(이메일) 조회.
  Future<List<MemberAccount>> fetchGroupMemberAccounts(String groupId);

  /// 관리자: 멤버의 임시 비밀번호를 발급(재설정). (email, password) 반환.
  Future<({String email, String password})> resetMemberPassword(String uid);
}

/// 대외활동 목록 정렬 기준.
///
/// 진행 중(미마감) 활동을 먼저 보여주되 마감 임박 순(마감일 오름차순),
/// 지난(마감된) 활동은 뒤로 보내되 최근에 마감된 것부터(마감일 내림차순).
int activityOrder(Activity a, Activity b) {
  final ac = a.closed, bc = b.closed;
  if (ac != bc) return ac ? 1 : -1; // 진행 중 먼저
  final ad = a.deadline ?? a.startDate ?? DateTime(2100);
  final bd = b.deadline ?? b.startDate ?? DateTime(2100);
  // 진행 중: 오름차순(임박 먼저) / 지난 활동: 내림차순(최근 마감 먼저)
  return ac ? bd.compareTo(ad) : ad.compareTo(bd);
}
