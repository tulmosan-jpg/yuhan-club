import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/report.dart';
import '../models/activity.dart';
import '../models/attendance.dart';
import '../models/group.dart';
import 'repository.dart';
import 'attendance_logic.dart';

/// Firestore 기반 저장소. flutterfire configure 후 사용.
///
/// 컬렉션 구조:
///   reports/{reportId}
///   activities/{activityId}
///   attendance/{userId}/days/{yyyy-MM-dd}
class FirebaseRepository implements AppRepository {
  FirebaseRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// 로그인된 사용자 uid/이름을 동적으로 읽는다(Auth 연동).
  @override
  String get currentUserId => _auth.currentUser?.uid ?? '';
  @override
  String get currentUserName => _auth.currentUser?.displayName ?? '학생';

  @override
  List<RewardTier> get rewardTiers => AttendanceLogic.defaultTiers;

  // ── 멘토-멘티 보고서 ──
  @override
  Future<List<MentoringReport>> fetchReports() async {
    final snap = await _db
        .collection('reports')
        .where('authorId', isEqualTo: currentUserId)
        .get();
    final list = snap.docs.map(MentoringReport.fromDoc).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<MentoringReport> saveReport(MentoringReport report) async {
    final data = {...report.toMap(), 'authorId': currentUserId};
    if (report.id.isEmpty) {
      final ref = await _db.collection('reports').add(data);
      final doc = await ref.get();
      return MentoringReport.fromDoc(doc);
    }
    await _db.collection('reports').doc(report.id).set(data);
    return report;
  }

  // ── 관리자 / 보고서 관리 ──
  @override
  Future<bool> isAdmin() async {
    final uid = currentUserId;
    if (uid.isEmpty) return false;
    final doc = await _db.collection('admins').doc(uid).get();
    return doc.exists;
  }

  @override
  Future<List<MentoringReport>> fetchAllReports() async {
    final snap = await _db.collection('reports').get();
    return snap.docs.map(MentoringReport.fromDoc).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> deleteReport(String reportId) async {
    await _db.collection('reports').doc(reportId).delete();
  }

  // ── 대외활동/박람회 ──
  @override
  Future<List<Activity>> fetchActivities({ActivityType? type}) async {
    Query<Map<String, dynamic>> q = _db.collection('activities');
    if (type != null) q = q.where('type', isEqualTo: type.name);
    final snap = await q.get();
    final list = snap.docs.map(Activity.fromDoc).toList()
      ..sort(activityOrder);
    return list;
  }

  // ── 연속 출석 ──
  CollectionReference<Map<String, dynamic>> get _daysCol =>
      _db.collection('attendance').doc(currentUserId).collection('days');

  @override
  Future<AttendanceSummary> fetchAttendance() async {
    final results = await Future.wait([_daysCol.get(), fetchAttendanceDates()]);
    final snap = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final schedule = results[1] as List<DateTime>;
    final days = snap.docs
        .map((d) => (d.data()['date'] as Timestamp?)?.toDate())
        .whereType<DateTime>()
        .toList();
    return AttendanceLogic.summarize(days, schedule: schedule);
  }

  @override
  Future<bool> checkInToday() async {
    final today = AttendanceRecord.dayOf(DateTime.now());
    final key =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final ref = _daysCol.doc(key);
    final existing = await ref.get();
    if (existing.exists) return false;
    await ref.set({
      'userId': currentUserId,
      'userName': currentUserName, // 관리자 출석 확인용 이름
      'date': Timestamp.fromDate(today),
    });
    return true;
  }

  // ── 출석 일정 ──
  @override
  Future<List<DateTime>> fetchAttendanceDates() async {
    final snap = await _db.collection('attendance_dates').get();
    return snap.docs
        .map((d) => (d.data()['date'] as Timestamp?)?.toDate())
        .whereType<DateTime>()
        .map(AttendanceRecord.dayOf)
        .toList()
      ..sort();
  }

  @override
  Future<void> addAttendanceDate(DateTime date) async {
    final day = AttendanceRecord.dayOf(date);
    await _db.collection('attendance_dates').doc(AttendanceRecord.keyOf(day)).set({
      'date': Timestamp.fromDate(day),
    });
  }

  @override
  Future<void> removeAttendanceDate(DateTime date) async {
    final day = AttendanceRecord.dayOf(date);
    await _db
        .collection('attendance_dates')
        .doc(AttendanceRecord.keyOf(day))
        .delete();
  }

  // ── 관리자: 전체 회원 출석 현황 ──
  @override
  Future<List<MemberAttendance>> fetchAllAttendance() async {
    // 모든 회원의 days 하위문서를 collectionGroup 으로 한 번에 조회.
    final results =
        await Future.wait([_db.collectionGroup('days').get(), fetchAttendanceDates()]);
    final snap = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final schedule = results[1] as List<DateTime>;
    final byUser = <String, List<DateTime>>{};
    final names = <String, String>{};
    for (final d in snap.docs) {
      final data = d.data();
      final uid = data['userId'] as String? ?? d.reference.parent.parent?.id;
      if (uid == null) continue;
      final date = (data['date'] as Timestamp?)?.toDate();
      if (date != null) (byUser[uid] ??= []).add(date);
      final name = data['userName'] as String?;
      if (name != null && name.isNotEmpty) names[uid] = name;
    }
    final list = byUser.entries.map((e) {
      return MemberAttendance(
        userId: e.key,
        name: names[e.key] ?? '회원',
        summary: AttendanceLogic.summarize(e.value, schedule: schedule),
      );
    }).toList()
      // 연속 출석 많은 순 → 누적 많은 순.
      ..sort((a, b) {
        final s = b.summary.currentStreak.compareTo(a.summary.currentStreak);
        return s != 0 ? s : b.summary.totalDays.compareTo(a.summary.totalDays);
      });
    return list;
  }

  // ── 그룹(팀) ──
  @override
  Future<String> createGroup(String name, String pin) async {
    final ref = await _db.collection('groups').add({
      'name': name.trim(),
      'pin': pin.trim(),
      'memberCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // 회원이 이름만 볼 수 있는 공개 인덱스.
    await _db.collection('group_index').doc(ref.id).set({'name': name.trim()});
    return ref.id;
  }

  @override
  Future<List<Group>> fetchGroups() async {
    final snap = await _db.collection('groups').get();
    return snap.docs.map(Group.fromDoc).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    await _db.collection('groups').doc(groupId).delete();
    await _db.collection('group_index').doc(groupId).delete();
  }

  @override
  Future<List<GroupInfo>> fetchGroupIndex() async {
    final snap = await _db.collection('group_index').get();
    return snap.docs
        .map((d) => GroupInfo(id: d.id, name: (d.data()['name'] as String?) ?? ''))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<List<GroupInfo>> fetchMyGroups() async {
    final uid = currentUserId;
    if (uid.isEmpty) return [];
    // 가입한 그룹 id는 users/{uid}.groups 에 기록해 둔다(인덱스 불필요).
    final userDoc = await _db.collection('users').doc(uid).get();
    final ids = (userDoc.data()?['groups'] as List?)?.cast<String>() ?? const [];
    if (ids.isEmpty) return [];
    final index = await fetchGroupIndex();
    return index.where((g) => ids.contains(g.id)).toList();
  }

  @override
  Future<bool> joinGroup(String groupId, String pin) async {
    final uid = currentUserId;
    if (uid.isEmpty) return false;
    try {
      // 규칙이 PIN 일치를 검증 → 틀리면 permission-denied.
      await _db
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(uid)
          .set({
        'userId': uid,
        'name': currentUserName,
        'pin': pin.trim(),
        'joinedAt': FieldValue.serverTimestamp(),
      });
      // 내 그룹 목록 캐시(본인 users 문서).
      await _db.collection('users').doc(uid).set({
        'groups': FieldValue.arrayUnion([groupId]),
      }, SetOptions(merge: true));
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  @override
  Future<List<MentoringReport>> fetchGroupReports(String groupId) async {
    final snap = await _db
        .collection('reports')
        .where('groupId', isEqualTo: groupId)
        .get();
    return snap.docs.map(MentoringReport.fromDoc).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  // ── 그룹별 출석 ──
  CollectionReference<Map<String, dynamic>> _groupDates(String gid) =>
      _db.collection('groups').doc(gid).collection('attendance_dates');
  CollectionReference<Map<String, dynamic>> _groupCheckins(String gid, String uid) =>
      _db
          .collection('groups')
          .doc(gid)
          .collection('attendance')
          .doc(uid)
          .collection('checkins');

  @override
  Future<List<DateTime>> fetchGroupAttendanceDates(String gid) async {
    final snap = await _groupDates(gid).get();
    return snap.docs
        .map((d) => (d.data()['date'] as Timestamp?)?.toDate())
        .whereType<DateTime>()
        .map(AttendanceRecord.dayOf)
        .toList()
      ..sort();
  }

  @override
  Future<List<ScheduleEntry>> fetchGroupSchedule(String gid) async {
    final snap = await _groupDates(gid).get();
    final list = snap.docs
        .map((d) {
          final date = (d.data()['date'] as Timestamp?)?.toDate();
          if (date == null) return null;
          return ScheduleEntry(
            date: AttendanceRecord.dayOf(date),
            topic: (d.data()['topic'] as String?) ?? '',
          );
        })
        .whereType<ScheduleEntry>()
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  @override
  Future<void> addGroupAttendanceDate(String gid, DateTime date,
      {String topic = ''}) async {
    final day = AttendanceRecord.dayOf(date);
    await _groupDates(gid).doc(AttendanceRecord.keyOf(day)).set({
      'date': Timestamp.fromDate(day),
      'topic': topic.trim(),
    });
  }

  @override
  Future<void> removeGroupAttendanceDate(String gid, DateTime date) async {
    await _groupDates(gid)
        .doc(AttendanceRecord.keyOf(AttendanceRecord.dayOf(date)))
        .delete();
  }

  @override
  Future<bool> checkInGroupToday(String gid) async {
    final uid = currentUserId;
    final today = AttendanceRecord.dayOf(DateTime.now());
    final ref = _groupCheckins(gid, uid).doc(AttendanceRecord.keyOf(today));
    final existing = await ref.get();
    if (existing.exists) return false;
    await ref.set({
      'userId': uid,
      'userName': currentUserName,
      'date': Timestamp.fromDate(today),
    });
    return true;
  }

  @override
  Future<AttendanceSummary> fetchMyGroupAttendance(String gid) async {
    final results = await Future.wait(
        [_groupCheckins(gid, currentUserId).get(), fetchGroupAttendanceDates(gid)]);
    final snap = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final schedule = results[1] as List<DateTime>;
    final days = snap.docs
        .map((d) => (d.data()['date'] as Timestamp?)?.toDate())
        .whereType<DateTime>()
        .toList();
    return AttendanceLogic.summarize(days, schedule: schedule);
  }

  // ── 참석 응답(RSVP) ──
  CollectionReference<Map<String, dynamic>> _rsvpCol(String gid, String uid) =>
      _db
          .collection('groups')
          .doc(gid)
          .collection('attendance')
          .doc(uid)
          .collection('rsvp');

  @override
  Future<void> setRsvp(
      String gid, DateTime day, bool available, String reason) async {
    final d = AttendanceRecord.dayOf(day);
    await _rsvpCol(gid, currentUserId).doc(AttendanceRecord.keyOf(d)).set({
      'userId': currentUserId,
      'userName': currentUserName,
      'available': available,
      'reason': reason.trim(),
      'date': Timestamp.fromDate(d),
    });
  }

  @override
  Future<Map<String, Rsvp>> fetchMyRsvp(String gid) async {
    final snap = await _rsvpCol(gid, currentUserId).get();
    final out = <String, Rsvp>{};
    for (final doc in snap.docs) {
      final m = doc.data();
      final date = (m['date'] as Timestamp?)?.toDate();
      if (date == null) continue;
      out[doc.id] = Rsvp(
        userId: (m['userId'] as String?) ?? '',
        userName: (m['userName'] as String?) ?? '',
        day: AttendanceRecord.dayOf(date),
        available: (m['available'] as bool?) ?? true,
        reason: (m['reason'] as String?) ?? '',
      );
    }
    return out;
  }

  @override
  Future<List<Rsvp>> fetchGroupRsvp(String gid) async {
    final members =
        await _db.collection('groups').doc(gid).collection('members').get();
    // 멤버별 RSVP 조회를 병렬로(N번 순차 왕복 방지).
    final snaps = await Future.wait(
        members.docs.map((m) => _rsvpCol(gid, m.id).get()));
    final out = <Rsvp>[];
    for (var i = 0; i < members.docs.length; i++) {
      final memberId = members.docs[i].id;
      for (final doc in snaps[i].docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp?)?.toDate();
        if (date == null) continue;
        out.add(Rsvp(
          userId: (data['userId'] as String?) ?? memberId,
          userName: (data['userName'] as String?) ?? '회원',
          day: AttendanceRecord.dayOf(date),
          available: (data['available'] as bool?) ?? true,
          reason: (data['reason'] as String?) ?? '',
        ));
      }
    }
    return out;
  }

  @override
  Future<List<MemberAttendance>> fetchGroupMemberAttendance(String gid) async {
    final membersFut =
        _db.collection('groups').doc(gid).collection('members').get();
    final scheduleFut = fetchGroupAttendanceDates(gid);
    final members = await membersFut;
    final schedule = await scheduleFut;
    // 멤버별 체크인 조회를 병렬로(N번 순차 왕복 방지).
    final checkins = await Future.wait(
        members.docs.map((m) => _groupCheckins(gid, m.id).get()));
    final result = <MemberAttendance>[];
    for (var i = 0; i < members.docs.length; i++) {
      final m = members.docs[i];
      final days = checkins[i]
          .docs
          .map((d) => (d.data()['date'] as Timestamp?)?.toDate())
          .whereType<DateTime>()
          .toList();
      result.add(MemberAttendance(
          userId: m.id,
          name: (m.data()['name'] as String?) ?? '회원',
          summary: AttendanceLogic.summarize(days, schedule: schedule)));
    }
    result.sort((a, b) {
      final s = b.summary.currentStreak.compareTo(a.summary.currentStreak);
      return s != 0 ? s : b.summary.totalDays.compareTo(a.summary.totalDays);
    });
    return result;
  }
}
