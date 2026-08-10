import '../models/report.dart';
import '../models/activity.dart';
import '../models/attendance.dart';
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
  Future<AttendanceSummary> fetchAttendance() => base.fetchAttendance();
  @override
  Future<bool> checkInToday() => base.checkInToday();

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

    merged.sort((a, b) {
      final ad = a.deadline ?? a.startDate ?? DateTime(2100);
      final bd = b.deadline ?? b.startDate ?? DateTime(2100);
      return ad.compareTo(bd);
    });
    return merged;
  }
}
