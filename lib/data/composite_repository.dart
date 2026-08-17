import '../models/report.dart';
import '../models/activity.dart';
import '../models/attendance.dart';
import '../models/group.dart';
import '../models/reward.dart';
import 'repository.dart';
import 'api_repository.dart';

/// 대외활동 목록을 두 소스에서 합친다:
///   - 운영진 등록분: 기존 저장소([base] = Mock/Firebase)
///   - 자동 수집분: activity-api([_api])
///
/// 보고서/출석 등 나머지 기능은 전부 [base] 로 그대로 위임한다.
class CompositeRepository implements AppRepository {
  CompositeRepository({required this.base, required ActivityApiClient api})
      : _api = api;

  final AppRepository base;
  final ActivityApiClient _api;

  @override
  String get currentUserId => base.currentUserId;
  @override
  String get currentUserName => base.currentUserName;

  @override
  List<RewardTier> get rewardTiers => base.rewardTiers;

  @override
  Future<List<MentoringReport>> fetchReports() => base.fetchReports();
  @override
  Future<MentoringReport> saveReport(MentoringReport r) => base.saveReport(r);
  @override
  Future<bool> isAdmin() => base.isAdmin();
  @override
  Future<List<MentoringReport>> fetchAllReports() => base.fetchAllReports();
  @override
  Future<void> deleteReport(String id) => base.deleteReport(id);
  @override
  Future<List<MemberAttendance>> fetchAllAttendance() =>
      base.fetchAllAttendance();
  @override
  Future<String> createGroup(String name, String pin) =>
      base.createGroup(name, pin);
  @override
  Future<List<Group>> fetchGroups() => base.fetchGroups();
  @override
  Future<void> deleteGroup(String id) => base.deleteGroup(id);
  @override
  Future<List<GroupInfo>> fetchGroupIndex() => base.fetchGroupIndex();
  @override
  Future<List<GroupInfo>> fetchMyGroups() => base.fetchMyGroups();
  @override
  Future<bool> joinGroup(String id, String pin) => base.joinGroup(id, pin);
  @override
  Future<List<MentoringReport>> fetchGroupReports(String id) =>
      base.fetchGroupReports(id);
  @override
  Future<List<DateTime>> fetchGroupAttendanceDates(String id) =>
      base.fetchGroupAttendanceDates(id);
  @override
  Future<List<ScheduleEntry>> fetchGroupSchedule(String id) =>
      base.fetchGroupSchedule(id);
  @override
  Future<void> addGroupAttendanceDate(String id, DateTime d,
          {String topic = ''}) =>
      base.addGroupAttendanceDate(id, d, topic: topic);
  @override
  Future<void> removeGroupAttendanceDate(String id, DateTime d) =>
      base.removeGroupAttendanceDate(id, d);
  @override
  Future<bool> checkInGroupToday(String id) => base.checkInGroupToday(id);
  @override
  Future<AttendanceSummary> fetchMyGroupAttendance(String id) =>
      base.fetchMyGroupAttendance(id);
  @override
  Future<List<MemberAttendance>> fetchGroupMemberAttendance(String id) =>
      base.fetchGroupMemberAttendance(id);
  @override
  Future<void> setRsvp(String id, DateTime day, bool a, String r) =>
      base.setRsvp(id, day, a, r);
  @override
  Future<Map<String, Rsvp>> fetchMyRsvp(String id) => base.fetchMyRsvp(id);
  @override
  Future<List<Rsvp>> fetchGroupRsvp(String id) => base.fetchGroupRsvp(id);

  @override
  Future<RewardConfig> fetchRewardConfig() => base.fetchRewardConfig();
  @override
  Future<void> setRewardCode(String code) => base.setRewardCode(code);
  @override
  Future<void> setDrinkStock(String id, int count) =>
      base.setDrinkStock(id, count);
  @override
  Future<List<Coupon>> fetchMyCoupons() => base.fetchMyCoupons();
  @override
  Future<List<Coupon>> fetchAllCoupons() => base.fetchAllCoupons();
  @override
  Future<int> fetchAvailableCoupons(AttendanceSummary s) =>
      base.fetchAvailableCoupons(s);
  @override
  Future<Coupon> claimCoupon(String drinkId, AttendanceSummary s) =>
      base.claimCoupon(drinkId, s);
  @override
  Future<bool> redeemCoupon(String couponId, String code) =>
      base.redeemCoupon(couponId, code);

  @override
  Future<AttendanceSummary> fetchAttendance() => base.fetchAttendance();
  @override
  Future<bool> checkInToday() => base.checkInToday();
  @override
  Future<List<DateTime>> fetchAttendanceDates() => base.fetchAttendanceDates();
  @override
  Future<void> addAttendanceDate(DateTime d) => base.addAttendanceDate(d);
  @override
  Future<void> removeAttendanceDate(DateTime d) => base.removeAttendanceDate(d);

  @override
  Future<List<Activity>> fetchActivities({ActivityType? type}) async {
    final results = await Future.wait([
      base.fetchActivities(type: type),
      _api.fetchActivities(type: type).catchError((_) => <Activity>[]),
    ]);
    final admin = results[0];
    final api = results[1];

    // id 중복 제거(운영진 등록분 우선)
    final seen = {for (final a in admin) a.id};
    final merged = [...admin, ...api.where((a) => !seen.contains(a.id))];

    merged.sort(activityOrder);
    return merged;
  }
}
