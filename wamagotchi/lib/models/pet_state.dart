import '../data/balance.dart';

/// 정령(펫)의 상태.
///
/// 이름은 게임이 정하지 않는다 — Lv.5 부화 시 유저가 직접 입력한다 (name == null 이면 아직 알).
class PetState {
  /// 유저가 지어 준 이름. null이면 아직 부화 전(알)이거나 이름을 짓지 않은 상태.
  String? name;

  int level;

  /// 현재 레벨 안에서 쌓인 경험치
  int exp;

  int mana;

  /// 포만감 0.0 ~ 100.0 (%p)
  double hunger;

  /// 함께 쓴 누적 글자 수 (통계 · 훗날 명예의 전당 기록용)
  int totalChars;

  /// 포만감 자연 감소를 마지막으로 정산한 시각
  DateTime lastHungerTickAt;

  /// 마지막으로 글자를 얻은 날짜(yyyy-MM-dd). '오늘의 첫 저장' 판정용.
  String? lastSaveYmd;

  DateTime createdAt;

  PetState({
    this.name,
    this.level = 1,
    this.exp = 0,
    this.mana = 0,
    this.hunger = Balance.hungerMax,
    this.totalChars = 0,
    DateTime? lastHungerTickAt,
    this.lastSaveYmd,
    DateTime? createdAt,
  })  : lastHungerTickAt = lastHungerTickAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  /// 아직 알인가? (부화 레벨 미만)
  bool get isEgg => level < Balance.hatchLevel;

  /// 부화했지만 이름을 아직 짓지 않았는가? (이름 입력을 요청해야 함)
  bool get needsNaming => !isEgg && name == null;

  /// 화면에 보여줄 이름
  String get displayName {
    if (name != null) return name!;
    return isEgg ? '이름 없는 알' : '이름을 기다리는 정령';
  }

  /// 기분 (Phase 1: 평온/시무룩/기절 3종 — 시스템 기획서 1.5)
  String get moodLabel {
    if (hunger <= Balance.hungerMin) return '기절';
    if (hunger < Balance.moodSadThreshold) return '시무룩';
    return '평온';
  }

  /// 상태창 얼굴 (Phase 1은 텍스트, Phase 2에서 픽셀 아트로 교체)
  String get face {
    if (isEgg) return '( ● )';
    if (hunger <= Balance.hungerMin) return '[ x_x ]';
    if (hunger < Balance.moodSadThreshold) return '[ ;_; ]';
    return '[ 0_0 ]';
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'level': level,
        'exp': exp,
        'mana': mana,
        'hunger': hunger,
        'totalChars': totalChars,
        'lastHungerTickAt': lastHungerTickAt.toIso8601String(),
        'lastSaveYmd': lastSaveYmd,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PetState.fromJson(Map<String, dynamic> json) {
    return PetState(
      name: json['name'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 1,
      exp: (json['exp'] as num?)?.toInt() ?? 0,
      mana: (json['mana'] as num?)?.toInt() ?? 0,
      hunger: (json['hunger'] as num?)?.toDouble() ?? Balance.hungerMax,
      totalChars: (json['totalChars'] as num?)?.toInt() ?? 0,
      lastHungerTickAt: json['lastHungerTickAt'] != null
          ? DateTime.parse(json['lastHungerTickAt'] as String)
          : DateTime.now(),
      lastSaveYmd: json['lastSaveYmd'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
