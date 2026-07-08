/// 업적·칭호 데이터 (Phase 5 2차 — 게임 시스템 기획서 8.3/8.4).
///
/// 달성 조건 판정은 GameViewModel._checkAchievements()가 id로 분기한다.
library;

class AchievementSpec {
  final String id;
  final String name;
  final String desc;

  /// 달성 보상 마나
  final int rewardMana;

  /// 달성 시 얻는 칭호 (없으면 null)
  final String? titleId;

  const AchievementSpec({
    required this.id,
    required this.name,
    required this.desc,
    this.rewardMana = 0,
    this.titleId,
  });
}

class TitleSpec {
  final String id;
  final String name;

  const TitleSpec(this.id, this.name);
}

class Achievements {
  Achievements._();

  static const List<AchievementSpec> all = [
    AchievementSpec(
        id: 'first_save',
        name: '첫 문장',
        desc: '처음으로 글을 저장했다',
        rewardMana: 100),
    AchievementSpec(
        id: 'hatch',
        name: '탄생의 목격자',
        desc: '알을 부화시켰다',
        rewardMana: 200),
    AchievementSpec(
        id: 'chars_10k',
        name: '만 자의 각오',
        desc: '누적 10,000자를 썼다',
        rewardMana: 1000),
    AchievementSpec(
        id: 'chars_100k',
        name: '십만 자의 필력',
        desc: '누적 100,000자를 썼다',
        rewardMana: 3000,
        titleId: 'scribe'),
    AchievementSpec(
        id: 'chars_1m',
        name: '백만 문자의 전설',
        desc: '누적 1,000,000자를 썼다',
        rewardMana: 10000,
        titleId: 'million_legend'),
    AchievementSpec(
        id: 'streak_7',
        name: '일주일의 불씨',
        desc: '7일 연속 글을 썼다',
        rewardMana: 500),
    AchievementSpec(
        id: 'streak_30',
        name: '한 달의 불꽃',
        desc: '30일 연속 글을 썼다',
        rewardMana: 2000,
        titleId: 'month_flame'),
    AchievementSpec(
        id: 'class_awaken',
        name: '패턴의 각성',
        desc: '클래스로 각성했다',
        rewardMana: 300),
    AchievementSpec(
        id: 'bond_5',
        name: '단짝',
        desc: '친밀도 Lv.5에 도달했다',
        rewardMana: 500),
    AchievementSpec(
        id: 'prestige_1',
        name: '세대의 시작',
        desc: '첫 환생을 이뤘다',
        rewardMana: 1000,
        titleId: 'generation_start'),
  ];

  static const List<TitleSpec> titles = [
    TitleSpec('scribe', '필경사'),
    TitleSpec('million_legend', '백만 문자의 전설'),
    TitleSpec('month_flame', '한 달의 불꽃'),
    TitleSpec('generation_start', '세대의 시작'),
  ];

  static AchievementSpec? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  static TitleSpec? titleById(String? id) {
    if (id == null) return null;
    for (final t in titles) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// 정령의 부탁 (일일 마이크로 퀘스트 — 시스템 기획서 3.3)
class QuestSpec {
  final String id;
  final String desc;

  /// 목표치 (chars: 글자 수 / pats: 쓰다듬기 횟수 / keyword: 1회)
  final int target;

  const QuestSpec(this.id, this.desc, this.target);
}

class Quests {
  Quests._();

  static const List<QuestSpec> all = [
    QuestSpec('q_chars', '오늘 300자만 더 써 줘!', 300),
    QuestSpec('q_pats', '오늘은 나를 3번 쓰다듬어 줘…', 3),
    QuestSpec('q_positive', "'감사'나 '행복' 같은 따뜻한 말을 한 번만 써 줘", 1),
  ];

  /// 날짜로 오늘의 부탁을 고른다 (결정적 — 플랫폼 간 동일)
  static QuestSpec forDay(DateTime day) {
    final index = (day.year * 372 + day.month * 31 + day.day) % all.length;
    return all[index];
  }

  static QuestSpec? byId(String? id) {
    if (id == null) return null;
    for (final q in all) {
      if (q.id == id) return q;
    }
    return null;
  }
}
