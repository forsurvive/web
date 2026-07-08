/// 게임 규칙 계산 엔진.
///
/// Flutter에 의존하지 않는 순수 함수 모음이라 단위 테스트가 쉽다.
/// (test/game_engine_test.dart 에서 검증)
library;

import '../data/balance.dart';

/// 경험치 적용 결과
class ExpResult {
  final int level;
  final int exp;
  final int levelsGained;

  const ExpResult({
    required this.level,
    required this.exp,
    required this.levelsGained,
  });
}

class GameEngine {
  GameEngine._();

  /// 공백(스페이스·줄바꿈·탭)을 제외한 글자 수를 센다.
  static int countChars(String text) {
    return text.replaceAll(RegExp(r'\s'), '').length;
  }

  /// 이전 글자 수 대비 "새로 늘어난" 글자 수. 삭제(음수)는 벌점 없이 0으로 취급.
  static int gainedChars({required int before, required int after}) {
    final diff = after - before;
    return diff > 0 ? diff : 0;
  }

  /// 현재 레벨에서 다음 레벨까지 필요한 경험치: 50 + 12 × (Lv - 1)
  static int expToNext(int level) {
    return Balance.expCurveBase + Balance.expCurveSlope * (level - 1);
  }

  /// 경험치를 더하고 레벨업(연속 레벨업 포함)을 계산한다.
  static ExpResult applyExp({
    required int level,
    required int exp,
    required int gained,
  }) {
    var newLevel = level;
    var newExp = exp + gained;
    var ups = 0;

    while (newLevel < Balance.maxLevel && newExp >= expToNext(newLevel)) {
      newExp -= expToNext(newLevel);
      newLevel += 1;
      ups += 1;
    }
    if (newLevel >= Balance.maxLevel) {
      newLevel = Balance.maxLevel;
      newExp = 0; // 최대 레벨에서는 경험치를 멈춘다 (환생은 Phase 5)
    }
    return ExpResult(level: newLevel, exp: newExp, levelsGained: ups);
  }

  /// 저장 글자 수에 따른 포만감 회복량(%p). 오늘의 첫 저장은 2배.
  static double hungerGain(int chars, {required bool firstSaveOfDay}) {
    final base = chars / 100.0 * Balance.hungerGainPer100Chars;
    return firstSaveOfDay ? base * Balance.firstSaveOfDayMultiplier : base;
  }

  /// 경과 시간에 따른 포만감 자연 감소량(%p). 시간당 3%p를 분 단위로 비례 계산.
  static double hungerDecay(Duration elapsed) {
    if (elapsed.isNegative) return 0;
    return elapsed.inMinutes * (Balance.hungerDecayPerHour / 60.0);
  }

  /// 포만감을 0~100 범위로 자른다.
  static double clampHunger(double value) {
    if (value < Balance.hungerMin) return Balance.hungerMin;
    if (value > Balance.hungerMax) return Balance.hungerMax;
    return value;
  }

  /// 정령 이름 검증. 문제없으면 null, 문제 있으면 한국어 에러 메시지를 돌려준다.
  ///
  /// 규칙(시스템 기획서 1.1): 1~8자, 한글/영문/숫자, 중간 공백 1개 허용,
  /// 앞뒤 공백 제거, 금칙어 필터.
  static String? validateName(String raw) {
    final name = raw.trim();
    if (name.length < Balance.nameMinLength) {
      return '이름을 입력해 주세요.';
    }
    if (name.length > Balance.nameMaxLength) {
      return '이름은 ${Balance.nameMaxLength}자 이내로 지어 주세요.';
    }
    final pattern = RegExp(r'^[가-힣a-zA-Z0-9]+( [가-힣a-zA-Z0-9]+)?$');
    if (!pattern.hasMatch(name)) {
      return '한글, 영문, 숫자만 쓸 수 있어요. (공백은 중간에 1개까지)';
    }
    for (final banned in Balance.bannedNameWords) {
      if (name.contains(banned)) {
        return '그 이름은 쓸 수 없어요.';
      }
    }
    return null;
  }

  /// 날짜를 yyyy-MM-dd 문자열로 (오늘의 첫 저장 판정용)
  static String ymd(DateTime t) {
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '${t.year}-$m-$d';
  }
}
