import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/achievements.dart';
import '../data/balance.dart';
import '../data/classes.dart';
import '../data/dungeons.dart';
import '../data/items.dart';
import '../logic/adventure_engine.dart';
import '../logic/evolution_engine.dart';
import '../logic/game_engine.dart';
import '../logic/keyword_engine.dart';
import '../models/feed_result.dart';
import '../models/hall_entry.dart';
import '../models/pet_state.dart';
import '../services/storage_service.dart';

/// 정령의 상태와 게임 규칙을 관장하는 뷰모델.
///
/// - feed(): 저장 시 늘어난 글자를 마나/경험치/포만감으로 정산
/// - settle(): 경과 시간을 5분 틱으로 쪼개 포만감 감소 + 던전 탐험을 정산 (Phase 3)
/// - 특별한 이벤트(층 돌파·보스 격파·희귀 전리품 등)는 [onHighlight]로
///   화면 하단 알림에 전달된다
class GameViewModel extends ChangeNotifier {
  final StorageService _storage;
  final Random _rng;

  PetState _state = PetState();
  List<String> _logs = [];
  List<HallEntry> _hall = [];
  Timer? _timer;

  /// 집필 동기를 북돋는 특별 로그가 발생하면 호출된다 (화면이 하단 알림 표시).
  void Function(String message)? onHighlight;

  /// 화면이 뜨기 전(앱 시작 정산)에 발생한 하이라이트 요약 — 화면이 가져간다.
  String? _pendingHighlight;

  GameViewModel(this._storage, {Random? rng}) : _rng = rng ?? Random();

  PetState get state => _state;

  List<String> get recentLogs => List.unmodifiable(_logs);

  int get expToNext => GameEngine.expToNext(_state.level);

  double get expProgress =>
      (_state.exp / GameEngine.expToNext(_state.level))
          .clamp(0.0, 1.0)
          .toDouble();

  /// 현재 던전
  Dungeon get dungeon {
    var i = _state.dungeonIndex;
    if (i < 0) i = 0;
    if (i >= Dungeons.all.length) i = Dungeons.all.length - 1;
    return Dungeons.all[i];
  }

  // ── 장비·클래스 (Phase 4~5) ────────────────────────────
  ItemSpec? get weapon => Items.byId(_state.weaponId);
  ItemSpec? get armor => Items.byId(_state.armorId);
  ItemSpec? get accessory => Items.byId(_state.accessoryId);

  /// 확정된 클래스 (Lv.30 미만이면 null)
  ClassSpec? get classSpec => Classes.byId(_state.classId);

  /// 명예의 전당 (최신순)
  List<HallEntry> get hall => List.unmodifiable(_hall);

  /// 장착 장비 + 클래스에서 오는 탐험 보정치
  AdventureMods get mods => AdventureMods(
        atkBonus: weapon?.atkBonus ?? 0,
        guardChance:
            (armor?.guardChance ?? 0) + (classSpec?.guardBonus ?? 0),
        critBonus:
            (accessory?.critBonus ?? 0) + (classSpec?.critBonus ?? 0),
        rareBonus: accessory?.rareBonus ?? 0,
        roomsReduction: classSpec?.roomsReduction ?? 0,
      );

  /// 보유 여부 (장착 중 포함)
  bool ownsItem(String id) {
    return (_state.inventory[id] ?? 0) > 0 ||
        _state.weaponId == id ||
        _state.armorId == id ||
        _state.accessoryId == id;
  }

  /// 마나 배율 적용: 클래스·장신구 배율 + 성취 버프.
  /// [writing]이 true면 환생 배율(글자당 마나)도 곱한다.
  int _scaleMana(int base, {bool writing = false}) {
    if (base <= 0) return base;
    var mult = 1.0 +
        (classSpec?.manaRate ?? 0) +
        (accessory?.manaRate ?? 0);
    if (writing) mult *= _state.prestigeManaMult;
    if (_state.buffActive) mult *= Balance.buffManaMultiplier;
    return (base * mult).round();
  }

  /// 앱 시작 정산에서 쌓인 하이라이트를 1회 가져간다 (없으면 null)
  String? takePendingHighlight() {
    final message = _pendingHighlight;
    _pendingHighlight = null;
    return message;
  }

  Future<void> load() async {
    _state = _storage.loadPetState();
    _logs = _storage.loadLogs();
    _hall = _storage.loadHall();
    if (_logs.isEmpty) {
      _addLog('알이 도착했다. 글을 쓰면 깨어난다…');
    }
    _maybeWriteLetter();
    settle();
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) => settle());
    await _persist();
    notifyListeners();
  }

  /// 경과 시간을 5분 단위 틱으로 정산: 포만감 자연 감소 + 던전 탐험 진행.
  /// (앱 시작·복귀·1분 타이머·저장 직전마다 호출)
  void settle() {
    final now = DateTime.now();
    final elapsedMinutes = now.difference(_state.lastHungerTickAt).inMinutes;
    final chunks = elapsedMinutes ~/ Balance.tickMinutes;
    if (chunks <= 0) return;

    final highlights = <String>[];
    // 자동 먹이통(특수 아이템) 보유 시 자연 감소 저감
    final feeder = Items.byId('auto_feeder');
    final decayFactor =
        ownsItem('auto_feeder') ? 1.0 - (feeder?.decayReduction ?? 0) : 1.0;
    final decayPerChunk =
        Balance.tickMinutes * (Balance.hungerDecayPerHour / 60.0) * decayFactor;
    var adventureTicks = 0;

    for (var i = 0; i < chunks; i++) {
      final before = _state.hunger;
      _state.hunger = GameEngine.clampHunger(_state.hunger - decayPerChunk);

      if (before > Balance.hungerMin &&
          _state.hunger <= Balance.hungerMin) {
        _addLog('${_state.displayName}이(가) 배가 고파 잠들었다… 글을 쓰면 깨어난다.');
      } else if (before >= Balance.exploreHungerThreshold &&
          _state.hunger < Balance.exploreHungerThreshold &&
          !_state.isEgg) {
        const message = '배가 고파 탐험을 멈췄다. 한 줄만 쓰면 다시 출발!';
        _addLog(message);
        highlights.add(message);
      }

      // 알은 탐험하지 않는다. 포만감이 충분할 때만 룸 진행.
      if (_state.isExploring && adventureTicks < Balance.offlineCapTicks) {
        adventureTicks += 1;
        final outcome = _runAdventureTick();
        if (outcome.highlight) highlights.add(outcome.message);
      }
    }

    _state.lastHungerTickAt = _state.lastHungerTickAt
        .add(Duration(minutes: chunks * Balance.tickMinutes));

    _deliverHighlights(highlights);
    _persist();
    notifyListeners();
  }

  /// 탐험 틱 1회 실행 + 상태 반영 + 로그. (settle과 '마감' 키워드가 공용)
  TickOutcome _runAdventureTick() {
    final outcome = AdventureEngine.runTick(
      petName: _state.displayName,
      petLevel: _state.level,
      dungeonIndex: _state.dungeonIndex,
      floor: _state.floor,
      roomsDone: _state.roomsDone,
      rng: _rng,
      mods: mods,
      petPrestige: _state.prestigeCount,
    );
    _state.mana += _scaleMana(outcome.manaGained);
    _state.hunger =
        GameEngine.clampHunger(_state.hunger + outcome.hungerGained);
    if (outcome.itemGained != null) {
      _state.inventory[outcome.itemGained!] =
          (_state.inventory[outcome.itemGained!] ?? 0) + 1;
    }
    _state.dungeonIndex = outcome.dungeonIndex;
    _state.floor = outcome.floor;
    _state.roomsDone = outcome.roomsDone;
    _addLog(outcome.message);
    return outcome;
  }

  void _deliverHighlights(List<String> highlights) {
    if (highlights.isEmpty) return;
    final message = highlights.length == 1
        ? highlights.first
        : '부재중 모험 보고 ${highlights.length}건 — ${highlights.last}';
    if (onHighlight != null) {
      onHighlight!(message);
    } else {
      _pendingHighlight = message;
    }
  }

  /// 저장(밥 주기) 정산. [gainedChars]는 "새로 늘어난 글자 수(공백 제외)".
  /// [keywordHits]는 이번 저장에서 새로 추가된 키워드 (Phase 4).
  Future<FeedResult> feed(
    int gainedChars, {
    List<KeywordHit> keywordHits = const [],
  }) async {
    settle();

    final now = DateTime.now();
    final today = GameEngine.ymd(now);

    // 0) 키워드 이벤트 — 버프(성취)는 이번 저장의 마나에도 적용되도록 먼저 처리
    _processKeywords(keywordHits, today);

    if (gainedChars <= 0) {
      await _persist();
      notifyListeners();
      return FeedResult.empty;
    }

    final firstSaveOfDay = _state.lastSaveYmd != today;
    final wasExploring = _state.isExploring;

    // 부탁·스트릭·친밀도 (Phase 5 2차)
    _ensureQuest(today);
    if (firstSaveOfDay) {
      final yesterday =
          GameEngine.ymd(now.subtract(const Duration(days: 1)));
      _state.streak = _state.lastSaveYmd == yesterday ? _state.streak + 1 : 1;
      if (_state.streak > _state.streakBest) {
        _state.streakBest = _state.streak;
      }
      final streakReward = Balance.streakManaRewards[_state.streak];
      if (streakReward != null) {
        _state.mana += streakReward;
        final message = '🔥 ${_state.streak}일 연속 기록! (+$streakReward M)';
        _addLog(message);
        onHighlight?.call(message);
      } else if (_state.streak > 1) {
        _addLog('🔥 ${_state.streak}일 연속 기록 중!');
      }
      _addBond(Balance.bondFirstSave);
    }
    _questProgress('q_chars', gainedChars);

    // 클래스 판정용 저장 통계 기록 (Phase 5)
    _state.saveStats.add(SaveStat(now, gainedChars));
    if (_state.saveStats.length > Balance.classStatsWindow) {
      _state.saveStats.removeRange(
          0, _state.saveStats.length - Balance.classStatsWindow);
    }

    // 1) 재화·경험치 (환생 배율은 글쓰기 마나에만)
    final manaGained =
        _scaleMana(gainedChars * Balance.manaPerChar, writing: true);
    final expGained = gainedChars * Balance.expPerChar;
    final wasEgg = _state.isEgg;

    _state.mana += manaGained;
    _state.totalChars += gainedChars;

    final expResult = GameEngine.applyExp(
      level: _state.level,
      exp: _state.exp,
      gained: expGained,
    );
    _state.level = expResult.level;
    _state.exp = expResult.exp;

    // 2) 포만감 (여명 사제는 회복 +15%)
    final hungerGain =
        GameEngine.hungerGain(gainedChars, firstSaveOfDay: firstSaveOfDay) *
            (1 + (classSpec?.hungerGainRate ?? 0));
    _state.hunger = GameEngine.clampHunger(_state.hunger + hungerGain);
    _state.lastSaveYmd = today;

    // 3) 로그
    _addLog('+$gainedChars자 기록 → 마나 +$manaGained · 경험치 +$expGained'
        '${_state.buffActive ? ' (성취의 기운!)' : ''}');
    if (firstSaveOfDay) {
      _addLog('오늘의 첫 끼니! 포만감 회복 2배 (+${hungerGain.toStringAsFixed(0)}%)');
    }
    if (expResult.levelsGained > 0) {
      _addLog('레벨 업! Lv.${_state.level} 달성!');
    }

    // 4) 부화 판정 (이름은 유저가 짓는다)
    final justHatched = wasEgg && !_state.isEgg && _state.name == null;
    if (justHatched) {
      _addLog('알이 흔들리더니… 작은 정령이 깨어났다!');
    }

    // 4.5) 클래스 진화 판정 — Lv.30 도달 시 작업 패턴으로 확정 (Phase 5)
    if (_state.level >= Balance.classLevel &&
        _state.classId == null &&
        !_state.isEgg) {
      final judged = EvolutionEngine.judge(_state.saveStats);
      _state.classId = judged;
      final spec = Classes.byId(judged)!;
      final message = '패턴 분석 완료! ${_state.displayName}은(는) '
          '[${spec.name}](으)로 각성했다! — ${spec.desc}';
      _addLog(message);
      onHighlight?.call(message);
    }

    // 5) 탐험 재개 — 이 저장 덕분에 다시 출발했다면 알려서 동기를 북돋는다
    if (!wasExploring && _state.isExploring && !justHatched) {
      final message = '포만감 회복! ${_state.displayName}이(가) '
          '${dungeon.name} ${_state.floor}층에서 다시 탐험을 나선다!';
      _addLog(message);
      onHighlight?.call(message);
    }

    // 6) 업적 판정 (Phase 5 2차)
    _checkAchievements();

    await _persist();
    notifyListeners();

    return FeedResult(
      gainedChars: gainedChars,
      manaGained: manaGained,
      expGained: expGained,
      levelsGained: expResult.levelsGained,
      justHatched: justHatched,
    );
  }

  // ── 친밀도·부탁·스트릭·업적·편지 (Phase 5 2차) ──────────────

  /// 친밀도 추가 (+레벨업 하이라이트)
  void _addBond(int amount) {
    final beforeLevel = _state.bondLevel;
    _state.bond += amount;
    if (_state.bondLevel > beforeLevel) {
      final message = '친밀도 Lv.${_state.bondLevel} 달성 — '
          "이제 '${_state.bondLabel}' 사이!";
      _addLog(message);
      onHighlight?.call(message);
    }
  }

  /// 오늘의 부탁이 없으면 발급한다
  void _ensureQuest(String today) {
    if (_state.questYmd == today) return;
    final quest = Quests.forDay(DateTime.now());
    _state.questYmd = today;
    _state.questId = quest.id;
    _state.questProgress = 0;
    _state.questDone = false;
    if (!_state.isEgg) {
      _addLog('오늘의 부탁 — ${_state.displayName}: "${quest.desc}"');
    }
  }

  /// 부탁 진행. [questId]가 현재 부탁과 일치할 때만 반영.
  void _questProgress(String questId, int amount) {
    if (_state.questDone || _state.questId != questId) return;
    final quest = Quests.byId(questId);
    if (quest == null) return;
    _state.questProgress += amount;
    if (_state.questProgress >= quest.target) {
      _state.questDone = true;
      _addBond(Balance.bondQuest);
      _state.inventory['snack'] = (_state.inventory['snack'] ?? 0) + 1;
      final message = '부탁 완료! ${_state.displayName}이(가) 기뻐하며 '
          '[간식]을 물어다 줬다 (친밀도 +${Balance.bondQuest})';
      _addLog(message);
      onHighlight?.call(message);
    }
  }

  /// 쓰다듬기. UI에 보여줄 반응 대사를 돌려준다.
  Future<String> pat() async {
    final today = GameEngine.ymd(DateTime.now());
    _ensureQuest(today);
    if (_state.patYmd != today) {
      _state.patYmd = today;
      _state.patsToday = 0;
    }

    String reaction;
    if (_state.isEgg) {
      reaction = '알이 따뜻해졌다… 안에서 작게 톡, 소리가 났다.';
      _addLog(reaction);
    } else if (_state.patsToday >= Balance.bondPatDailyCap) {
      reaction = '${_state.displayName}이(가) 간지럽다는 듯 웃는다. (오늘은 충분해요!)';
    } else {
      _state.patsToday += 1;
      _addBond(Balance.bondPat);
      const reactions = [
        '기분 좋게 몸을 흔든다!',
        '포근하게 눈을 감는다…',
        '하트가 뿅 떠올랐다!',
        '당신의 손에 머리를 비빈다.',
      ];
      reaction = '${_state.displayName}이(가) '
          '${reactions[(_state.patsToday - 1) % reactions.length]} '
          '(친밀도 +${Balance.bondPat})';
      _addLog(reaction);
      _questProgress('q_pats', 1);
    }

    _checkAchievements();
    await _persist();
    notifyListeners();
    return reaction;
  }

  /// 보유한 칭호 목록 (달성한 업적이 부여한 것)
  List<TitleSpec> get ownedTitles {
    final owned = <TitleSpec>[];
    for (final a in Achievements.all) {
      if (a.titleId != null && _state.achievements.contains(a.id)) {
        final t = Achievements.titleById(a.titleId);
        if (t != null) owned.add(t);
      }
    }
    return owned;
  }

  /// 칭호 장착 (null이면 해제). 성공하면 null.
  Future<String?> setTitle(String? titleId) async {
    if (titleId != null && !ownedTitles.any((t) => t.id == titleId)) {
      return '아직 얻지 못한 칭호예요.';
    }
    _state.titleId = titleId;
    if (titleId != null) {
      _addLog('칭호 「${Achievements.titleById(titleId)!.name}」 장착!');
    }
    await _persist();
    notifyListeners();
    return null;
  }

  /// 업적 일괄 판정 (멱등 — 새로 달성한 것만 보상)
  void _checkAchievements() {
    for (final a in Achievements.all) {
      if (_state.achievements.contains(a.id)) continue;
      final met = switch (a.id) {
        'first_save' => _state.totalChars > 0,
        'hatch' => !_state.isEgg,
        'chars_10k' => _state.totalChars >= 10000,
        'chars_100k' => _state.totalChars >= 100000,
        'chars_1m' => _state.totalChars >= 1000000,
        'streak_7' => _state.streakBest >= 7,
        'streak_30' => _state.streakBest >= 30,
        'class_awaken' => _state.classId != null,
        'bond_5' => _state.bondLevel >= 5,
        'prestige_1' => _state.prestigeCount >= 1,
        _ => false,
      };
      if (!met) continue;
      _state.achievements.add(a.id);
      _state.mana += a.rewardMana;
      final title = Achievements.titleById(a.titleId);
      final message = '업적 달성! [${a.name}] (+${a.rewardMana} M'
          '${title != null ? ' · 칭호 「${title.name}」 획득' : ''})';
      _addLog(message);
      onHighlight?.call(message);
    }
  }

  /// 주가 바뀌었으면 정령의 편지를 쓴다 (앱 시작 시 호출)
  void _maybeWriteLetter() {
    final week =
        DateTime.now().millisecondsSinceEpoch ~/ 86400000 ~/ 7;
    if (_state.letterWeek == 0) {
      // 최초 실행: 이번 주를 기준점으로만 잡는다
      _state.letterWeek = week;
      return;
    }
    if (week <= _state.letterWeek || _state.isEgg) return;

    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    var chars7 = 0;
    final hourBands = <String, int>{};
    for (final s in _state.saveStats) {
      if (s.at.isBefore(cutoff)) continue;
      chars7 += s.chars;
      final h = s.at.hour;
      final band = h >= 22 || h < 5
          ? '밤'
          : h < 11
              ? '아침'
              : h < 17
                  ? '낮'
                  : '저녁';
      hourBands[band] = (hourBands[band] ?? 0) + 1;
    }
    String favBand = '낮';
    var best = -1;
    hourBands.forEach((band, count) {
      if (count > best) {
        best = count;
        favBand = band;
      }
    });

    _state.lastLetter = chars7 > 0
        ? '작가님께.\n\n지난주에 글을 $chars7자나 주셔서 배가 아주 든든했어요. '
            '특히 $favBand에 쓴 글이 제일 고소했어요.\n'
            '덕분에 지금은 ${dungeon.name} ${_state.floor}층까지 왔답니다.\n'
            '이번 주의 글도 기다릴게요.\n\n— ${_state.displayName} 올림'
        : '작가님께.\n\n지난주에는 글이 조금 그리웠어요… '
            '괜찮아요, 바쁜 날도 있는 거니까요.\n'
            '오늘 한 줄이면 저는 충분히 행복해요.\n\n— ${_state.displayName} 올림';
    _state.letterWeek = week;

    const notice = '📮 정령의 편지가 도착했어요 — 정령 패널에서 읽어 보세요';
    _addLog(notice);
    _deliverHighlights([notice]);
  }

  // ── 키워드 이벤트 (Phase 4 — 시스템 기획서 4.1) ─────────────

  /// 일일 상한을 확인·차감한다. 발동 가능하면 true.
  bool _kwAllow(String categoryId, String today) {
    if (_state.kwYmd != today) {
      _state.kwYmd = today;
      _state.kwUsed = {};
    }
    final used = _state.kwUsed[categoryId] ?? 0;
    if (used >= Balance.keywordDailyCap) return false;
    _state.kwUsed[categoryId] = used + 1;
    return true;
  }

  void _processKeywords(List<KeywordHit> hits, String today) {
    for (final hit in hits) {
      if (!_kwAllow(hit.category.id, today)) continue;

      switch (hit.category.id) {
        case 'achieve':
          _state.buffManaUntil = DateTime.now()
              .add(const Duration(minutes: Balance.buffManaDurationMinutes));
          const message =
              '키워드 [성취] 감지 — 성취의 기운 발동! 1시간 동안 마나 +20%';
          _addLog(message);
          onHighlight?.call(message);
        case 'positive':
          _state.hunger = GameEngine.clampHunger(
              _state.hunger + Balance.keywordHungerGain);
          _addLog('따뜻한 말의 힘! ${_state.displayName}의 포만감 '
              '+${Balance.keywordHungerGain.toStringAsFixed(0)}%');
          _questProgress('q_positive', 1);
        case 'stress':
          _state.inventory['stress_crystal'] =
              (_state.inventory['stress_crystal'] ?? 0) + 1;
          const message =
              '[스트레스 결정체] 획득! 고생이 보상이 된다 (가방에서 800 M에 판매)';
          _addLog(message);
          onHighlight?.call(message);
        case 'bug':
          final bounty = _scaleMana(Balance.bugBountyMana);
          _state.mana += bounty;
          final message = "'오류'의 기운에 이끌려 버그 벌레 출현! "
              '${_state.displayName}이(가) 처치 (+$bounty M)';
          _addLog(message);
          onHighlight?.call(message);
        case 'deadline':
          if (_state.isExploring) {
            final message =
                '마감의 기운! ${_state.displayName}이(가) 서둘러 전진한다!';
            _addLog(message);
            onHighlight?.call(message);
            for (var i = 0; i < Balance.deadlineBonusTicks; i++) {
              final outcome = _runAdventureTick();
              if (outcome.highlight) onHighlight?.call(outcome.message);
            }
          } else {
            _addLog('마감의 기운이 감돌지만, 정령은 아직 출발할 수 없다…');
          }
      }
    }
  }

  // ── 상점·인벤토리 (Phase 4 — 시스템 기획서 7장) ─────────────

  /// 구매. 성공하면 null, 실패하면 에러 메시지.
  Future<String?> buyItem(String id) async {
    final item = Items.byId(id);
    if (item == null || !item.isBuyable) return '살 수 없는 물건이에요.';
    if (_state.level < item.minLevel) {
      return '레벨이 부족해요. (Lv.${item.minLevel} 필요)';
    }
    if (item.isUnique && ownsItem(id)) return '이미 갖고 있어요.';
    if (_state.mana < item.price) {
      return '마나가 부족해요. (${item.price - _state.mana} M 더 필요)';
    }

    _state.mana -= item.price;
    _state.inventory[id] = (_state.inventory[id] ?? 0) + 1;
    _addLog('[${item.name}] 구매! (−${item.price} M)'
        '${item.type == ItemType.special ? ' — 영구 적용!' : ''}');

    // 빈 슬롯이면 바로 장착해 준다
    if (item.isEquipment) {
      final slotEmpty = switch (item.type) {
        ItemType.weapon => _state.weaponId == null,
        ItemType.armor => _state.armorId == null,
        ItemType.accessory => _state.accessoryId == null,
        _ => false,
      };
      if (slotEmpty) await equipItem(id);
    }

    await _persist();
    notifyListeners();
    return null;
  }

  /// 장착. 기존 장비는 가방으로 돌아간다.
  Future<String?> equipItem(String id) async {
    final item = Items.byId(id);
    if (item == null || !item.isEquipment) return '장착할 수 없는 물건이에요.';
    if (_state.level < item.minLevel) {
      return '레벨이 부족해요. (Lv.${item.minLevel} 필요)';
    }
    if ((_state.inventory[id] ?? 0) <= 0) return '가방에 없는 장비예요.';

    _state.inventory[id] = (_state.inventory[id] ?? 1) - 1;
    if ((_state.inventory[id] ?? 0) <= 0) _state.inventory.remove(id);

    String? previous;
    switch (item.type) {
      case ItemType.weapon:
        previous = _state.weaponId;
        _state.weaponId = id;
      case ItemType.armor:
        previous = _state.armorId;
        _state.armorId = id;
      case ItemType.accessory:
        previous = _state.accessoryId;
        _state.accessoryId = id;
      default:
        break;
    }
    if (previous != null) {
      _state.inventory[previous] = (_state.inventory[previous] ?? 0) + 1;
    }

    _addLog('[${item.name}] 장착! ${item.desc}');
    await _persist();
    notifyListeners();
    return null;
  }

  /// 소모품 사용. 성공하면 null.
  Future<String?> useItem(String id) async {
    final item = Items.byId(id);
    if (item == null || item.type != ItemType.consumable) {
      return '사용할 수 없는 물건이에요.';
    }
    if ((_state.inventory[id] ?? 0) <= 0) return '가방에 없어요.';

    final wasExploring = _state.isExploring;
    _state.inventory[id] = (_state.inventory[id] ?? 1) - 1;
    if ((_state.inventory[id] ?? 0) <= 0) _state.inventory.remove(id);

    if (item.hungerRestore > 0) {
      _state.hunger =
          GameEngine.clampHunger(_state.hunger + item.hungerRestore);
      _addLog('[${item.name}] 사용 — 포만감 '
          '+${item.hungerRestore.toStringAsFixed(0)}%');
    }

    // 간식은 교감의 뜻 (친밀도 +2)
    if (item.id == 'snack') {
      _addBond(Balance.bondSnack);
      _checkAchievements();
    }

    // 카페인 물약: 즉시 탐험 전진 (Phase 5)
    if (item.bonusTicks > 0) {
      if (_state.isExploring) {
        final message = '[${item.name}] 사용 — 번쩍! '
            '${_state.displayName}이(가) 서둘러 전진한다!';
        _addLog(message);
        onHighlight?.call(message);
        for (var i = 0; i < item.bonusTicks; i++) {
          final outcome = _runAdventureTick();
          if (outcome.highlight) onHighlight?.call(outcome.message);
        }
      } else {
        _addLog('[${item.name}] 사용 — 하지만 정령은 아직 출발할 수 없다…');
      }
    }

    if (!wasExploring && _state.isExploring) {
      final message = '${_state.displayName}이(가) 기운을 차리고 '
          '${dungeon.name} ${_state.floor}층에서 다시 탐험을 나선다!';
      _addLog(message);
      onHighlight?.call(message);
    }

    await _persist();
    notifyListeners();
    return null;
  }

  // ── 환생 (Phase 5 — 시스템 기획서 9장) ──────────────────

  /// Lv.100 정령을 은퇴시키고 새로운 알로 세대교체한다.
  /// 성공하면 null, 불가하면 에러 메시지.
  Future<String?> retire() async {
    if (_state.level < Balance.maxLevel) {
      return 'Lv.${Balance.maxLevel}에 도달해야 은퇴할 수 있어요.';
    }

    final now = DateTime.now();
    final entry = HallEntry(
      generation: _state.prestigeCount + 1,
      name: _state.name ?? '이름 없는 정령',
      className: classSpec?.name ?? '모험가',
      chars: _state.totalChars - _state.lifeStartTotalChars,
      days: now.difference(_state.lifeStartAt).inDays + 1,
      dungeonName: dungeon.name,
      floor: _state.floor,
      retiredAt: now,
    );
    _hall.insert(0, entry);
    await _storage.saveHall(_hall);

    final farewell = "'${entry.name}'이(가) 명예의 전당에 올랐다! "
        '(${entry.generation}세대 · 함께 쓴 ${entry.chars}자)';
    _addLog(farewell);
    onHighlight?.call(farewell);

    // 세대교체: 마나·장비·가방·전당은 유지, 성장은 처음부터
    _state.prestigeCount += 1;
    _state.name = null;
    _state.level = 1;
    _state.exp = 0;
    _state.hunger = Balance.hungerMax;
    _state.classId = null;
    _state.saveStats = [];
    _state.dungeonIndex = 0;
    _state.floor = 1;
    _state.roomsDone = 0;
    _state.buffManaUntil = null;
    _state.lifeStartTotalChars = _state.totalChars;
    _state.lifeStartAt = now;
    // 교감은 정령별 — 새 정령과 처음부터 (스트릭·업적·칭호는 작가의 자산이라 유지)
    _state.bond = 0;
    _state.patYmd = null;
    _state.patsToday = 0;
    _state.questYmd = null;
    _state.questId = null;
    _state.questProgress = 0;
    _state.questDone = false;

    _addLog('새로운 알이 도착했다. 이제 글자당 마나 '
        '×${_state.prestigeManaMult.toStringAsFixed(2)}!');

    _checkAchievements(); // prestige_1
    await _persist();
    notifyListeners();
    return null;
  }

  /// 재료 판매. 성공하면 null.
  Future<String?> sellItem(String id) async {
    final item = Items.byId(id);
    if (item == null || item.sellPrice <= 0) return '팔 수 없는 물건이에요.';
    if ((_state.inventory[id] ?? 0) <= 0) return '가방에 없어요.';

    _state.inventory[id] = (_state.inventory[id] ?? 1) - 1;
    if ((_state.inventory[id] ?? 0) <= 0) _state.inventory.remove(id);
    _state.mana += item.sellPrice;
    _addLog('[${item.name}] 판매 (+${item.sellPrice} M)');

    await _persist();
    notifyListeners();
    return null;
  }

  /// 부화한 정령에게 이름을 지어 준다. 성공하면 null, 실패하면 에러 메시지 반환.
  Future<String?> setName(String raw) async {
    final error = GameEngine.validateName(raw);
    if (error != null) return error;

    _state.name = raw.trim();
    _addLog("정령 '${_state.name}' 탄생! 앞으로 잘 부탁해요.");
    await _persist();
    notifyListeners();
    return null;
  }

  void _addLog(String message) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    _logs.insert(0, '$hh:$mm | $message');
    if (_logs.length > Balance.maxLogLines) {
      _logs = _logs.sublist(0, Balance.maxLogLines);
    }
  }

  Future<void> _persist() async {
    await _storage.savePetState(_state);
    await _storage.saveLogs(_logs);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
