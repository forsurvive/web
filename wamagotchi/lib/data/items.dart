/// 아이템 데이터 (Phase 4~5 — 게임 시스템 기획서 7장).
///
/// 순수 Dart 데이터. 효과 수치는 전부 여기서 관리한다.
/// [minLevel]: 구매·장착 공통 레벨 제한.
library;

enum ItemType { weapon, armor, accessory, special, consumable, material }

class ItemSpec {
  final String id;
  final String name;
  final ItemType type;
  final String desc;

  /// 구매·장착에 필요한 최소 레벨
  final int minLevel;

  /// 상점 구매가 (0 = 비매품)
  final int price;

  /// 판매가 (0 = 판매 불가)
  final int sellPrice;

  /// 무기: 전투력 보너스 (승률 계산 시 정령 레벨에 가산)
  final int atkBonus;

  /// 방어구: 패배 시 후퇴를 무효화할 확률 (0.0~1.0)
  final double guardChance;

  /// 장신구: 치명타 확률 보너스 (+%p)
  final double critBonus;

  /// 장신구: 희귀 전리품 확률 보너스 (+%p)
  final double rareBonus;

  /// 장신구: 마나 획득 배율 보너스 (+비율, 0.05 = +5%)
  final double manaRate;

  /// 특수(영구): 포만감 자연 감소 저감 비율 (0.25 = −25%)
  final double decayReduction;

  /// 소모품: 포만감 회복량 (%p)
  final double hungerRestore;

  /// 소모품: 사용 즉시 진행하는 탐험 틱 수
  final int bonusTicks;

  const ItemSpec({
    required this.id,
    required this.name,
    required this.type,
    required this.desc,
    this.minLevel = 1,
    this.price = 0,
    this.sellPrice = 0,
    this.atkBonus = 0,
    this.guardChance = 0,
    this.critBonus = 0,
    this.rareBonus = 0,
    this.manaRate = 0,
    this.decayReduction = 0,
    this.hungerRestore = 0,
    this.bonusTicks = 0,
  });

  bool get isEquipment =>
      type == ItemType.weapon ||
      type == ItemType.armor ||
      type == ItemType.accessory;

  /// 1개만 보유 의미가 있는 아이템 (장비·특수)
  bool get isUnique => isEquipment || type == ItemType.special;

  bool get isBuyable => price > 0;
}

class Items {
  Items._();

  /// 최초 지급 무기
  static const String starterWeaponId = 'pencil_sword';

  static const List<ItemSpec> all = [
    // ── 무기 (전투력) ─────────────────────────────────────
    ItemSpec(
        id: 'pencil_sword',
        name: '낡은 연필검',
        type: ItemType.weapon,
        desc: '처음부터 함께한 검. 전투 +1',
        atkBonus: 1),
    ItemSpec(
        id: 'steel_nib',
        name: '강철 펜촉',
        type: ItemType.weapon,
        desc: '단단한 필기의 힘. 전투 +3',
        minLevel: 5,
        price: 2000,
        atkBonus: 3),
    ItemSpec(
        id: 'highlighter_sword',
        name: '형광펜 대검',
        type: ItemType.weapon,
        desc: '중요한 부분을 벤다. 전투 +4',
        minLevel: 10,
        price: 2800,
        atkBonus: 4),
    ItemSpec(
        id: 'fountain_rapier',
        name: '만년필 레이피어',
        type: ItemType.weapon,
        desc: '유려한 필체의 찌르기. 전투 +5',
        minLevel: 15,
        price: 4500,
        atkBonus: 5),
    ItemSpec(
        id: 'exclamation_spear',
        name: '느낌표 창',
        type: ItemType.weapon,
        desc: '확신의 일격. 전투 +7',
        minLevel: 22,
        price: 7500,
        atkBonus: 7),
    ItemSpec(
        id: 'question_staff',
        name: '물음표 지팡이',
        type: ItemType.weapon,
        desc: '좋은 질문은 무엇보다 강하다. 전투 +8',
        minLevel: 30,
        price: 11000,
        atkBonus: 8),
    ItemSpec(
        id: 'golden_keycap_hammer',
        name: '골든 키캡 해머',
        type: ItemType.weapon,
        desc: '황금 자판의 묵직한 한 방. 전투 +10',
        minLevel: 40,
        price: 18000,
        atkBonus: 10),

    // ── 방어구 (패배 시 후퇴 무효 확률) ───────────────────
    ItemSpec(
        id: 'backspace_shield',
        name: '백스페이스 방패',
        type: ItemType.armor,
        desc: '실수를 지워 준다. 패배 시 40% 확률로 후퇴 무효',
        minLevel: 5,
        price: 1500,
        guardChance: 0.4),
    ItemSpec(
        id: 'bookmark_cloak',
        name: '책갈피 망토',
        type: ItemType.armor,
        desc: '읽던 자리를 잃지 않는다. 후퇴 무효 55%',
        minLevel: 12,
        price: 2400,
        guardChance: 0.55),
    ItemSpec(
        id: 'manuscript_armor',
        name: '원고지 갑옷',
        type: ItemType.armor,
        desc: '켜켜이 쌓인 원고의 무게. 후퇴 무효 70%',
        minLevel: 20,
        price: 5000,
        guardChance: 0.7),
    ItemSpec(
        id: 'sleepmode_robe',
        name: '절전모드 로브',
        type: ItemType.armor,
        desc: '고요한 수호. 후퇴 무효 80%',
        minLevel: 32,
        price: 9000,
        guardChance: 0.8),

    // ── 장신구 ────────────────────────────────────────────
    ItemSpec(
        id: 'comma_earring',
        name: '쉼표 귀걸이',
        type: ItemType.accessory,
        desc: '잠깐의 쉼이 급소를 보인다. 치명타 +4%p',
        minLevel: 8,
        price: 1200,
        critBonus: 0.04),
    ItemSpec(
        id: 'bookmark_charm',
        name: '북마크 부적',
        type: ItemType.accessory,
        desc: '좋은 페이지를 기억한다. 희귀 전리품 +10%p',
        minLevel: 18,
        price: 2600,
        rareBonus: 0.10),
    ItemSpec(
        id: 'at_necklace',
        name: '@골뱅이 목걸이',
        type: ItemType.accessory,
        desc: '연결의 힘. 모든 마나 획득 +5%',
        minLevel: 25,
        price: 6000,
        manaRate: 0.05),
    ItemSpec(
        id: 'underline_ring',
        name: '밑줄 반지',
        type: ItemType.accessory,
        desc: '핵심에 밑줄을 긋는다. 치명타 +7%p',
        minLevel: 35,
        price: 9500,
        critBonus: 0.07),

    // ── 특수 (구매 즉시 영구 적용) ────────────────────────
    ItemSpec(
        id: 'auto_feeder',
        name: '자동 먹이통',
        type: ItemType.special,
        desc: '포만감 자연 감소 −25% (영구)',
        minLevel: 10,
        price: 5000,
        decayReduction: 0.25),

    // ── 소모품 ────────────────────────────────────────────
    ItemSpec(
        id: 'comma_potion',
        name: '쉼표 포션',
        type: ItemType.consumable,
        desc: '포만감 +30%p',
        price: 100,
        hungerRestore: 30),
    ItemSpec(
        id: 'quote_potion',
        name: '큰따옴표 포션',
        type: ItemType.consumable,
        desc: '포만감 +60%p',
        price: 180,
        hungerRestore: 60),
    ItemSpec(
        id: 'snack',
        name: '간식',
        type: ItemType.consumable,
        desc: '정령이 제일 좋아하는 주전부리. 포만감 +10%p',
        minLevel: 5,
        price: 150,
        hungerRestore: 10),
    ItemSpec(
        id: 'caffeine_potion',
        name: '카페인 물약',
        type: ItemType.consumable,
        desc: '번쩍! 마시면 즉시 3룸 전진',
        minLevel: 15,
        price: 400,
        bonusTicks: 3),

    // ── 재료 (던전 희귀 전리품·키워드 드롭 → 판매) ────────
    ItemSpec(
        id: 'stress_crystal',
        name: '스트레스 결정체',
        type: ItemType.material,
        desc: '고생이 뭉친 보석 — 고생이 보상이 된다',
        sellPrice: 800),
    ItemSpec(
        id: 'shiny_keycap',
        name: '빛나는 키캡',
        type: ItemType.material,
        desc: '어느 명작 키보드의 조각',
        sellPrice: 500),
    ItemSpec(
        id: 'crumpled_draft',
        name: '구겨진 초고 뭉치',
        type: ItemType.material,
        desc: '누군가의 버려진 걸작 후보',
        sellPrice: 350),
    ItemSpec(
        id: 'zip_fragment',
        name: '수상한 압축파일 조각',
        type: ItemType.material,
        desc: '열어 보지 않는 편이 좋았다',
        sellPrice: 600),
    ItemSpec(
        id: 'slime_ink',
        name: '슬라임 잉크',
        type: ItemType.material,
        desc: '진득하고 반짝이는 필기 재료',
        sellPrice: 450),
    ItemSpec(
        id: 'cookie_shard',
        name: '오래된 쿠키 파편',
        type: ItemType.material,
        desc: '당신을 기억하는 과자 부스러기',
        sellPrice: 700),
    ItemSpec(
        id: 'defrag_shard',
        name: '디스크 조각 파편',
        type: ItemType.material,
        desc: '심연에서 건진 기억의 조각',
        sellPrice: 900),
  ];

  static ItemSpec? byId(String? id) {
    if (id == null) return null;
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }
}
