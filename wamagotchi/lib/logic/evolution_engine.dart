/// 작업 패턴 → 클래스 판정 엔진 (Phase 5 — 게임 시스템 기획서 2.2).
///
/// 순수 Dart. 최근 저장 통계(시각·글자 수)로 유저의 글쓰기 습관을 읽어
/// 정령의 클래스를 정한다. 판정 우선순위: 심야 > 아침 > 단문 > 장문 > 균형.
library;

import '../data/balance.dart';

/// 저장 1회의 통계 (판정 재료)
class SaveStat {
  final DateTime at;
  final int chars;

  const SaveStat(this.at, this.chars);

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'chars': chars,
      };

  factory SaveStat.fromJson(Map<String, dynamic> json) => SaveStat(
        DateTime.parse(json['at'] as String),
        (json['chars'] as num?)?.toInt() ?? 0,
      );
}

class EvolutionEngine {
  EvolutionEngine._();

  /// 최근 저장 통계로 클래스 id를 판정한다.
  static String judge(List<SaveStat> stats) {
    if (stats.isEmpty) return 'adventurer';

    final n = stats.length;
    var night = 0;
    var morning = 0;
    var longForm = 0;
    var totalChars = 0;

    for (final s in stats) {
      final h = s.at.hour;
      if (h >= 22 || h < 2) night += 1;
      if (h >= 5 && h < 9) morning += 1;
      if (s.chars >= Balance.classLongChars) longForm += 1;
      totalChars += s.chars;
    }
    final avg = totalChars / n;

    if (night / n >= Balance.classNightShare) return 'shadow_rogue';
    if (morning / n >= Balance.classMorningShare) return 'dawn_priest';
    if (avg < Balance.classShortAvgChars) return 'assassin';
    if (longForm / n >= Balance.classLongShare) return 'knight';
    return 'adventurer';
  }
}
