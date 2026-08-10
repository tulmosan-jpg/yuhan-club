import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/report.dart';
import '../models/activity.dart';
import '../models/attendance.dart';
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

  // ── 대외활동/박람회 ──
  @override
  Future<List<Activity>> fetchActivities({ActivityType? type}) async {
    Query<Map<String, dynamic>> q = _db.collection('activities');
    if (type != null) q = q.where('type', isEqualTo: type.name);
    final snap = await q.get();
    final list = snap.docs.map(Activity.fromDoc).toList()
      ..sort((a, b) {
        final ad = a.deadline ?? a.startDate ?? DateTime(2100);
        final bd = b.deadline ?? b.startDate ?? DateTime(2100);
        return ad.compareTo(bd);
      });
    return list;
  }

  // ── 연속 출석 ──
  CollectionReference<Map<String, dynamic>> get _daysCol =>
      _db.collection('attendance').doc(currentUserId).collection('days');

  @override
  Future<AttendanceSummary> fetchAttendance() async {
    final snap = await _daysCol.get();
    final days = snap.docs
        .map((d) => (d.data()['date'] as Timestamp?)?.toDate())
        .whereType<DateTime>()
        .toList();
    return AttendanceLogic.summarize(days);
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
      'date': Timestamp.fromDate(today),
    });
    return true;
  }
}
