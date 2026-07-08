import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/balance.dart';
import '../data/dungeons.dart';
import '../logic/adventure_engine.dart';
import '../logic/game_engine.dart';
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
        final outcome = AdventureEngine.runTick(
          petName: _state.displayName,
          petLevel: _state.level,
          dungeonIndex: _state.dungeonIndex,
          floor: _state.floor,
          roomsDone: _state.roomsDone,
          rng: _rng,
        );
        _state.mana += outcome.manaGained;
        _state.hunger =
            GameEngine.clampHunger(_state.hunger + outcome.hungerGained);
        _state.dungeonIndex = outcome.dungeonIndex;
        _state.floor = outcome.floor;
        _state.roomsDone = outcome.roomsDone;
        _addLog(outcome.message);
        if (outcome.highlight) highlights.add(outcome.message);
      }
    }

    _state.lastHungerTickAt = _state.lastHungerTickAt
        .add(Duration(minutes: chunks * Balance.tickMinutes));

    _deliverHighlights(highlights);
    _persist();
    notifyListeners();
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
  Future<FeedResult> feed(int gainedChars) async {
    settle();

    if (gainedChars <= 0) {
      return FeedResult.empty;
    }

    final now = DateTime.now();
    final today = GameEngine.ymd(now);
    final firstSaveOfDay = _state.lastSaveYmd != today;
    final wasExploring = _state.isExploring;

    // 1) 재화·경험치
    final manaGained = gainedChars * Balance.manaPerChar;
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
    _addLog('+$gainedChars자 기록 → 마나 +$manaGained · 경험치 +$expGained');
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
