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
