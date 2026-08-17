// 리워드로 교환 가능한 더벤티 음료 카탈로그 + 발급 쿠폰 모델.
//
// - 쿠폰은 기프티콘이 아니며, 더벤티 역곡북부역점에서만 사용 가능하다.
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

/// 더벤티 브랜드 색(보라).
const int kTheventiPurpleValue = 0xFF7A1FA2;

/// 더벤티 로고 에셋.
const String kTheventiLogo = 'assets/images/theventi/logo.png';

/// 더벤티 역곡북부역점 선결제 음료(총 10만원어치).
const List<Drink> kDrinks = [
  Drink(
    id: 'peach',
    name: '제로 복숭아 아이스티',
    size: '라지 (600ml)',
    desc: '홍차 베이스에 싱그러운 복숭아 과즙을 더한 당류 부담 없는 제로 아이스티.',
    nutrition: '20kcal · 당류 0g · 단백질 0g · 나트륨 57mg · 카페인 0mg · 복숭아 함유',
    caution: '알룰로스(대체당) 함유 — 과량 섭취 시 복통·설사 유발 가능, 민감자 주의.',
    image: 'assets/images/theventi/peach.png',
  ),
  Drink(
    id: 'plum',
    name: '제로 매실 아이스티',
    size: '라지 (600ml)',
    desc: '매실 특유의 새콤달콤함을 깔끔하고 가볍게 풀어낸 당류 부담 없는 제로 아이스티.',
    nutrition: '20kcal · 당류 0g · 단백질 0g · 나트륨 60mg · 카페인 0mg',
    caution: '알룰로스(대체당) 함유 — 과량 섭취 시 복통·설사 유발 가능, 민감자 주의.',
    image: 'assets/images/theventi/plum.png',
  ),
  Drink(
    id: 'americano',
    name: '아이스 아메리카노',
    size: '라지 (600ml)',
    desc: '더벤티의 깊고 진한 커피 풍미를 느낄 수 있는 아이스 아메리카노.',
    nutrition: '14kcal · 당류 0g · 단백질 1g · 카페인 시그니처 168mg / 다크 266mg (고카페인)',
    caution: '고카페인 음료 — 어린이·임산부·카페인 민감자는 섭취에 주의.',
    image: 'assets/images/theventi/americano.png',
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

  static const defaultStock = {'peach': 6, 'plum': 6, 'americano': 14};
}
