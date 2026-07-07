import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/memo.dart';
import '../models/pet_state.dart';

/// 로컬 저장소 입출력 담당.
///
/// Phase 1은 shared_preferences(JSON)로 충분하다. 메모가 많아지면
/// 이 클래스 내부만 Hive/sqflite로 교체하면 된다 (다른 코드는 수정 불필요).
class StorageService {
  static const _keyPetState = 'pet_state';
  static const _keyMemos = 'memos';
  static const _keyLogs = 'logs';

  final SharedPreferences _prefs;

  StorageService._(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService._(prefs);
  }

  // ── 정령 상태 ──────────────────────────────────────────────
  PetState loadPetState() {
    final raw = _prefs.getString(_keyPetState);
    if (raw == null) return PetState();
    try {
      return PetState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // 저장 데이터가 깨졌을 때: 앱이 죽는 대신 새 알에서 시작
      return PetState();
    }
  }

  Future<void> savePetState(PetState state) async {
    await _prefs.setString(_keyPetState, jsonEncode(state.toJson()));
  }

  // ── 메모 ──────────────────────────────────────────────────
  List<Memo> loadMemos() {
    final raw = _prefs.getString(_keyMemos);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Memo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveMemos(List<Memo> memos) async {
    final list = memos.map((m) => m.toJson()).toList();
    await _prefs.setString(_keyMemos, jsonEncode(list));
  }

  // ── 로그 ──────────────────────────────────────────────────
  List<String> loadLogs() {
    return _prefs.getStringList(_keyLogs) ?? [];
  }

  Future<void> saveLogs(List<String> logs) async {
    await _prefs.setStringList(_keyLogs, logs);
  }
}
