import 'package:flutter/material.dart';

/// 자격증/면허 분류.
enum CertKind {
  license, // 면허 (국시원 / 보건복지부)
  engineer, // 기사·산업기사 (국가기술자격)
  craftsman, // 기능사 (국가기술자격)
  private, // 민간자격 (학회/협회 등)
  international, // 국제자격 (해외 학회/협회)
}

extension CertKindX on CertKind {
  String get labelKo => switch (this) {
        CertKind.license => '면허',
        CertKind.engineer => '기사·산업기사',
        CertKind.craftsman => '기능사',
        CertKind.private => '민간자격',
        CertKind.international => '국제자격',
      };

  String get labelEn => switch (this) {
        CertKind.license => 'License',
        CertKind.engineer => 'Engineer',
        CertKind.craftsman => 'Craftsman',
        CertKind.private => 'Private',
        CertKind.international => 'International',
      };
}

/// 식품·영양 관련 자격증/면허 정보 항목.
///
/// 데이터는 큐넷(q-net.or.kr)·국시원(kuksiwon.or.kr) 공개 정보를 정리한 것으로,
/// 시험 일정·응시료 등은 매년 바뀌므로 상세는 공식 사이트에서 확인하도록 링크를 둔다.
class Certification {
  final String id;
  final String name; // 예: 영양사
  final CertKind kind;
  final String issuer; // 발급/시행 기관
  final String tagline; // 한 줄 소개
  final String eligibility; // 응시자격
  final List<String> subjects; // 시험과목(필기 등)
  final String method; // 시험방법/문항
  final String passCriteria; // 합격 기준
  final String schedule; // 시행 시기(대략)
  final String? fee; // 응시료(있으면)
  final String url; // 공식 안내 링크
  final IconData icon;

  const Certification({
    required this.id,
    required this.name,
    required this.kind,
    required this.issuer,
    required this.tagline,
    required this.eligibility,
    required this.subjects,
    required this.method,
    required this.passCriteria,
    required this.schedule,
    this.fee,
    required this.url,
    required this.icon,
  });
}

/// 식품영양학과 학생에게 유용한 자격증/면허 목록.
/// (출처: 국시원 kuksiwon.or.kr, 큐넷 q-net.or.kr — 2026년 기준 정리)
const List<Certification> kCertifications = [
  // ── 면허 (국시원 / 보건복지부) ──
  Certification(
    id: 'dietitian',
    name: '영양사',
    kind: CertKind.license,
    issuer: '한국보건의료인국가시험원 · 보건복지부',
    tagline: '급식·임상·보건 영양 관리 전문 면허',
    eligibility:
        '식품영양학과 등 관련 학과 졸업(또는 응시일로부터 3개월 내 졸업예정)이면서 '
        '보건복지부령 별표1의 교과목·학점 및 현장실습을 이수한 자.',
    subjects: [
      '영양학 및 생화학',
      '영양교육, 식사요법 및 생리학',
      '식품학 및 조리원리',
      '급식, 위생 및 관계법규',
    ],
    method: '필기(PBT) 4과목 총 220문항, 5지선다 객관식.',
    passCriteria: '전 과목 총점 60% 이상 + 매 과목 40% 이상 득점.',
    schedule: '연 1회, 매년 12월경 시행(원서접수 9월경). 2026년 시험일 12/19(토).',
    fee: '90,000원',
    url: 'https://www.kuksiwon.or.kr',
    icon: Icons.restaurant_menu,
  ),
  Certification(
    id: 'hygienist',
    name: '위생사',
    kind: CertKind.license,
    issuer: '한국보건의료인국가시험원 · 보건복지부',
    tagline: '식품·환경 위생 관리 전문 면허',
    eligibility:
        '대학에서 위생 관련 교과목을 이수하고 졸업한 자(또는 4학기 이상 수료 후 '
        '위생 관련 교과목 이수자).',
    subjects: [
      '공중보건학 (35문항)',
      '환경위생학 (50문항)',
      '식품위생학 (40문항)',
      '위생곤충학 (30문항)',
      '위생관계법령 (25문항)',
    ],
    method: '필기 5과목(총 180문항) + 실기시험.',
    passCriteria: '필기 매 과목 40% 이상 & 전 과목 총점 60% 이상, 실기 60% 이상.',
    schedule: '연 1회, 매년 하반기 시행. 상세 일정은 국시원 공고 확인.',
    url: 'https://www.kuksiwon.or.kr',
    icon: Icons.cleaning_services,
  ),
  Certification(
    id: 'clinical_dietitian',
    name: '임상영양사',
    kind: CertKind.license,
    issuer: '한국보건의료인국가시험원 · 보건복지부',
    tagline: '병원 등에서 질환별 영양치료를 담당하는 영양사 상위 국가자격',
    eligibility:
        '영양사 면허 소지자로서 임상영양사 교육과정을 수료하고 보건소·의료기관·집단급식소 등에서 '
        '1년 이상 영양사 실무경력을 갖춘 자. (영양 관련 석사학위 이상은 6개월 이상 경력으로 응시 가능.) '
        '먼저 영양사 국가시험 합격이 전제된다.',
    subjects: [
      '임상영양학',
      '영양판정 및 영양관리',
      '질환별 영양치료(의학영양요법)',
      '영양상담 및 교육',
    ],
    method: '보건복지부장관이 시행하는 임상영양사 자격시험(필기). 국시원 관리.',
    passCriteria: '전 과목 총점 60% 이상 + 매 과목 40% 이상(국시원 공고 기준).',
    schedule: '연 1회 시행. 교육과정(대한영양사협회 인정, 약 30주)+실무경력 요건 선이수.',
    url: 'https://www.kuksiwon.or.kr',
    icon: Icons.local_hospital,
  ),

  // ── 국가기술자격 (큐넷 / 한국산업인력공단) ──
  Certification(
    id: 'food_engineer',
    name: '식품기사',
    kind: CertKind.engineer,
    issuer: '한국산업인력공단(큐넷)',
    tagline: '식품 제조·가공·위생 전반의 기사 자격',
    eligibility:
        '관련 학과 4년제 졸업(예정), 또는 산업기사 취득 후 실무 1년, '
        '동일·유사 직무분야 실무 4년 등.',
    subjects: [
      '식품위생학',
      '식품화학',
      '식품가공학',
      '식품미생물학',
      '생화학 및 발효학',
    ],
    method: '필기 5과목(과목당 20문항, 4지선다) + 실기(식품생산관리 실무, 필답형+작업형).',
    passCriteria: '필기 과목당 40점 이상 & 평균 60점 이상, 실기 60점 이상.',
    schedule: '연 3회(정기) 시행.',
    fee: '필기 19,400원 / 실기 56,300원(변동 가능)',
    url: 'https://www.q-net.or.kr',
    icon: Icons.science,
  ),
  Certification(
    id: 'food_industrial_engineer',
    name: '식품산업기사',
    kind: CertKind.engineer,
    issuer: '한국산업인력공단(큐넷)',
    tagline: '식품 제조·가공 실무 중심의 산업기사 자격',
    eligibility: '관련 학과 2년제 졸업(예정), 또는 동일 직무분야 실무 2년 등.',
    subjects: [
      '식품위생학',
      '식품가공학',
      '식품화학',
      '식품미생물학',
    ],
    method: '필기 4과목(과목당 20문항) + 실기(식품생산관리 실무).',
    passCriteria: '필기 과목당 40점 이상 & 평균 60점 이상, 실기 60점 이상.',
    schedule: '연 3회(정기) 시행.',
    url: 'https://www.q-net.or.kr',
    icon: Icons.factory,
  ),
  Certification(
    id: 'cook_craftsman',
    name: '조리기능사',
    kind: CertKind.craftsman,
    issuer: '한국산업인력공단(큐넷)',
    tagline: '한식·양식·중식·일식·복어 등 종목별 조리 자격',
    eligibility: '응시 제한 없음(누구나 응시 가능).',
    subjects: [
      '재료관리 · 음식조리 및 위생관리(필기 통합)',
    ],
    method: '필기 60문항(60분, 4지선다) + 실기(작업형).',
    passCriteria: '필기 60점 이상, 실기 60점 이상.',
    schedule: '필기 상시/정기, 실기 종목별 시행.',
    fee: '필기 14,500원 / 실기 종목별 상이',
    url: 'https://www.q-net.or.kr',
    icon: Icons.soup_kitchen,
  ),
  Certification(
    id: 'bakery_craftsman',
    name: '제과·제빵기능사',
    kind: CertKind.craftsman,
    issuer: '한국산업인력공단(큐넷)',
    tagline: '과자류·빵류 제조 기능 자격',
    eligibility: '응시 제한 없음(누구나 응시 가능).',
    subjects: [
      '과자류/빵류 재료 · 제조 및 위생관리(필기)',
    ],
    method: '필기 60문항(60분) + 실기(작업형). 제과·제빵 각각 응시.',
    passCriteria: '필기 60점 이상, 실기 60점 이상.',
    schedule: '필기 상시, 실기 정기 시행.',
    fee: '필기 14,500원 / 실기 종목별 상이',
    url: 'https://www.q-net.or.kr',
    icon: Icons.bakery_dining,
  ),

  // ── 민간자격 (학회/협회) ──
  Certification(
    id: 'nsca_snc',
    name: '스포츠 영양코치 (SNC)',
    kind: CertKind.private,
    issuer: 'NSCA Korea (미국체력관리학회 한국지부)',
    tagline: '운동수행능력 향상을 위한 스포츠영양 코칭 민간자격',
    eligibility:
        'NSCA Korea 스포츠영양 교육(온라인 강의) 수강자. 기본(Level 1)·심화(Advanced) '
        '단계로 운영되며, 특별한 학력 제한 없이 관심자가 응시할 수 있다(상세는 공고 확인).',
    subjects: [
      '스포츠영양학 기초·응용 (NSCA 교재 기반)',
      '기본(Level 1) / 심화(Advanced) 과정 구분',
    ],
    method: '온라인 강의 수강 후 정기 자격시험 응시(레벨별 운영).',
    passCriteria: 'NSCA Korea 공고 기준. 불합격 시 바로 다음 회차 1회 무료 재응시.',
    schedule: '연 수 회 정기 시험(서울·천안 등 지역별 시행). 일정·장소는 공지 확인.',
    fee: '교육/응시 비용은 과정·레벨별 상이(공식 사이트 확인)',
    url: 'https://www.nscakorea.com/snc',
    icon: Icons.fitness_center,
  ),

  // ── 국제자격 (International Society of Sports Nutrition, ISSN) ──
  Certification(
    id: 'issn_cissn',
    name: 'CISSN (국제공인 스포츠영양사)',
    kind: CertKind.international,
    issuer: 'International Society of Sports Nutrition (ISSN, 미국 국제스포츠영양학회)',
    tagline: 'ISSN이 인증하는 스포츠영양 국제 전문 자격(상위 등급) · 영어 시험',
    eligibility:
        '4년제 대학 학사 학위 소지자(전공 무관 — 영양·운동과학이 아니어도 응시 가능). '
        '전공이 아닌 경우 기초 영양학 지식이 시험 준비에 도움이 된다. '
        'ISSN 정회원 등록 후 응시.',
    subjects: [
      'ISSN Position Stands(공식 입장문) 기반 스포츠영양학',
      '에너지 대사·다량영양소·수분 보충',
      '스포츠 보충제(단백질/크레아틴/카페인 등)의 근거',
      '운동수행·체성분 관리 영양 전략',
    ],
    method: '온라인 감독형 컴퓨터 시험. 객관식 200문항, 제한시간 135분(오픈북 아님). '
        '⚠️ 시험·교재 전 과정이 영어로 진행되므로 영어 독해 능력이 필요하다.',
    passCriteria: '70% 이상 득점 시 합격. 합격 시 전자 인증서 발급.',
    schedule: '온라인으로 상시 응시(사전 등록·예약제). 자격 유지 시 연간 CEU(보수교육) 필요.',
    fee: r'정회원 응시 $621 + 회원등록 $169 (합계 약 $790) / 비회원 $998. 유지비 연 $149.',
    url: 'https://www.sportsnutritionsociety.org',
    icon: Icons.public,
  ),
  Certification(
    id: 'issn_sns',
    name: 'SNS (스포츠영양 스페셜리스트)',
    kind: CertKind.international,
    issuer: 'International Society of Sports Nutrition (ISSN, 미국 국제스포츠영양학회)',
    tagline: '학위가 없어도 도전 가능한 ISSN 스포츠영양 응용 자격 · 영어 시험',
    eligibility:
        '4년제 학위나 운동과학·스포츠영양 정규 교육 배경이 없는 사람을 위한 과정. '
        '개인 트레이너·피트니스 지도자 등 현장 실무자가 주 대상.',
    subjects: [
      '스포츠영양 기초 이론',
      '실전 적용 중심의 영양 코칭',
      'ISSN 교육 콘텐츠 기반 학습',
    ],
    method: '온라인 강의 수강 후 온라인 시험 응시(응용·실무 중심). CISSN보다 입문 단계. '
        '⚠️ 강의·시험이 모두 영어로 진행된다.',
    passCriteria: 'ISSN 기준 통과 시 자격 부여(상세는 공식 사이트 확인).',
    schedule: '온라인으로 상시 수강·응시.',
    fee: '과정·회원 여부에 따라 상이(공식 사이트 확인)',
    url: 'https://www.sportsnutritionsociety.org',
    icon: Icons.sports_gymnastics,
  ),
  Certification(
    id: 'nasm_cnc',
    name: 'NASM-CNC (공인 영양코치)',
    kind: CertKind.international,
    issuer: 'NASM (미국스포츠의학회, National Academy of Sports Medicine)',
    tagline: 'NCCA 인증. 트레이너·코치와 잘 맞는 미국 영양코치 자격',
    eligibility:
        '별도 선수강 요건 없음(누구나 등록 가능). 학위 불필요. '
        '개인 트레이너·피트니스 종사자에게 특히 적합.',
    subjects: [
      '영양과학 기초(다량·미량영양소)',
      '행동변화 코칭·상담 기술',
      '체중관리·식단 구성 전략',
      '보충제와 근거 기반 영양',
    ],
    method: '온라인 강의 + 온라인 시험. 객관식 100문항, 90분, 오픈북, 최대 3회 응시. '
        '⚠️ 전 과정 영어로 진행.',
    passCriteria: '70% 이상 득점 시 합격.',
    schedule: '온라인 상시 등록·응시(구매 후 1년 내 완료).',
    fee: r'월 구독형(약 $49~/월, 프로모션에 따라 상이). 공식 사이트 확인.',
    url: 'https://www.nasm.org/products/certified-nutrition-coach',
    icon: Icons.eco,
  ),
  Certification(
    id: 'nasm_csnc',
    name: 'NASM-CSNC (공인 스포츠영양코치)',
    kind: CertKind.international,
    issuer: 'NASM (미국스포츠의학회, National Academy of Sports Medicine)',
    tagline: 'CNC보다 심화. 운동선수 경기력 영양에 특화된 국제자격',
    eligibility:
        '별도 선수강 요건 없음. 다만 영양 기초 지식(CNC 등)이 있으면 학습에 유리하다. '
        '선수·운동인 대상 스포츠영양 실무를 원하는 사람에게 적합.',
    subjects: [
      '운동수행 에너지 대사',
      '경기 전·중·후 영양 및 수분 전략',
      '체성분·체중 조절',
      '스포츠 보충제(에르고제닉)',
    ],
    method: '온라인 강의 + 온라인 시험(경기력 영양 심화). ⚠️ 전 과정 영어로 진행.',
    passCriteria: 'NASM 기준 통과 시 자격 부여(공식 사이트 확인).',
    schedule: '온라인 상시 등록·응시.',
    fee: '과정별 상이(공식 사이트 확인)',
    url: 'https://www.nasm.org/products/sports-nutrition-certification',
    icon: Icons.directions_run,
  ),
];
