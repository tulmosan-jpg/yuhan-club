import 'package:cloud_firestore/cloud_firestore.dart';

/// 대외활동/박람회 종류
enum ActivityType {
  fair('박람회/전시'),
  contest('공모전'),
  intern('인턴/채용'),
  program('대외활동'),
  seminar('세미나/특강');

  const ActivityType(this.label);
  final String label;

  static ActivityType fromName(String? name) =>
      ActivityType.values.firstWhere(
        (t) => t.name == name,
        orElse: () => ActivityType.program,
      );
}

/// 대외활동/박람회 정보 (운영진이 등록, 앱에서 조회)
class Activity {
  final String id;
  final ActivityType type;
  final String title;
  final String organizer; // 주최/주관
  final String description;
  final String? location;
  final DateTime? startDate; // 행사 시작
  final DateTime? deadline; // 신청 마감
  final String? url; // 신청/상세 링크
  final String? imageUrl;

  const Activity({
    required this.id,
    required this.type,
    required this.title,
    required this.organizer,
    required this.description,
    this.location,
    this.startDate,
    this.deadline,
    this.url,
    this.imageUrl,
  });

  /// 마감 임박 여부(7일 이내)
  bool get closingSoon {
    if (deadline == null) return false;
    final diff = deadline!.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 7;
  }

  bool get closed =>
      deadline != null && deadline!.isBefore(DateTime.now());

  factory Activity.fromMap(String id, Map<String, dynamic> map) {
    return Activity(
      id: id,
      type: ActivityType.fromName(map['type'] as String?),
      title: map['title'] as String? ?? '',
      organizer: map['organizer'] as String? ?? '',
      description: map['description'] as String? ?? '',
      location: map['location'] as String?,
      startDate: (map['startDate'] as Timestamp?)?.toDate(),
      deadline: (map['deadline'] as Timestamp?)?.toDate(),
      url: map['url'] as String?,
      imageUrl: map['imageUrl'] as String?,
    );
  }

  factory Activity.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Activity.fromMap(doc.id, doc.data() ?? {});

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'title': title,
        'organizer': organizer,
        'description': description,
        'location': location,
        'startDate':
            startDate == null ? null : Timestamp.fromDate(startDate!),
        'deadline': deadline == null ? null : Timestamp.fromDate(deadline!),
        'url': url,
        'imageUrl': imageUrl,
      };
}
