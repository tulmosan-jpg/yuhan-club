import '../models/report.dart';
import '../models/activity.dart';
import '../models/attendance.dart';
import '../models/group.dart';
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
        photos: report.photos,
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

  // 목 모드에서는 관리자 기능 시연을 위해 관리자로 취급.
  @override
  Future<bool> isAdmin() async {
    await _delay();
    return true;
  }

  @override
  Future<List<MentoringReport>> fetchAllReports() async {
    await _delay();
    return [..._reports]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> deleteReport(String reportId) async {
    await _delay();
    _reports.removeWhere((r) => r.id == reportId);
  }

  @override
  Future<List<MemberAttendance>> fetchAllAttendance() async {
    await _delay();
    final schedule = _attendanceDates;
    return [
      MemberAttendance(
          userId: 'me',
          name: '홍길동',
          summary:
              AttendanceLogic.summarize(_attendanceDays, schedule: schedule)),
      MemberAttendance(
          userId: 'u2',
          name: '김회원',
          summary: AttendanceLogic.summarize([
            for (int i = 0; i < 3; i++)
              AttendanceRecord.dayOf(DateTime.now().subtract(Duration(days: i)))
          ], schedule: schedule)),
      MemberAttendance(
          userId: 'u3',
          name: '이학생',
          summary: AttendanceLogic.summarize([
            AttendanceRecord.dayOf(
                DateTime.now().subtract(const Duration(days: 5)))
          ], schedule: schedule)),
    ];
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
    return AttendanceLogic.summarize(_attendanceDays,
        schedule: _attendanceDates);
  }

  @override
  Future<bool> checkInToday() async {
    await _delay();
    final today = AttendanceRecord.dayOf(DateTime.now());
    if (_attendanceDays.contains(today)) return false;
    _attendanceDays.add(today);
    return true;
  }

  // 데모: 오늘 + 어제 + 내일을 출석 가능일로.
  final List<DateTime> _attendanceDates = [
    AttendanceRecord.dayOf(DateTime.now().subtract(const Duration(days: 1))),
    AttendanceRecord.dayOf(DateTime.now()),
    AttendanceRecord.dayOf(DateTime.now().add(const Duration(days: 1))),
  ];

  @override
  Future<List<DateTime>> fetchAttendanceDates() async {
    await _delay();
    return [..._attendanceDates]..sort();
  }

  @override
  Future<void> addAttendanceDate(DateTime date) async {
    await _delay();
    final d = AttendanceRecord.dayOf(date);
    if (!_attendanceDates.contains(d)) _attendanceDates.add(d);
  }

  @override
  Future<void> removeAttendanceDate(DateTime date) async {
    await _delay();
    _attendanceDates.remove(AttendanceRecord.dayOf(date));
  }

  // ── 그룹(데모) ──
  final List<Group> _groups = [
    const Group(id: 'g1', name: '홍길동 멘토팀', pin: '1234', memberCount: 3),
    const Group(id: 'g2', name: '김영양 멘토팀', pin: '5678', memberCount: 2),
  ];
  final Set<String> _myGroupIds = {'g1'};

  @override
  Future<String> createGroup(String name, String pin) async {
    await _delay();
    final id = 'g${DateTime.now().millisecondsSinceEpoch}';
    _groups.add(Group(id: id, name: name, pin: pin));
    return id;
  }

  @override
  Future<List<Group>> fetchGroups() async {
    await _delay();
    return [..._groups];
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    await _delay();
    _groups.removeWhere((g) => g.id == groupId);
  }

  @override
  Future<List<GroupInfo>> fetchGroupIndex() async {
    await _delay();
    return _groups.map((g) => GroupInfo(id: g.id, name: g.name)).toList();
  }

  @override
  Future<List<GroupInfo>> fetchMyGroups() async {
    await _delay();
    return _groups
        .where((g) => _myGroupIds.contains(g.id))
        .map((g) => GroupInfo(id: g.id, name: g.name))
        .toList();
  }

  @override
  Future<bool> joinGroup(String groupId, String pin) async {
    await _delay();
    final g = _groups.where((g) => g.id == groupId);
    if (g.isEmpty || g.first.pin != pin.trim()) return false;
    _myGroupIds.add(groupId);
    return true;
  }

  @override
  Future<List<MentoringReport>> fetchGroupReports(String groupId) async {
    await _delay();
    return [..._reports]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  // 그룹별 출석(데모): 그룹→날짜, 그룹→내 체크인.
  final Map<String, List<DateTime>> _groupDates = {
    'g1': [
      AttendanceRecord.dayOf(DateTime.now()),
      AttendanceRecord.dayOf(DateTime.now().add(const Duration(days: 7))),
    ],
  };
  final Map<String, List<DateTime>> _groupMine = {'g1': []};
  // 일정 주제: 'gid|yyyy-MM-dd' → topic (데모 시드)
  final Map<String, String> _groupTopics = {
    'g1|${AttendanceRecord.keyOf(AttendanceRecord.dayOf(DateTime.now()))}':
        '오리엔테이션 · 조 편성',
    'g1|${AttendanceRecord.keyOf(AttendanceRecord.dayOf(DateTime.now().add(const Duration(days: 7))))}':
        '식품위생 특강',
  };

  String _topicKey(String gid, DateTime d) =>
      '$gid|${AttendanceRecord.keyOf(AttendanceRecord.dayOf(d))}';

  @override
  Future<List<DateTime>> fetchGroupAttendanceDates(String gid) async {
    await _delay();
    return [...?_groupDates[gid]]..sort();
  }

  @override
  Future<List<ScheduleEntry>> fetchGroupSchedule(String gid) async {
    await _delay();
    final dates = [...?_groupDates[gid]]..sort();
    return dates
        .map((d) => ScheduleEntry(
            date: d, topic: _groupTopics[_topicKey(gid, d)] ?? ''))
        .toList();
  }

  @override
  Future<void> addGroupAttendanceDate(String gid, DateTime date,
      {String topic = ''}) async {
    await _delay();
    final day = AttendanceRecord.dayOf(date);
    final list = _groupDates[gid] ??= [];
    if (!list.contains(day)) list.add(day);
    _groupTopics[_topicKey(gid, day)] = topic.trim();
  }

  @override
  Future<void> removeGroupAttendanceDate(String gid, DateTime date) async {
    await _delay();
    final day = AttendanceRecord.dayOf(date);
    _groupDates[gid]?.remove(day);
    _groupTopics.remove(_topicKey(gid, day));
  }

  @override
  Future<bool> checkInGroupToday(String gid) async {
    await _delay();
    final today = AttendanceRecord.dayOf(DateTime.now());
    final mine = _groupMine[gid] ??= [];
    if (mine.contains(today)) return false;
    mine.add(today);
    return true;
  }

  @override
  Future<AttendanceSummary> fetchMyGroupAttendance(String gid) async {
    await _delay();
    return AttendanceLogic.summarize(_groupMine[gid] ?? [],
        schedule: _groupDates[gid]);
  }

  @override
  Future<List<MemberAttendance>> fetchGroupMemberAttendance(String gid) async {
    await _delay();
    final schedule = _groupDates[gid];
    return [
      MemberAttendance(
          userId: 'me',
          name: '홍길동',
          summary: AttendanceLogic.summarize(_groupMine[gid] ?? [],
              schedule: schedule)),
      MemberAttendance(
          userId: 'u2',
          name: '김멘티',
          summary: AttendanceLogic.summarize(
              [AttendanceRecord.dayOf(DateTime.now())],
              schedule: schedule)),
    ];
  }

  final Map<String, Map<String, Rsvp>> _rsvp = {}; // gid → (dayKey → Rsvp)

  @override
  Future<void> setRsvp(
      String gid, DateTime day, bool available, String reason) async {
    await _delay();
    final d = AttendanceRecord.dayOf(day);
    (_rsvp[gid] ??= {})[AttendanceRecord.keyOf(d)] = Rsvp(
        userId: 'me',
        userName: '홍길동',
        day: d,
        available: available,
        reason: reason.trim());
  }

  @override
  Future<Map<String, Rsvp>> fetchMyRsvp(String gid) async {
    await _delay();
    return {...?_rsvp[gid]};
  }

  @override
  Future<List<Rsvp>> fetchGroupRsvp(String gid) async {
    await _delay();
    return (_rsvp[gid]?.values.toList()) ?? [];
  }

  Future<void> _delay() =>
      Future<void>.delayed(const Duration(milliseconds: 250));
}
