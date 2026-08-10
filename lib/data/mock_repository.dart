import '../models/report.dart';
import '../models/activity.dart';
import '../models/attendance.dart';
import 'repository.dart';
import 'attendance_logic.dart';

/// Firebase 연결 전 개발/테스트용 인메모리 저장소.
class MockRepository implements AppRepository {
  @override
  String get currentUserId => 'me';
  @override
  String get currentUserName => '홍길동';

  @override
  List<RewardTier> get rewardTiers => AttendanceLogic.defaultTiers;

  final List<MentoringReport> _reports = [
    MentoringReport(
      id: 'r1',
      role: ReportRole.mentor,
      authorName: '홍길동',
      partnerName: '김새내',
      activityDate: DateTime.now().subtract(const Duration(days: 2)),
      activityHours: 2,
      title: '1학년 전공기초 멘토링 - 영양학개론',
      content: '영양소 대사 파트 질의응답을 진행하고 중간고사 대비 요약 노트를 함께 정리했습니다.',
      feedback: '멘티가 개념 연결을 어려워해 예시 위주로 설명하니 이해도가 높아졌습니다.',
      status: ReportStatus.submitted,
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    MentoringReport(
      id: 'r2',
      role: ReportRole.mentee,
      authorName: '홍길동',
      partnerName: '이선배',
      activityDate: DateTime.now().subtract(const Duration(days: 6)),
      activityHours: 1,
      title: '식품위생학 실습 준비 멘토링',
      content: '실습 보고서 양식과 미생물 배양 실험 절차를 배웠습니다.',
      status: ReportStatus.draft,
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  final List<Activity> _activities = [
    Activity(
      id: 'a1',
      type: ActivityType.fair,
      title: '2026 서울국제식품산업대전 (SEOUL FOOD)',
      organizer: 'KOTRA / aT',
      description:
          '국내 최대 규모의 식품 박람회. 식품·외식·급식 산업 최신 트렌드와 채용 부스를 만나볼 수 있습니다. '
          '식품영양학과 재학생 단체 관람 신청 예정.',
      location: '킨텍스(KINTEX) 제1전시장',
      startDate: DateTime.now().add(const Duration(days: 20)),
      deadline: DateTime.now().add(const Duration(days: 12)),
      url: 'https://www.seoulfood.or.kr',
    ),
    Activity(
      id: 'a2',
      type: ActivityType.contest,
      title: '대학생 건강식단 레시피 공모전',
      organizer: '한국영양학회',
      description: '균형 잡힌 한 끼 식단을 주제로 한 레시피 공모전. 수상 시 상금 및 학회 인증서 수여.',
      deadline: DateTime.now().add(const Duration(days: 5)),
      url: 'https://www.kns.or.kr',
    ),
    Activity(
      id: 'a3',
      type: ActivityType.intern,
      title: '급식업체 임상영양 인턴십 모집',
      organizer: '○○푸드서비스',
      description: '단체급식 현장에서 영양사 직무를 체험하는 동계 인턴십. 4주 과정, 실습 인정 가능.',
      location: '수도권 사업장',
      deadline: DateTime.now().add(const Duration(days: 15)),
    ),
    Activity(
      id: 'a4',
      type: ActivityType.seminar,
      title: '임상영양사 진로 특강',
      organizer: '식품영양학과 학생회',
      description: '병원 임상영양사 선배 초청 특강. 진로 Q&A 세션 포함.',
      startDate: DateTime.now().add(const Duration(days: 3)),
      location: '보건관 401호',
    ),
  ];

  // 데모용 출석 이력: 최근 4일 연속 출석(오늘 제외).
  final List<DateTime> _attendanceDays = [
    for (int i = 1; i <= 4; i++)
      AttendanceRecord.dayOf(
          DateTime.now().subtract(Duration(days: i))),
  ];

  @override
  Future<List<MentoringReport>> fetchReports() async {
    await _delay();
    final list = [..._reports]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<MentoringReport> saveReport(MentoringReport report) async {
    await _delay();
    final idx = _reports.indexWhere((r) => r.id == report.id);
    final saved = report.id.isEmpty
        ? report.copyWith() // 새 보고서
        : report;
    if (report.id.isEmpty) {
      final withId = MentoringReport(
        id: 'r${DateTime.now().millisecondsSinceEpoch}',
        role: report.role,
        authorName: report.authorName,
        partnerName: report.partnerName,
        activityDate: report.activityDate,
        activityHours: report.activityHours,
        title: report.title,
        content: report.content,
        feedback: report.feedback,
        status: report.status,
        updatedAt: report.updatedAt,
      );
      _reports.add(withId);
      return withId;
    } else if (idx >= 0) {
      _reports[idx] = saved;
    } else {
      _reports.add(saved);
    }
    return saved;
  }

  @override
  Future<List<Activity>> fetchActivities({ActivityType? type}) async {
    await _delay();
    var list = [..._activities];
    if (type != null) list = list.where((a) => a.type == type).toList();
    list.sort((a, b) {
      final ad = a.deadline ?? a.startDate ?? DateTime(2100);
      final bd = b.deadline ?? b.startDate ?? DateTime(2100);
      return ad.compareTo(bd);
    });
    return list;
  }

  @override
  Future<AttendanceSummary> fetchAttendance() async {
    await _delay();
    return AttendanceLogic.summarize(_attendanceDays);
  }

  @override
  Future<bool> checkInToday() async {
    await _delay();
    final today = AttendanceRecord.dayOf(DateTime.now());
    if (_attendanceDays.contains(today)) return false;
    _attendanceDays.add(today);
    return true;
  }

  Future<void> _delay() =>
      Future<void>.delayed(const Duration(milliseconds: 250));
}
