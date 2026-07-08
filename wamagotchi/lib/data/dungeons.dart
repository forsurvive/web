/// 던전·몬스터 데이터 (Phase 3 — 게임 시스템 기획서 5.3/6.2의 P1 범위).
///
/// PC 폴클로어 세계관. 순수 Dart — 밸런스처럼 데이터만 담는다.
library;

class MonsterSpec {
  final String name;
  final int level;

  /// 이 층 이상에서 등장
  final int minFloor;
  final bool isBoss;

  const MonsterSpec(this.name, this.level, this.minFloor,
      {this.isBoss = false});
}

class Dungeon {
  final String name;

  /// 이 레벨 이상이어야 입장(개방)
  final int minLevel;

  /// 최상층 = 보스 층
  final int floors;

  final List<MonsterSpec> monsters;

  /// 보물 룸 희귀 전리품 이름 (연출용 — 인벤토리는 Phase 4)
  final List<String> lootNames;

  const Dungeon({
    required this.name,
    required this.minLevel,
    required this.floors,
    required this.monsters,
    required this.lootNames,
  });

  MonsterSpec get boss => monsters.firstWhere((m) => m.isBoss);
}

class Dungeons {
  Dungeons._();

  static const List<Dungeon> all = [
    Dungeon(
      name: '휴지통 던전',
      minLevel: 1,
      floors: 10,
      monsters: [
        MonsterSpec('오타 슬라임', 1, 1),
        MonsterSpec('자동완성 임프', 4, 4),
        MonsterSpec('구겨진 종이 골렘', 9, 10, isBoss: true),
      ],
      lootNames: ['빛나는 키캡', '구겨진 초고 뭉치'],
    ),
    Dungeon(
      name: '다운로드 폴더의 미궁',
      minLevel: 15,
      floors: 15,
      monsters: [
        MonsterSpec('캡스락 광전사', 16, 1),
        MonsterSpec('중복 파일 쌍둥이', 21, 15, isBoss: true),
      ],
      lootNames: ['수상한 압축파일 조각', '빛나는 키캡'],
    ),
    Dungeon(
      name: '캐시 파일의 늪',
      minLevel: 25,
      floors: 20,
      monsters: [
        MonsterSpec('광고 배트', 26, 1),
        MonsterSpec('무한 로딩 젤리', 30, 8),
        MonsterSpec('비대해진 캐시 슬라임', 33, 20, isBoss: true),
      ],
      lootNames: ['슬라임 잉크', '오래된 쿠키 파편'],
    ),
  ];
}
