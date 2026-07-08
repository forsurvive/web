import 'package:flutter_test/flutter_test.dart';
import 'package:wamagotchi/logic/keyword_engine.dart';

void main() {
  group('키워드 등장 횟수 (countOccurrences)', () {
    test('겹치지 않게 센다', () {
      expect(KeywordEngine.countOccurrences('완료 완료 완료', '완료'), 3);
      expect(KeywordEngine.countOccurrences('스트레스스트레스', '스트레스'), 2);
      expect(KeywordEngine.countOccurrences('없음', '완료'), 0);
      expect(KeywordEngine.countOccurrences('', '완료'), 0);
    });
  });

  group('카테고리별 카운트 (countsFor)', () {
    test('같은 카테고리의 여러 단어를 합산한다', () {
      final counts = KeywordEngine.countsFor('버그를 잡았다. 에러도 잡았다. 완료!');
      expect(counts['bug'], 2); // 버그 + 에러
      expect(counts['achieve'], 1); // 완료
      expect(counts.containsKey('stress'), false);
    });
  });

  group('신규 키워드 감지 (detect)', () {
    test('늘어난 카테고리만 히트', () {
      final oldCounts = KeywordEngine.countsFor('오늘은 힘들다.');
      final newCounts = KeywordEngine.countsFor('오늘은 힘들다. 그래도 완료했다!');
      final hits =
          KeywordEngine.detect(oldCounts: oldCounts, newCounts: newCounts);
      expect(hits.length, 1);
      expect(hits.first.category.id, 'achieve');
      expect(hits.first.increase, 1);
    });

    test('키워드를 지웠다가 다시 써도(횟수 동일) 발동하지 않는다', () {
      final a = KeywordEngine.countsFor('완료했다');
      final b = KeywordEngine.countsFor('오늘 일과를 완료');
      final hits = KeywordEngine.detect(oldCounts: a, newCounts: b);
      expect(hits, isEmpty);
    });

    test('여러 카테고리 동시 히트', () {
      final hits = KeywordEngine.detect(
        oldCounts: const {},
        newCounts: KeywordEngine.countsFor('마감이라 스트레스지만 감사하다'),
      );
      final ids = hits.map((h) => h.category.id).toSet();
      expect(ids, {'deadline', 'stress', 'positive'});
    });

    test('감소는 히트가 아니다', () {
      final hits = KeywordEngine.detect(
        oldCounts: KeywordEngine.countsFor('완료 완료'),
        newCounts: KeywordEngine.countsFor('완료'),
      );
      expect(hits, isEmpty);
    });
  });
}
