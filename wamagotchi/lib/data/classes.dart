/// 클래스(작업 패턴 진화) 데이터 (Phase 5 — 게임 시스템 기획서 2.2).
///
/// Lv.30 도달 시 최근 저장 패턴으로 판정되어 확정된다.
library;

class ClassSpec {
  final String id;
  final String name;
  final String desc;

  /// 치명타 확률 보너스 (+%p)
  final double critBonus;

  /// 패배 시 후퇴 무효 확률 보너스 (+%p)
  final double guardBonus;

  /// 마나 획득 배율 보너스 (+비율)
  final double manaRate;

  /// 저장 시 포만감 회복 배율 보너스 (+비율)
  final double hungerGainRate;

  /// 층 돌파에 필요한 룸 수 감소 (민첩)
  final int roomsReduction;

  const ClassSpec({
    required this.id,
    required this.name,
    required this.desc,
    this.critBonus = 0,
    this.guardBonus = 0,
    this.manaRate = 0,
    this.hungerGainRate = 0,
    this.roomsReduction = 0,
  });
}

class Classes {
  Classes._();

  static const List<ClassSpec> all = [
    ClassSpec(
      id: 'shadow_rogue',
      name: '그림자 도적',
      desc: '심야의 집필자. 어둠 속에서 급소를 노린다 — 치명타 +5%p',
      critBonus: 0.05,
    ),
    ClassSpec(
      id: 'dawn_priest',
      name: '여명 사제',
      desc: '아침의 집필자. 새벽 기도의 축복 — 저장 포만감 회복 +15%',
      hungerGainRate: 0.15,
    ),
    ClassSpec(
      id: 'assassin',
      name: '암살자',
      desc: '짧고 잦은 기록의 달인. 빠른 발놀림 — 층 돌파 필요 룸 −1',
      roomsReduction: 1,
    ),
    ClassSpec(
      id: 'knight',
      name: '기사',
      desc: '장문의 집필자. 묵직한 원고의 방벽 — 후퇴 무효 +15%p',
      guardBonus: 0.15,
    ),
    ClassSpec(
      id: 'adventurer',
      name: '모험가',
      desc: '균형 잡힌 기록자. 두루 밝은 눈 — 모든 마나 +5%',
      manaRate: 0.05,
    ),
  ];

  static ClassSpec? byId(String? id) {
    if (id == null) return null;
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }
}
