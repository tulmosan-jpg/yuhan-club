// 리워드로 교환 가능한 빽다방 음료 카탈로그 + 발급 쿠폰 모델.
//
// - 쿠폰은 기프티콘이 아니며, 빽다방 부천역곡역북부점에서만 사용 가능하다.
// - 매장에서 쿠폰 제시 → 직원이 사용완료 코드(4자리)를 입력하면 사용 완료 처리.

/// 리워드 음료 1종의 고정 정보(영양성분 요약 포함).
class Drink {
  final String id;
  final String name;
  final String size; // 제공량
  final String desc; // 한 줄 소개
  final String nutrition; // 영양성분 요약
  final String? caution; // 주의 문구(선택)
  final String image; // 에셋 경로

  const Drink({
    required this.id,
    required this.name,
    required this.size,
    required this.desc,
    required this.nutrition,
    this.caution,
    required this.image,
  });
}

/// 빽다방 브랜드 색(네이비).
const int kPaikNavyValue = 0xFF102A6B;

/// 빽다방 로고 에셋.
const String kPaikLogo = 'assets/images/paikdabang/logo.png';

/// 빽다방 부천역곡역북부점 선결제 음료.
const List<Drink> kDrinks = [
  Drink(
    id: 'peachtea',
    name: '제로슈거 납작복숭아 아이스티',
    size: '아이스',
    desc: '납작복숭아의 달콤한 향을 담은 제로슈거 아이스티. 당류 부담 없이 즐기는 시원한 한 잔.',
    nutrition: '제로슈거 · 당류 0g · 카페인 0mg · 복숭아 향 함유',
    caution: '대체당(감미료) 함유 — 과량 섭취 시 복통·설사 유발 가능, 민감자 주의.',
    image: 'assets/images/paikdabang/peachtea.png',
  ),
  Drink(
    id: 'americano',
    name: '아이스 아메리카노',
    size: '아이스',
    desc: '빽다방의 진한 커피 풍미를 시원하게 즐기는 아이스 아메리카노.',
    nutrition: '당류 0g · 카페인 함유(고카페인)',
    caution: '고카페인 음료 — 어린이·임산부·카페인 민감자는 섭취에 주의.',
    image: 'assets/images/paikdabang/americano.png',
  ),
];

Drink? drinkById(String id) {
  for (final d in kDrinks) {
    if (d.id == id) return d;
  }
  return null;
}

/// 발급된 리워드 쿠폰.
class Coupon {
  final String id;
  final String userId;
  final String userName;
  final String drinkId;
  final String drinkName;
  final DateTime issuedAt;
  final bool used;
  final DateTime? usedAt;

  const Coupon({
    required this.id,
    required this.userId,
    required this.userName,
    required this.drinkId,
    required this.drinkName,
    required this.issuedAt,
    this.used = false,
    this.usedAt,
  });
}

/// 리워드 설정/재고 현황(설정 문서 + 종목별 남은 수량).
class RewardConfig {
  final String code; // 직원용 사용완료 코드(4자리). 비어 있으면 미설정.
  final Map<String, int> stock; // drinkId → 남은 수량

  const RewardConfig({required this.code, required this.stock});

  int remaining(String drinkId) => stock[drinkId] ?? 0;
  int get totalRemaining =>
      stock.values.fold(0, (a, b) => a + (b < 0 ? 0 : b));

  static const defaultStock = {'peachtea': 20, 'americano': 22};
}
