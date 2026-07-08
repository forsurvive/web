/// 아이템 데이터 (Phase 4 — 게임 시스템 기획서 7장의 P2 범위).
///
/// 순수 Dart 데이터. 효과 수치는 전부 여기서 관리한다.
library;

enum ItemType { weapon, armor, accessory, consumable, material }

class ItemSpec {
  final String id;
  final String name;
  final ItemType type;
  final String desc;

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

  /// 소모품: 포만감 회복량 (%p)
  final double hungerRestore;

  const ItemSpec({
    required this.id,
    required this.name,
    required this.type,
    required this.desc,
    this.price = 0,
    this.sellPrice = 0,
    this.atkBonus = 0,
    this.guardChance = 0,
    this.critBonus = 0,
    this.rareBonus = 0,
    this.hungerRestore = 0,
  });

  bool get isEquipment =>
      type == ItemType.weapon ||
      type == ItemType.armor ||
      type == ItemType.accessory;

  bool get isBuyable => price > 0;
}

class Items {
  Items._();

  /// 최초 지급 무기
  static const String starterWeaponId = 'pencil_sword';

  static const List<ItemSpec> all = [
    // ── 무기 ──────────────────────────────────────────────
    ItemSpec(
      id: 'pencil_sword',
      name: '낡은 연필검',
      type: ItemType.weapon,
      desc: '처음부터 함께한 검. 전투 +1',
      atkBonus: 1,
    ),
    ItemSpec(
      id: 'steel_nib',
      name: '강철 펜촉',
      type: ItemType.weapon,
      desc: '단단한 필기의 힘. 전투 +3',
      price: 2000,
      atkBonus: 3,
    ),
    ItemSpec(
      id: 'fountain_rapier',
      name: '만년필 레이피어',
      type: ItemType.weapon,
      desc: '유려한 필체의 찌르기. 전투 +5',
      price: 4500,
      atkBonus: 5,
    ),
    // ── 방어구 ────────────────────────────────────────────
    ItemSpec(
      id: 'backspace_shield',
      name: '백스페이스 방패',
      type: ItemType.armor,
      desc: '패배 시 40% 확률로 후퇴를 무효화',
      price: 1500,
      guardChance: 0.4,
    ),
    ItemSpec(
      id: 'manuscript_armor',
      name: '원고지 갑옷',
      type: ItemType.armor,
      desc: '패배 시 70% 확률로 후퇴를 무효화',
      price: 3000,
      guardChance: 0.7,
    ),
    // ── 장신구 ────────────────────────────────────────────
    ItemSpec(
      id: 'comma_earring',
      name: '쉼표 귀걸이',
      type: ItemType.accessory,
      desc: '잠깐의 쉼이 급소를 보인다. 치명타 +4%p',
      price: 1200,
      critBonus: 0.04,
    ),
    ItemSpec(
      id: 'bookmark_charm',
      name: '북마크 부적',
      type: ItemType.accessory,
      desc: '좋은 페이지를 기억한다. 희귀 전리품 +10%p',
      price: 2600,
      rareBonus: 0.10,
    ),
    // ── 소모품 ────────────────────────────────────────────
    ItemSpec(
      id: 'comma_potion',
      name: '쉼표 포션',
      type: ItemType.consumable,
      desc: '포만감 +30%p',
      price: 100,
      hungerRestore: 30,
    ),
    ItemSpec(
      id: 'quote_potion',
      name: '큰따옴표 포션',
      type: ItemType.consumable,
      desc: '포만감 +60%p',
      price: 180,
      hungerRestore: 60,
    ),
    // ── 재료 ──────────────────────────────────────────────
    ItemSpec(
      id: 'stress_crystal',
      name: '스트레스 결정체',
      type: ItemType.material,
      desc: '고생이 뭉친 보석. 상점에 800 M로 판다 — 고생이 보상이 된다',
      sellPrice: 800,
    ),
  ];

  static ItemSpec? byId(String? id) {
    if (id == null) return null;
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }
}
