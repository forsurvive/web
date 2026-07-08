/// 밸런스 상수 모음.
///
/// 게임의 모든 숫자는 코드가 아닌 이 파일에서 관리한다 (게임 시스템 기획서 원칙).
/// 수치를 바꾸고 싶으면 이 파일만 수정하면 된다. Flutter를 import하지 않는 순수 Dart.
library;

class Balance {
  Balance._();

  // ── 재화·경험치 (기획서 5.1 / 시스템 기획서 10.1) ──────────────
  /// 새로 늘어난 글자 1자당 마나
  static const int manaPerChar = 1;

  /// 새로 늘어난 글자 1자당 경험치
  static const int expPerChar = 1;

  /// 최대 레벨 (도달 시 은퇴 가능 — 환생은 Phase 5)
  static const int maxLevel = 100;

  /// 레벨업 필요 경험치: 50 + 12 × (Lv - 1)  (시스템 기획서 10.1 개정 곡선)
  static const int expCurveBase = 50;
  static const int expCurveSlope = 12;

  // ── 포만감 (시스템 기획서 3.1 개정 수치) ──────────────────────
  /// 저장 글자 100자당 포만감 회복량 (%p)
  static const double hungerGainPer100Chars = 8.0;

  /// 오늘의 첫 저장 회복 배수
  static const double firstSaveOfDayMultiplier = 2.0;

  /// 시간당 포만감 자연 감소량 (%p)
  static const double hungerDecayPerHour = 3.0;

  static const double hungerMax = 100.0;
  static const double hungerMin = 0.0;

  /// 시무룩 상태 진입 기준 (%p 미만)
  static const double moodSadThreshold = 20.0;

  // ── 방치형 던전 탐험 (Phase 3 — 시스템 기획서 5장) ────────────
  /// 탐험 틱 주기 (분). 포만감이 충분하면 이 주기마다 룸 1개를 진행한다.
  static const int tickMinutes = 5;

  /// 오프라인 정산 시 처리할 최대 틱 수 (8시간 = 96틱)
  static const int offlineCapTicks = 96;

  /// 탐험 조건: 포만감이 이 값(%p) 이상일 때만 전진
  static const double exploreHungerThreshold = 50.0;

  /// 룸 타입 가중치 (합 100) — Phase 3은 전투/보물/휴식 3종
  static const int roomWeightBattle = 70;
  static const int roomWeightTreasure = 18;
  static const int roomWeightRest = 12;

  /// 전투 승률: base + perLevelDiff × (정령Lv − 몬스터Lv), min~max로 클램프
  static const double winBase = 0.75;
  static const double winPerLevelDiff = 0.035;
  static const double winMin = 0.35;
  static const double winMax = 0.97;

  /// 치명타 확률 (보상 2배)
  static const double critChance = 0.08;

  /// 휴식 룸 포만감 회복 (%p)
  static const double restHungerGain = 5.0;

  /// 희귀 전리품 확률 (보물 룸)
  static const double rareTreasureChance = 0.15;

  /// 패배 시 후퇴 층수 (일반 / 보스)
  static const int loseRetreatFloors = 1;
  static const int bossLoseRetreatFloors = 5;

  // ── 키워드 이벤트 (Phase 4 — 시스템 기획서 4.1) ───────────────
  /// 카테고리당 1일 발동 상한 (어뷰징 방지)
  static const int keywordDailyCap = 3;

  /// [성취의 기운] 버프: 지속 시간(분)과 마나 배율
  static const int buffManaDurationMinutes = 60;
  static const double buffManaMultiplier = 1.2;

  /// 긍정 키워드: 포만감 회복 (%p)
  static const double keywordHungerGain = 10.0;

  /// 오류 키워드: 버그 벌레 처치 보상 마나
  static const int bugBountyMana = 300;

  /// 마감 키워드: 즉시 진행하는 보너스 탐험 틱 수
  static const int deadlineBonusTicks = 2;

  // ── 클래스 진화 (Phase 5 — 시스템 기획서 2.2) ─────────────────
  /// 클래스가 확정되는 레벨
  static const int classLevel = 30;

  /// 판정에 사용할 최근 저장 통계 개수
  static const int classStatsWindow = 30;

  /// 심야형(22~02시)·아침형(05~09시) 판정 비중
  static const double classNightShare = 0.4;
  static const double classMorningShare = 0.4;

  /// 단문형: 평균 저장 글자 수 미만
  static const int classShortAvgChars = 300;

  /// 장문형: 이 글자 수 이상 저장의 비중
  static const int classLongChars = 2000;
  static const double classLongShare = 0.3;

  // ── 환생 (Phase 5 — 시스템 기획서 9장) ────────────────────────
  /// 첫 환생 시 글자당 마나 배율 증가분 (1.0 → 1.5)
  static const double prestigeFirstBonus = 0.5;

  /// 이후 환생마다 추가 배율
  static const double prestigeExtraBonus = 0.25;

  // ── 성장 단계 (시스템 기획서 1.4) ─────────────────────────────
  /// 알이 부화하는 레벨 (부화 시 유저가 이름을 지어 준다)
  static const int hatchLevel = 5;

  // ── 정령 이름 규칙 (시스템 기획서 1.1) ────────────────────────
  static const int nameMinLength = 1;
  static const int nameMaxLength = 8;

  /// '이름 뽑기' 랜덤 후보
  static const List<String> nameSuggestions = [
    '잉크', '모모', '도트', '먹물', '쉼표', '나기', '픽셀', '심야',
  ];

  /// 금칙어 (최소 필터 — 추후 사전 확장)
  static const List<String> bannedNameWords = ['시발', '씨발', '병신'];

  // ── 로그 ─────────────────────────────────────────────────────
  /// 저장·표시할 최근 로그 최대 개수
  static const int maxLogLines = 30;
}
