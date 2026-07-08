import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/balance.dart';
import '../data/dungeons.dart';
import '../data/items.dart';
import '../logic/adventure_engine.dart';
import '../logic/game_engine.dart';
import '../logic/keyword_engine.dart';
import '../models/feed_result.dart';
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

  // ── 장비 (Phase 4) ─────────────────────────────────────
  ItemSpec? get weapon => Items.byId(_state.weaponId);
  ItemSpec? get armor => Items.byId(_state.armorId);
  ItemSpec? get accessory => Items.byId(_state.accessoryId);

  /// 장착 장비에서 오는 탐험 보정치
  AdventureMods get mods => AdventureMods(
        atkBonus: weapon?.atkBonus ?? 0,
        guardChance: armor?.guardChance ?? 0,
        critBonus: accessory?.critBonus ?? 0,
        rareBonus: accessory?.rareBonus ?? 0,
      );

  /// 보유 여부 (장착 중 포함)
  bool ownsItem(String id) {
    return (_state.inventory[id] ?? 0) > 0 ||
        _state.weaponId == id ||
        _state.armorId == id ||
        _state.accessoryId == id;
  }

  /// [성취의 기운] 버프가 있으면 마나에 배율 적용
  int _applyManaBuff(int mana) {
    if (mana <= 0 || !_state.buffActive) return mana;
    return (mana * Balance.buffManaMultiplier).round();
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
    if (_logs.isEmpty) {
      _addLog('알이 도착했다. 글을 쓰면 깨어난다…');
    }
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
    final decayPerChunk =
        Balance.tickMinutes * (Balance.hungerDecayPerHour / 60.0);
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
    );
    _state.mana += _applyManaBuff(outcome.manaGained);
    _state.hunger =
        GameEngine.clampHunger(_state.hunger + outcome.hungerGained);
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

    // 1) 재화·경험치
    final manaGained = _applyManaBuff(gainedChars * Balance.manaPerChar);
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

    // 2) 포만감
    final hungerGain =
        GameEngine.hungerGain(gainedChars, firstSaveOfDay: firstSaveOfDay);
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

    // 5) 탐험 재개 — 이 저장 덕분에 다시 출발했다면 알려서 동기를 북돋는다
    if (!wasExploring && _state.isExploring && !justHatched) {
      final message = '포만감 회복! ${_state.displayName}이(가) '
          '${dungeon.name} ${_state.floor}층에서 다시 탐험을 나선다!';
      _addLog(message);
      onHighlight?.call(message);
    }

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
        case 'stress':
          _state.inventory['stress_crystal'] =
              (_state.inventory['stress_crystal'] ?? 0) + 1;
          const message =
              '[스트레스 결정체] 획득! 고생이 보상이 된다 (가방에서 800 M에 판매)';
          _addLog(message);
          onHighlight?.call(message);
        case 'bug':
          final bounty = _applyManaBuff(Balance.bugBountyMana);
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
    if (item.isEquipment && ownsItem(id)) return '이미 갖고 있어요.';
    if (_state.mana < item.price) {
      return '마나가 부족해요. (${item.price - _state.mana} M 더 필요)';
    }

    _state.mana -= item.price;
    _state.inventory[id] = (_state.inventory[id] ?? 0) + 1;
    _addLog('[${item.name}] 구매! (−${item.price} M)');

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
    _state.hunger =
        GameEngine.clampHunger(_state.hunger + item.hungerRestore);
    _addLog('[${item.name}] 사용 — 포만감 '
        '+${item.hungerRestore.toStringAsFixed(0)}%');

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
