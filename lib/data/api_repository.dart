import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/activity.dart';

/// activity-api(FastAPI) `/activities` 를 읽어오는 저장소 조각.
///
/// 대외활동/박람회 목록만 담당한다. 보고서/출석 등 나머지 기능은
/// [CompositeRepository] 가 기존 저장소(Mock/Firebase)로 위임한다.
class ActivityApiClient {
  ActivityApiClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// 예: http://10.0.2.2:8000 (안드로이드 에뮬레이터에서 로컬 서버),
  ///     실제 배포 시엔 공개된 API 도메인.
  final String baseUrl;
  final http.Client _client;

  /// 우리 API의 category(한글) -> 앱 ActivityType
  static ActivityType _mapType(String? category) {
    switch (category) {
      case '공모전':
        return ActivityType.contest;
      case '박람회':
        return ActivityType.fair;
      case '인턴':
        return ActivityType.intern;
      case '세미나':
        return ActivityType.seminar;
      case '대외활동':
      default:
        return ActivityType.program;
    }
  }

  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);

  Activity _fromJson(Map<String, dynamic> m) {
    final desc = (m['detail'] as String?)?.trim();
    return Activity(
      id: m['uid'] as String,
      type: _mapType(m['category'] as String?),
      title: m['title'] as String? ?? '',
      organizer: m['organization'] as String? ?? '',
      description: (desc != null && desc.isNotEmpty)
          ? desc
          : (m['fields'] as String? ?? ''),
      location: m['region'] as String?,
      startDate: _dt(m['activity_start_at']),
      deadline: _dt(m['recruit_close_at']),
      url: m['url'] as String?,
      imageUrl: m['thumbnail'] as String?,
    );
  }

  Future<List<Activity>> fetchActivities({ActivityType? type}) async {
    final params = <String, String>{'limit': '100', 'open_only': 'true'};
    // 앱의 enum -> API category 역매핑
    const toCategory = {
      ActivityType.contest: '공모전',
      ActivityType.fair: '박람회',
      ActivityType.intern: '인턴',
      ActivityType.seminar: '세미나',
      ActivityType.program: '대외활동',
    };
    if (type != null) params['category'] = toCategory[type]!;

    final uri =
        Uri.parse('$baseUrl/activities').replace(queryParameters: params);
    final res = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('activity-api ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
    return data
        .map((e) => _fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
