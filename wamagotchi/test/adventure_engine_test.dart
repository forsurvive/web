import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wamagotchi/data/balance.dart';
import 'package:wamagotchi/data/dungeons.dart';
import 'package:wamagotchi/logic/adventure_engine.dart';

void main() {
  group('층당 룸 수 (roomsPerFloor)', () {
    test('항상 3~5개', () {
      for (var f = 1; f <= 60; f++) {
        final rooms = AdventureEngine.roomsPerFloor(f);
        expect(rooms >= 3 && rooms <= 5, true, reason: 'floor $f → $rooms');
      }
    });

    test('결정적(플랫폼 간 동일해야 함)', () {
      expect(AdventureEngine.roomsPerFloor(1), 4); // 3 + (7 % 3)
      expect(AdventureEngine.roomsPerFloor(2), 5); // 3 + (14 % 3)
      expect(AdventureEngine.roomsPerFloor(3), 3); // 3 + (21 % 3)
    });
  });

  group('전투 승률 (winChance)', () {
    test('레벨 차이에 비례하고 상하한으로 클램프된다', () {
      expect(AdventureEngine.winChance(1, 1), Balance.winBase);
      expect(AdventureEngine.winChance(99, 1), Balance.winMax);
      expect(AdventureEngine.winChance(1, 99), Balance.winMin);
      expect(
        AdventureEngine.winChance(10, 5),
        closeTo(Balance.winBase + Balance.winPerLevelDiff * 5, 1e-9),
      );
    });
  });

  group('던전 데이터 무결성', () {
    test('모든 던전에 보스가 정확히 1마리, 1층 일반 몬스터가 존재한다', () {
      for (final d in Dungeons.all) {
        expect(d.monsters.where((m) => m.isBoss).length, 1,
            reason: d.name);
        expect(
          d.monsters.any((m) => !m.isBoss && m.minFloor <= 1),
          true,
          reason: '${d.name}: 1층에서 만날 일반 몬스터가 필요',
        );
        expect(d.lootNames.isNotEmpty, true, reason: d.name);
      }
    });

    test('개방 레벨은 오름차순', () {
      for (var i = 1; i < Dungeons.all.length; i++) {
        expect(
          Dungeons.all[i].minLevel > Dungeons.all[i - 1].minLevel,
          true,
        );
      }
    });
  });

  group('탐험 틱 (runTick) 불변식', () {
    test('500틱 동안 상태가 항상 유효 범위를 유지한다', () {
      final rng = Random(42);
      var dungeonIndex = 0, floor = 1, roomsDone = 0;
      var mana = 0;

      for (var i = 0; i < 500; i++) {
        final o = AdventureEngine.runTick(
          petName: '테스트',
          petLevel: 20,
          dungeonIndex: dungeonIndex,
          floor: floor,
          roomsDone: roomsDone,
          rng: rng,
        );
        dungeonIndex = o.dungeonIndex;
        floor = o.floor;
        roomsDone = o.roomsDone;
        mana += o.manaGained;

        expect(dungeonIndex >= 0 && dungeonIndex < Dungeons.all.length, true);
        final d = Dungeons.all[dungeonIndex];
        expect(floor >= 1 && floor <= d.floors, true,
            reason: 'tick $i: floor $floor');
        expect(roomsDone >= 0 && roomsDone < 5, true);
        expect(o.manaGained >= 0, true);
        expect(o.hungerGained >= 0, true);
        expect(o.message.isNotEmpty, true);
      }
      expect(mana > 0, true, reason: '500틱이면 마나를 벌었어야 한다');
    });

    test('고레벨 정령은 결국 첫 던전을 클리어하고 다음 던전으로 간다', () {
      final rng = Random(7);
      var dungeonIndex = 0, floor = 1, roomsDone = 0;

      var cleared = false;
      for (var i = 0; i < 3000 && !cleared; i++) {
        final o = AdventureEngine.runTick(
          petName: '테스트',
          petLevel: 99, // 승률 최대치
          dungeonIndex: dungeonIndex,
          floor: floor,
          roomsDone: roomsDone,
          rng: rng,
        );
        if (o.dungeonIndex != dungeonIndex) cleared = true;
        dungeonIndex = o.dungeonIndex;
        floor = o.floor;
        roomsDone = o.roomsDone;
      }
      expect(cleared, true, reason: '3000틱 안에 휴지통 던전을 클리어해야 한다');
      expect(dungeonIndex, 1);
      expect(floor, 1);
    });

    test('저레벨 정령은 개방 레벨이 안 되면 같은 던전을 다시 돈다', () {
      // 보스 층에서 반드시 이기는 상황을 만들기 위해 여러 시드를 시도
      for (var seed = 0; seed < 50; seed++) {
        final rng = Random(seed);
        final o = AdventureEngine.runTick(
          petName: '테스트',
          petLevel: 10, // 다음 던전(minLevel 15) 미달
          dungeonIndex: 0,
          floor: Dungeons.all[0].floors, // 보스 층
          roomsDone: 0,
          rng: rng,
        );
        if (o.manaGained > 0) {
          // 보스 승리 → 클리어했지만 같은 던전 1층부터
          expect(o.dungeonIndex, 0);
          expect(o.floor, 1);
          expect(o.highlight, true);
          return;
        }
      }
      fail('50개 시드 중 보스 승리가 한 번도 없을 수는 없다');
    });

    test('보스 패배 시 5층 후퇴', () {
      for (var seed = 0; seed < 200; seed++) {
        final rng = Random(seed);
        final o = AdventureEngine.runTick(
          petName: '테스트',
          petLevel: 1, // 승률 최저
          dungeonIndex: 0,
          floor: Dungeons.all[0].floors,
          roomsDone: 0,
          rng: rng,
        );
        if (o.manaGained == 0) {
          expect(
            o.floor,
            Dungeons.all[0].floors - Balance.bossLoseRetreatFloors,
          );
          return;
        }
      }
      fail('승률 최저인데 200개 시드 모두 보스에게 이길 수는 없다');
    });
  });
}
