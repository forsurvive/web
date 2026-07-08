/// 방치형 던전 탐험 엔진 (Phase 3).
///
/// 순수 로직 — Flutter에 의존하지 않고, Random을 주입받아 테스트 가능하다.
/// 틱 1회 = 룸 1개 진행. 결과는 [TickOutcome]으로 돌려주고 상태 반영은 뷰모델의 몫.
library;

import 'dart:math';

import '../data/balance.dart';
import '../data/dungeons.dart';
import '../data/items.dart';

/// 장비에서 오는 탐험 보정치 (Phase 4)
class AdventureMods {
  /// 무기: 승률 계산 시 정령 레벨에 가산
  final int atkBonus;

  /// 방어구: 패배 시 후퇴 무효 확률
  final double guardChance;

  /// 장신구: 치명타 확률 보너스
  final double critBonus;

  /// 장신구: 희귀 전리품 확률 보너스
  final double rareBonus;

  /// 클래스(암살자): 층 돌파 필요 룸 수 감소
  final int roomsReduction;

  const AdventureMods({
    this.atkBonus = 0,
    this.guardChance = 0,
    this.critBonus = 0,
    this.rareBonus = 0,
    this.roomsReduction = 0,
  });

  static const AdventureMods none = AdventureMods();
}

/// 탐험 틱 1회의 결과
class TickOutcome {
  final String message;

  /// 집필 동기를 북돋는 특별 이벤트 → 화면 하단 알림 대상
  final bool highlight;

  final int manaGained;
  final double hungerGained;

  /// 획득한 아이템 id (희귀 전리품 — 가방으로)
  final String? itemGained;

  // 틱 이후의 위치
  final int dungeonIndex;
  final int floor;
  final int roomsDone;

  const TickOutcome({
    required this.message,
    required this.highlight,
    required this.manaGained,
    required this.hungerGained,
    this.itemGained,
    required this.dungeonIndex,
    required this.floor,
    required this.roomsDone,
  });
}

class AdventureEngine {
  AdventureEngine._();

  /// int 전용 클램프 (int.clamp는 num을 반환해 인덱스로 못 쓴다)
  static int _clampInt(int v, int lo, int hi) =>
      v < lo ? lo : (v > hi ? hi : v);

  /// 층당 룸 수 (3~5, 층 번호로 결정 — 플랫폼 간 동일해야 해서 결정적)
  static int roomsPerFloor(int floor) => 3 + ((floor * 7) % 3);

  /// 전투 승률
  static double winChance(int petLevel, int monsterLevel) {
    final p =
        Balance.winBase + Balance.winPerLevelDiff * (petLevel - monsterLevel);
    if (p < Balance.winMin) return Balance.winMin;
    if (p > Balance.winMax) return Balance.winMax;
    return p;
  }

  /// 몬스터 처치 보상 마나
  static int battleReward(MonsterSpec m, int floor) {
    final base = 8 + 4 * m.level + 2 * floor;
    return m.isBoss ? base * 5 : base;
  }

  /// 보물 룸 보상 마나
  static int treasureReward(int floor, {required bool rare}) {
    return 15 + 6 * floor + (rare ? 150 : 0);
  }

  /// 탐험 틱 1회 실행. [petPrestige]는 심층 던전 개방 판정용 (Phase 5).
  static TickOutcome runTick({
    required String petName,
    required int petLevel,
    required int dungeonIndex,
    required int floor,
    required int roomsDone,
    required Random rng,
    AdventureMods mods = AdventureMods.none,
    int petPrestige = 0,
  }) {
    final di = _clampInt(dungeonIndex, 0, Dungeons.all.length - 1);
    final dungeon = Dungeons.all[di];
    final f = _clampInt(floor, 1, dungeon.floors);
    final effLevel = petLevel + mods.atkBonus;

    // ── 보스 층 ──────────────────────────────────────────
    if (f >= dungeon.floors) {
      final boss = dungeon.boss;
      final win = rng.nextDouble() < winChance(effLevel, boss.level);
      if (win) {
        final mana = battleReward(boss, f);
        // 다음 던전 개방 or 같은 던전 재입장 (레벨 + 환생 조건)
        final nextIndex = di + 1;
        if (nextIndex < Dungeons.all.length &&
            petLevel >= Dungeons.all[nextIndex].minLevel &&
            petPrestige >= Dungeons.all[nextIndex].minPrestige) {
          return TickOutcome(
            message: '보스 ${boss.name} 격파! ${dungeon.name} 클리어!! '
                '(+$mana M) → 다음 목적지: ${Dungeons.all[nextIndex].name}',
            highlight: true,
            manaGained: mana,
            hungerGained: 0,
            dungeonIndex: nextIndex,
            floor: 1,
            roomsDone: 0,
          );
        }
        return TickOutcome(
          message: '보스 ${boss.name} 격파! ${dungeon.name} 클리어!! '
              '(+$mana M) 전리품을 챙겨 다시 1층부터.',
          highlight: true,
          manaGained: mana,
          hungerGained: 0,
          dungeonIndex: di,
          floor: 1,
          roomsDone: 0,
        );
      }
      if (rng.nextDouble() < mods.guardChance) {
        return TickOutcome(
          message: '보스 ${boss.name}에게 패했지만, 방패가 밀려남을 막아냈다! (제자리 사수)',
          highlight: false,
          manaGained: 0,
          hungerGained: 0,
          dungeonIndex: di,
          floor: f,
          roomsDone: 0,
        );
      }
      final retreat =
          _clampInt(f - Balance.bossLoseRetreatFloors, 1, dungeon.floors);
      return TickOutcome(
        message: '보스 ${boss.name}의 벽은 높았다… $retreat층으로 후퇴. (재도전!)',
        highlight: false,
        manaGained: 0,
        hungerGained: 0,
        dungeonIndex: di,
        floor: retreat,
        roomsDone: 0,
      );
    }

    // ── 일반 층: 룸 타입 추첨 ────────────────────────────
    final roll = rng.nextInt(100);
    String message;
    bool highlight = false;
    int mana = 0;
    double hunger = 0;
    String? itemGained;
    var newFloor = f;
    var newRooms = roomsDone;

    if (roll < Balance.roomWeightBattle) {
      // 전투
      final candidates = dungeon.monsters
          .where((m) => !m.isBoss && m.minFloor <= f)
          .toList();
      final monster = candidates[rng.nextInt(candidates.length)];
      final win = rng.nextDouble() < winChance(effLevel, monster.level);
      if (win) {
        final crit =
            rng.nextDouble() < (Balance.critChance + mods.critBonus);
        mana = battleReward(monster, f) * (crit ? 2 : 1);
        message = '${dungeon.name} $f층 — ${monster.name} 처치!'
            '${crit ? ' 치명타!' : ''} (+$mana M)';
        newRooms += 1;
      } else {
        if (rng.nextDouble() < mods.guardChance) {
          return TickOutcome(
            message: '${monster.name}에게 패했지만, 방패가 밀려남을 막아냈다!',
            highlight: false,
            manaGained: 0,
            hungerGained: 0,
            dungeonIndex: di,
            floor: f,
            roomsDone: roomsDone,
          );
        }
        newFloor = _clampInt(f - Balance.loseRetreatFloors, 1, dungeon.floors);
        newRooms = 0;
        return TickOutcome(
          message: '${monster.name}에게 밀려 $newFloor층으로 후퇴… 다음엔 이긴다.',
          highlight: false,
          manaGained: 0,
          hungerGained: 0,
          dungeonIndex: di,
          floor: newFloor,
          roomsDone: newRooms,
        );
      }
    } else if (roll < Balance.roomWeightBattle + Balance.roomWeightTreasure) {
      // 보물
      final rare =
          rng.nextDouble() < (Balance.rareTreasureChance + mods.rareBonus);
      mana = treasureReward(f, rare: false);
      if (rare) {
        // 희귀 전리품은 실제 아이템으로 가방에 들어간다 (Phase 5)
        itemGained =
            dungeon.lootItemIds[rng.nextInt(dungeon.lootItemIds.length)];
        final lootName = Items.byId(itemGained)?.name ?? itemGained;
        message = '희귀 전리품 [$lootName] 발견! 가방에 넣었다 (+$mana M)';
        highlight = true;
      } else {
        message = '${dungeon.name} $f층에서 보물 발견! (+$mana M)';
      }
      newRooms += 1;
    } else {
      // 휴식
      hunger = Balance.restHungerGain;
      message = '$petName이(가) 모닥불 곁에서 잠깐 쉬었다. '
          '(포만감 +${Balance.restHungerGain.toStringAsFixed(0)}%)';
      newRooms += 1;
    }

    // ── 층 돌파 판정 (암살자는 필요 룸 −1, 최소 2) ────────
    var required = roomsPerFloor(f) - mods.roomsReduction;
    if (required < 2) required = 2;
    if (newRooms >= required) {
      newFloor = f + 1;
      newRooms = 0;
      message = '$message — ${dungeon.name} $newFloor층 돌파!';
      highlight = true;
    }

    return TickOutcome(
      message: message,
      highlight: highlight,
      manaGained: mana,
      hungerGained: hunger,
      itemGained: itemGained,
      dungeonIndex: di,
      floor: newFloor,
      roomsDone: newRooms,
    );
  }
}
