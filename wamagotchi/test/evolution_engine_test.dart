import 'package:flutter_test/flutter_test.dart';
import 'package:wamagotchi/data/items.dart';
import 'package:wamagotchi/logic/evolution_engine.dart';

List<SaveStat> _stats(List<(int hour, int chars)> entries) {
  return entries
      .map((e) => SaveStat(DateTime(2026, 7, 1, e.$1, 0), e.$2))
      .toList();
}

void main() {
  group('클래스 판정 (EvolutionEngine.judge) — 시스템 기획서 2.2', () {
    test('심야형(22~02시 40%↑) → 그림자 도적', () {
      final stats = _stats([
        (23, 500), (23, 500), (0, 500), (1, 500), // 심야 4
        (14, 500), (15, 500), (16, 500), (17, 500), (18, 500), (19, 500),
      ]);
      expect(EvolutionEngine.judge(stats), 'shadow_rogue');
    });

    test('아침형(05~09시 40%↑) → 여명 사제', () {
      final stats = _stats([
        (6, 500), (7, 500), (8, 500), (5, 500), // 아침 4
        (14, 500), (15, 500), (16, 500), (17, 500), (18, 500), (19, 500),
      ]);
      expect(EvolutionEngine.judge(stats), 'dawn_priest');
    });

    test('단문형(평균 300자 미만) → 암살자', () {
      final stats = _stats([
        (14, 100), (15, 150), (16, 120), (17, 200), (18, 90),
      ]);
      expect(EvolutionEngine.judge(stats), 'assassin');
    });

    test('장문형(2,000자↑ 비중 30%↑) → 기사', () {
      final stats = _stats([
        (14, 2500), (15, 3000), // 장문 2/5 = 40%
        (16, 800), (17, 900), (18, 700),
      ]);
      expect(EvolutionEngine.judge(stats), 'knight');
    });

    test('해당 없음 → 모험가', () {
      final stats = _stats([
        (14, 500), (15, 600), (16, 700), (17, 800), (18, 900),
      ]);
      expect(EvolutionEngine.judge(stats), 'adventurer');
    });

    test('통계가 없으면 모험가', () {
      expect(EvolutionEngine.judge([]), 'adventurer');
    });

    test('우선순위: 심야가 단문보다 먼저', () {
      // 심야 100% + 평균 100자 → 심야 우선
      final stats = _stats([(23, 100), (23, 100), (0, 100)]);
      expect(EvolutionEngine.judge(stats), 'shadow_rogue');
    });
  });

  group('아이템 데이터 무결성 (Phase 5)', () {
    test('id 중복 없음', () {
      final ids = Items.all.map((i) => i.id).toSet();
      expect(ids.length, Items.all.length);
    });

    test('구매 가능한 장비·특수는 레벨 제한과 가격이 있다', () {
      for (final item in Items.all.where((i) => i.isBuyable)) {
        expect(item.price > 0, true, reason: item.id);
      }
      // 시작 무기를 제외한 모든 무기는 레벨 제한 보유
      final weapons = Items.all.where(
          (i) => i.type == ItemType.weapon && i.id != Items.starterWeaponId);
      for (final w in weapons) {
        expect(w.minLevel > 1, true, reason: w.id);
      }
    });

    test('재료는 판매가가 있고 비매품이다', () {
      for (final m in Items.all.where((i) => i.type == ItemType.material)) {
        expect(m.sellPrice > 0, true, reason: m.id);
        expect(m.isBuyable, false, reason: m.id);
      }
    });

    test('byId 조회', () {
      expect(Items.byId('golden_keycap_hammer')?.atkBonus, 10);
      expect(Items.byId('없는아이템'), null);
      expect(Items.byId(null), null);
    });
  });
}
