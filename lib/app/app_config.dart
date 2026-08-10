import '../data/repository.dart';
import '../data/mock_repository.dart';
import '../data/api_repository.dart';
import '../data/composite_repository.dart';
import '../data/firebase_repository.dart';

/// 앱 전역 설정.
class AppConfig {
  static const String appTitle = '유한대 식품영양학과';

  /// true 면 인메모리 Mock 데이터 사용(오프라인 실행 가능).
  /// Firebase 연결 완료 → 기본 false. (Firestore + 자동수집분 사용)
  /// 웹 디자인 확인/오프라인 테스트 시:
  ///   flutter run -d chrome --dart-define=USE_MOCK=true
  static const bool useMock =
      bool.fromEnvironment('USE_MOCK', defaultValue: false);

  /// activity-api(FastAPI) 직접 호출 주소.
  ///
  /// 무료 구성에서는 API 서버를 호스팅하지 않고, 스크래퍼가 firebase_sync로
  /// Firestore `activities`에 자동수집분을 채운다. 따라서 기본값은 빈 값이며,
  /// 앱은 Firestore(운영진 등록 + 자동수집)만 읽는다.
  ///
  /// 로컬 개발 중 API를 직접 붙여보려면:
  ///   flutter run --dart-define=ACTIVITY_API_URL=http://localhost:8000
  static const String activityApiUrl =
      String.fromEnvironment('ACTIVITY_API_URL', defaultValue: '');

  /// 저장소를 만든다. 실제 모드의 사용자(uid/이름)는 [FirebaseRepository]가
  /// Firebase Auth 현재 사용자에서 직접 읽는다.
  static AppRepository createRepository() {
    // 운영진 등록분 + 자동수집분(firebase_sync)을 담는 기본 저장소.
    final AppRepository base = useMock ? MockRepository() : FirebaseRepository();

    // 자동수집 대외활동을 API에서 합쳐온다.
    if (activityApiUrl.isEmpty) return base;
    return CompositeRepository(
      base: base,
      api: ActivityApiClient(baseUrl: activityApiUrl),
    );
  }
}
