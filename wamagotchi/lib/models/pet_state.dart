import '../data/balance.dart';
import '../data/items.dart';
import '../logic/evolution_engine.dart';

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

  // ── 방치형 탐험 위치 (Phase 3) ──────────────────────────
  /// 현재 던전 (Dungeons.all 인덱스)
  int dungeonIndex;

  /// 현재 층 (1부터)
  int floor;

  /// 현재 층에서 진행한 룸 수
  int roomsDone;

  // ── 장비·인벤토리 (Phase 4) ─────────────────────────────
  /// 장착 슬롯 (아이템 id)
  String? weaponId;
  String? armorId;
  String? accessoryId;

  /// 보유 아이템 (id → 개수). 장착 중인 장비는 여기서 빠져 있다.
  Map<String, int> inventory;

  // ── 버프·키워드 (Phase 4) ───────────────────────────────
  /// [성취의 기운] 종료 시각 (null이면 비활성)
  DateTime? buffManaUntil;

  /// 키워드 일일 상한 관리: 기준 날짜와 카테고리별 발동 횟수
  String? kwYmd;
  Map<String, int> kwUsed;

  // ── 클래스·환생 (Phase 5) ───────────────────────────────
  /// Lv.30에 확정되는 클래스 (Classes id). null이면 미확정.
  String? classId;

  /// 클래스 판정용 최근 저장 통계 (최대 30개)
  List<SaveStat> saveStats;

  /// 환생(은퇴) 횟수
  int prestigeCount;

  /// 이 생애가 시작될 때의 누적 글자 수 (전당 기록용)
  int lifeStartTotalChars;

  /// 이 생애의 시작 시각
  DateTime lifeStartAt;

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
    this.dungeonIndex = 0,
    this.floor = 1,
    this.roomsDone = 0,
    this.weaponId = Items.starterWeaponId,
    this.armorId,
    this.accessoryId,
    Map<String, int>? inventory,
    this.buffManaUntil,
    this.kwYmd,
    Map<String, int>? kwUsed,
    this.classId,
    List<SaveStat>? saveStats,
    this.prestigeCount = 0,
    this.lifeStartTotalChars = 0,
    DateTime? lifeStartAt,
    DateTime? lastHungerTickAt,
    this.lastSaveYmd,
    DateTime? createdAt,
  })  : inventory = inventory ?? {},
        kwUsed = kwUsed ?? {},
        saveStats = saveStats ?? [],
        lifeStartAt = lifeStartAt ?? DateTime.now(),
        lastHungerTickAt = lastHungerTickAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  /// 환생에 따른 글자당 마나 배율 (첫 환생 1.5배, 이후 +0.25)
  double get prestigeManaMult => prestigeCount <= 0
      ? 1.0
      : 1.0 +
          Balance.prestigeFirstBonus +
          Balance.prestigeExtraBonus * (prestigeCount - 1);

  /// [성취의 기운] 버프가 지금 활성인가
  bool get buffActive =>
      buffManaUntil != null && DateTime.now().isBefore(buffManaUntil!);

  /// 지금 탐험이 가동 중인가 (포만감 조건)
  bool get isExploring =>
      !isEgg && hunger >= Balance.exploreHungerThreshold;

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
        'dungeonIndex': dungeonIndex,
        'floor': floor,
        'roomsDone': roomsDone,
        'weaponId': weaponId,
        'armorId': armorId,
        'accessoryId': accessoryId,
        'inventory': inventory,
        'buffManaUntil': buffManaUntil?.toIso8601String(),
        'kwYmd': kwYmd,
        'kwUsed': kwUsed,
        'classId': classId,
        'saveStats': saveStats.map((s) => s.toJson()).toList(),
        'prestigeCount': prestigeCount,
        'lifeStartTotalChars': lifeStartTotalChars,
        'lifeStartAt': lifeStartAt.toIso8601String(),
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
      dungeonIndex: (json['dungeonIndex'] as num?)?.toInt() ?? 0,
      floor: (json['floor'] as num?)?.toInt() ?? 1,
      roomsDone: (json['roomsDone'] as num?)?.toInt() ?? 0,
      weaponId: json['weaponId'] as String? ?? Items.starterWeaponId,
      armorId: json['armorId'] as String?,
      accessoryId: json['accessoryId'] as String?,
      inventory: (json['inventory'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
          {},
      buffManaUntil: json['buffManaUntil'] != null
          ? DateTime.parse(json['buffManaUntil'] as String)
          : null,
      kwYmd: json['kwYmd'] as String?,
      kwUsed: (json['kwUsed'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
          {},
      classId: json['classId'] as String?,
      saveStats: (json['saveStats'] as List<dynamic>?)
              ?.map((e) => SaveStat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      prestigeCount: (json['prestigeCount'] as num?)?.toInt() ?? 0,
      lifeStartTotalChars:
          (json['lifeStartTotalChars'] as num?)?.toInt() ?? 0,
      lifeStartAt: json['lifeStartAt'] != null
          ? DateTime.parse(json['lifeStartAt'] as String)
          : DateTime.now(),
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
