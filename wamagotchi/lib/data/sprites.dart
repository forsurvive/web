/// 레벨에 따른 정령 스프라이트 매핑 (기획서 1.4 성장 단계).
///
/// 실제 PNG는 Higgsfield로 생성해 `assets/sprites/`에 넣는다.
/// 파일이 아직 없어도 앱은 동작한다 (PetSprite 위젯이 텍스트 얼굴로 대체 표시).
library;

class SpriteStage {
  final String key;
  final String asset;
  final int minLevel;
  final String label;

  const SpriteStage(this.key, this.asset, this.minLevel, this.label);
}

class Sprites {
  Sprites._();

  /// minLevel 오름차순. forLevel()이 "현재 레벨 이하의 마지막 단계"를 고른다.
  static const List<SpriteStage> stages = [
    SpriteStage('egg', 'assets/sprites/egg.png', 1, '알'),
    SpriteStage('hatchling', 'assets/sprites/hatchling.png', 5, '유년기'),
    SpriteStage('grown', 'assets/sprites/grown.png', 15, '1차 성장'),
    SpriteStage('evolved', 'assets/sprites/evolved.png', 30, '2차 진화'),
    // 향후: Lv.60 3차 전직, Lv.90 각성 스프라이트 추가
  ];

  static SpriteStage forLevel(int level) {
    var current = stages.first;
    for (final s in stages) {
      if (level >= s.minLevel) current = s;
    }
    return current;
  }
}
