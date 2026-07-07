import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/balance.dart';
import '../logic/game_engine.dart';
import '../models/feed_result.dart';
import '../models/pet_state.dart';
import '../services/storage_service.dart';

/// 정령의 상태와 게임 규칙을 관장하는 뷰모델.
///
/// - feed(): 저장 시 늘어난 글자를 마나/경험치/포만감으로 정산
/// - 1분마다 포만감 자연 감소 정산
/// - 부화(이름 입력) 흐름 관리
class GameViewModel extends ChangeNotifier {
  final StorageService _storage;

  PetState _state = PetState();
  List<String> _logs = [];
  Timer? _decayTimer;

  GameViewModel(this._storage);

  PetState get state => _state;

  /// 최신 로그가 앞에 오는 목록
  List<String> get recentLogs => List.unmodifiable(_logs);

  int get expToNext => GameEngine.expToNext(_state.level);

  double get expProgress =>
      (_state.exp / GameEngine.expToNext(_state.level)).clamp(0.0, 1.0).toDouble();

  Future<void> load() async {
    _state = _storage.loadPetState();
    _logs = _storage.loadLogs();
    if (_logs.isEmpty) {
      _addLog('알이 도착했다. 글을 쓰면 깨어난다…');
    }
    applyTimeDecay();
    _decayTimer ??= Timer.periodic(
      const Duration(minutes: 1),
      (_) => applyTimeDecay(),
    );
    await _persist();
    notifyListeners();
  }

  /// 경과 시간만큼 포만감을 깎는다. (앱 시작·복귀·1분 타이머마다 호출)
  void applyTimeDecay() {
    final now = DateTime.now();
    final elapsed = now.difference(_state.lastHungerTickAt);
    if (elapsed.inMinutes < 1) return;

    final decay = GameEngine.hungerDecay(elapsed);
    final before = _state.hunger;
    _state.hunger = GameEngine.clampHunger(_state.hunger - decay);
    _state.lastHungerTickAt = now;

    if (before > Balance.hungerMin && _state.hunger <= Balance.hungerMin) {
      _addLog('${_state.displayName}이(가) 배가 고파 기절했다… 글을 쓰면 깨어난다.');
    }
    _persist();
    notifyListeners();
  }

  /// 저장(밥 주기) 정산. [gainedChars]는 "새로 늘어난 글자 수(공백 제외)".
  Future<FeedResult> feed(int gainedChars) async {
    applyTimeDecay();

    if (gainedChars <= 0) {
      return FeedResult.empty;
    }

    final now = DateTime.now();
    final today = GameEngine.ymd(now);
    final firstSaveOfDay = _state.lastSaveYmd != today;

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
    _decayTimer?.cancel();
    super.dispose();
  }
}
