/// 특수 키워드 감지 엔진 (Phase 4 — 게임 시스템 기획서 4.1).
///
/// "마지막으로 밥을 준 시점" 대비 키워드 등장 횟수가 늘었을 때만 발동한다.
/// (메모가 키워드별 기준 카운트를 저장 — 초안 자동 저장은 기준을 건드리지 않는다)
/// 순수 Dart — 테스트 가능.
library;

class KeywordCategory {
  final String id;
  final String label;
  final List<String> words;

  const KeywordCategory(this.id, this.label, this.words);
}

class KeywordHit {
  final KeywordCategory category;

  /// 늘어난 등장 횟수
  final int increase;

  const KeywordHit(this.category, this.increase);
}

class KeywordEngine {
  KeywordEngine._();

  /// 키워드 사전 — 데이터 파일 성격이라 여기서만 관리한다.
  static const List<KeywordCategory> categories = [
    KeywordCategory('achieve', '성취', ['완료', '해냈다', '성공', '끝냈다']),
    KeywordCategory('positive', '긍정', ['감사', '사랑', '행복', '좋았']),
    KeywordCategory('stress', '부정', ['스트레스', '힘들다', '힘들었', '지쳤']),
    KeywordCategory('bug', '오류', ['오류', '버그', '에러']),
    KeywordCategory('deadline', '마감', ['마감', '데드라인', '급하다']),
  ];

  static KeywordCategory? byId(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 문자열에서 [word]의 등장 횟수 (겹치지 않게)
  static int countOccurrences(String text, String word) {
    if (word.isEmpty) return 0;
    var count = 0;
    var index = 0;
    while (true) {
      index = text.indexOf(word, index);
      if (index < 0) break;
      count += 1;
      index += word.length;
    }
    return count;
  }

  /// 텍스트의 카테고리별 키워드 총 등장 횟수
  static Map<String, int> countsFor(String text) {
    final counts = <String, int>{};
    for (final c in categories) {
      var n = 0;
      for (final w in c.words) {
        n += countOccurrences(text, w);
      }
      if (n > 0) counts[c.id] = n;
    }
    return counts;
  }

  /// 이전 카운트 대비 "늘어난" 카테고리만 히트로 돌려준다.
  static List<KeywordHit> detect({
    required Map<String, int> oldCounts,
    required Map<String, int> newCounts,
  }) {
    final hits = <KeywordHit>[];
    for (final c in categories) {
      final before = oldCounts[c.id] ?? 0;
      final after = newCounts[c.id] ?? 0;
      if (after > before) {
        hits.add(KeywordHit(c, after - before));
      }
    }
    return hits;
  }
}
