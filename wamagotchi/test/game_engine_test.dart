import 'package:flutter_test/flutter_test.dart';
import 'package:wamagotchi/data/balance.dart';
import 'package:wamagotchi/logic/game_engine.dart';

void main() {
  group('글자 수 계산 (countChars)', () {
    test('공백·줄바꿈·탭은 제외하고 센다', () {
      expect(GameEngine.countChars('안녕 하세요'), 5);
      expect(GameEngine.countChars('a b\nc\td'), 4);
      expect(GameEngine.countChars('   '), 0);
      expect(GameEngine.countChars(''), 0);
    });
  });

  group('늘어난 글자 계산 (gainedChars)', () {
    test('늘어난 만큼만 계산한다', () {
      expect(GameEngine.gainedChars(before: 100, after: 250), 150);
      expect(GameEngine.gainedChars(before: 0, after: 10), 10);
    });

    test('글을 지워도 벌점(음수)은 없다', () {
      expect(GameEngine.gainedChars(before: 100, after: 40), 0);
      expect(GameEngine.gainedChars(before: 100, after: 100), 0);
    });
  });

  group('레벨 곡선 (expToNext) — 시스템 기획서 10.1', () {
    test('필요 경험치 = 50 + 12 × (Lv - 1)', () {
      expect(GameEngine.expToNext(1), 50);
      expect(GameEngine.expToNext(2), 62);
      expect(GameEngine.expToNext(10), 158);
      expect(GameEngine.expToNext(30), 398);
      expect(GameEngine.expToNext(60), 758);
      expect(GameEngine.expToNext(99), 1226);
    });
  });

  group('경험치 적용과 레벨업 (applyExp)', () {
    test('경험치가 모자라면 레벨 유지', () {
      final r = GameEngine.applyExp(level: 1, exp: 0, gained: 49);
      expect(r.level, 1);
      expect(r.exp, 49);
      expect(r.levelsGained, 0);
    });

    test('딱 채우면 레벨업하고 나머지는 0', () {
      final r = GameEngine.applyExp(level: 1, exp: 0, gained: 50);
      expect(r.level, 2);
      expect(r.exp, 0);
      expect(r.levelsGained, 1);
    });

    test('큰 경험치는 연속 레벨업 처리 (초반 1,000자 시나리오)', () {
      // Lv.1에서 1,000 Exp: 50+62+74+86+98+110+122+134+146 = 882 → Lv.10, 잔여 118
      final r = GameEngine.applyExp(level: 1, exp: 0, gained: 1000);
      expect(r.level, 10);
      expect(r.exp, 118);
      expect(r.levelsGained, 9);
    });

    test('부화 레벨(Lv.5) 도달 시나리오 — 약 270자면 부화', () {
      // 50+62+74+86 = 272 Exp면 Lv.5
      final r = GameEngine.applyExp(level: 1, exp: 0, gained: 272);
      expect(r.level, 5);
      expect(r.level >= Balance.hatchLevel, true);
    });

    test('최대 레벨(100)을 넘지 않는다', () {
      final r = GameEngine.applyExp(level: 99, exp: 0, gained: 999999);
      expect(r.level, Balance.maxLevel);
      expect(r.exp, 0);
    });
  });

  group('포만감 (hungerGain / hungerDecay) — 시스템 기획서 3.1', () {
    test('100자당 +8%p', () {
      expect(GameEngine.hungerGain(100, firstSaveOfDay: false), 8.0);
      expect(GameEngine.hungerGain(50, firstSaveOfDay: false), 4.0);
      expect(GameEngine.hungerGain(1000, firstSaveOfDay: false), 80.0);
    });

    test('오늘의 첫 저장은 2배', () {
      expect(GameEngine.hungerGain(100, firstSaveOfDay: true), 16.0);
    });

    test('자연 감소: 시간당 3%p를 분 단위 비례 계산', () {
      expect(GameEngine.hungerDecay(const Duration(hours: 1)), closeTo(3.0, 1e-9));
      expect(GameEngine.hungerDecay(const Duration(hours: 24)), closeTo(72.0, 1e-9));
      expect(GameEngine.hungerDecay(const Duration(minutes: 20)), closeTo(1.0, 1e-9));
      expect(GameEngine.hungerDecay(Duration.zero), 0.0);
    });

    test('포만감은 0~100 사이로 잘린다', () {
      expect(GameEngine.clampHunger(150.0), 100.0);
      expect(GameEngine.clampHunger(-10.0), 0.0);
      expect(GameEngine.clampHunger(42.5), 42.5);
    });
  });

  group('정령 이름 검증 (validateName) — 시스템 기획서 1.1', () {
    test('올바른 이름은 통과 (null 반환)', () {
      expect(GameEngine.validateName('잉크'), null);
      expect(GameEngine.validateName('Momo'), null);
      expect(GameEngine.validateName('도트777'), null);
      expect(GameEngine.validateName('먹물 대장'), null); // 중간 공백 1개 허용
      expect(GameEngine.validateName('  픽셀  '), null); // 앞뒤 공백은 제거 후 검사
    });

    test('빈 이름·너무 긴 이름은 거부', () {
      expect(GameEngine.validateName(''), isNotNull);
      expect(GameEngine.validateName('   '), isNotNull);
      expect(GameEngine.validateName('아주아주긴이름이다'), isNotNull); // 9자
    });

    test('특수문자·공백 2개 이상은 거부', () {
      expect(GameEngine.validateName('잉크!'), isNotNull);
      expect(GameEngine.validateName('먹 물 이'), isNotNull);
      expect(GameEngine.validateName('a@b'), isNotNull);
    });

    test('금칙어는 거부', () {
      for (final banned in Balance.bannedNameWords) {
        expect(GameEngine.validateName(banned), isNotNull);
      }
    });
  });

  group('날짜 문자열 (ymd)', () {
    test('yyyy-MM-dd 형식', () {
      expect(GameEngine.ymd(DateTime(2026, 7, 7)), '2026-07-07');
      expect(GameEngine.ymd(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });
}
