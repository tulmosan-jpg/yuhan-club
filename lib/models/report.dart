import 'package:cloud_firestore/cloud_firestore.dart';

/// 보고서 작성 주체
enum ReportRole {
  mentor('멘토'),
  mentee('멘티');

  const ReportRole(this.label);
  final String label;

  static ReportRole fromName(String? name) => ReportRole.values.firstWhere(
        (r) => r.name == name,
        orElse: () => ReportRole.mentor,
      );
}

/// 제출 상태
enum ReportStatus {
  draft('임시저장'),
  submitted('제출완료');

  const ReportStatus(this.label);
  final String label;

  static ReportStatus fromName(String? name) =>
      ReportStatus.values.firstWhere(
        (s) => s.name == name,
        orElse: () => ReportStatus.draft,
      );
}

/// 멘토-멘티 활동 보고서
class MentoringReport {
  final String id;
  final ReportRole role; // 작성자 역할
  final String authorName; // 작성자
  final String partnerName; // 상대(멘토↔멘티)
  final DateTime activityDate; // 활동 일자
  final int activityHours; // 활동 시간
  final String title;
  final String content; // 활동 내용
  final String? feedback; // 소감/피드백
  final ReportStatus status;
  final DateTime updatedAt;

  const MentoringReport({
    required this.id,
    required this.role,
    required this.authorName,
    required this.partnerName,
    required this.activityDate,
    required this.activityHours,
    required this.title,
    required this.content,
    this.feedback,
    this.status = ReportStatus.draft,
    required this.updatedAt,
  });

  MentoringReport copyWith({
    ReportStatus? status,
    DateTime? updatedAt,
  }) {
    return MentoringReport(
      id: id,
      role: role,
      authorName: authorName,
      partnerName: partnerName,
      activityDate: activityDate,
      activityHours: activityHours,
      title: title,
      content: content,
      feedback: feedback,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MentoringReport.fromMap(String id, Map<String, dynamic> map) {
    return MentoringReport(
      id: id,
      role: ReportRole.fromName(map['role'] as String?),
      authorName: map['authorName'] as String? ?? '',
      partnerName: map['partnerName'] as String? ?? '',
      activityDate:
          (map['activityDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      activityHours: (map['activityHours'] as num?)?.toInt() ?? 0,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      feedback: map['feedback'] as String?,
      status: ReportStatus.fromName(map['status'] as String?),
      updatedAt:
          (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory MentoringReport.fromDoc(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      MentoringReport.fromMap(doc.id, doc.data() ?? {});

  Map<String, dynamic> toMap() => {
        'role': role.name,
        'authorName': authorName,
        'partnerName': partnerName,
        'activityDate': Timestamp.fromDate(activityDate),
        'activityHours': activityHours,
        'title': title,
        'content': content,
        'feedback': feedback,
        'status': status.name,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}
