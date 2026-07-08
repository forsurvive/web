/// 방치형 던전 탐험 엔진 (Phase 3).
///
/// 순수 로직 — Flutter에 의존하지 않고, Random을 주입받아 테스트 가능하다.
/// 틱 1회 = 룸 1개 진행. 결과는 [TickOutcome]으로 돌려주고 상태 반영은 뷰모델의 몫.
library;

import 'dart:math';

import '../data/balance.dart';
import '../data/dungeons.dart';

/// 탐험 틱 1회의 결과
class TickOutcome {
  final String message;

  /// 집필 동기를 북돋는 특별 이벤트 → 화면 하단 알림 대상
  final bool highlight;

  final int manaGained;
  final double hungerGained;

  // 틱 이후의 위치
  final int dungeonIndex;
  final int floor;
  final int roomsDone;

  const TickOutcome({
    required this.message,
    required this.highlight,
    required this.manaGained,
    required this.hungerGained,
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

  /// 탐험 틱 1회 실행.
  static TickOutcome runTick({
    required String petName,
    required int petLevel,
    required int dungeonIndex,
    required int floor,
    required int roomsDone,
    required Random rng,
  }) {
    final di = _clampInt(dungeonIndex, 0, Dungeons.all.length - 1);
    final dungeon = Dungeons.all[di];
    final f = _clampInt(floor, 1, dungeon.floors);

    // ── 보스 층 ──────────────────────────────────────────
    if (f >= dungeon.floors) {
      final boss = dungeon.boss;
      final win = rng.nextDouble() < winChance(petLevel, boss.level);
      if (win) {
        final mana = battleReward(boss, f);
        // 다음 던전 개방 or 같은 던전 재입장
        final nextIndex = di + 1;
        if (nextIndex < Dungeons.all.length &&
            petLevel >= Dungeons.all[nextIndex].minLevel) {
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
    var newFloor = f;
    var newRooms = roomsDone;

    if (roll < Balance.roomWeightBattle) {
      // 전투
      final candidates = dungeon.monsters
          .where((m) => !m.isBoss && m.minFloor <= f)
          .toList();
      final monster = candidates[rng.nextInt(candidates.length)];
      final win = rng.nextDouble() < winChance(petLevel, monster.level);
      if (win) {
        final crit = rng.nextDouble() < Balance.critChance;
        mana = battleReward(monster, f) * (crit ? 2 : 1);
        message = '${dungeon.name} $f층 — ${monster.name} 처치!'
            '${crit ? ' 치명타!' : ''} (+$mana M)';
        newRooms += 1;
      } else {
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
      final rare = rng.nextDouble() < Balance.rareTreasureChance;
      mana = treasureReward(f, rare: rare);
      if (rare) {
        final loot = dungeon.lootNames[rng.nextInt(dungeon.lootNames.length)];
        message = '희귀 전리품 [$loot] 발견! (+$mana M)';
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

    // ── 층 돌파 판정 ─────────────────────────────────────
    if (newRooms >= roomsPerFloor(f)) {
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
      dungeonIndex: di,
      floor: newFloor,
      roomsDone: newRooms,
    );
  }
}
