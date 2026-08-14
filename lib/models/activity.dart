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

  /// 식품·영양 관련 활동 여부. 제목/주최에 식품영양 도메인 키워드가 포함되면
  /// true. (식품영양학과 전용 "식품·영양" 섹션 필터에 사용)
  /// 설명 본문까지 넣으면 오탐이 많아 제목+주최만으로 판별한다.
  static const List<String> _foodKeywords = [
    '식품', '영양', '요리', '조리', '급식', '외식', '식단', '레시피', '푸드',
    'food', 'nutrition', '위생', '제과', '제빵', '베이커리', '바리스타',
    '농식품', '축산', '수산', '발효', '한식', '양식', '셰프', '조리사',
    '영양사', '건강기능', 'haccp', '식자재', '먹거리', '미식', '식생활',
    '푸드테크', '식료', '간식', '음식', '농정원', '농림',
  ];

  bool get foodRelated {
    final hay = '$title $organizer'.toLowerCase();
    return _foodKeywords.any((k) => hay.contains(k));
  }

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
