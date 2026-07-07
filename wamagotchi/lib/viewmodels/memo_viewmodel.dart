import 'package:flutter/foundation.dart';

import '../logic/game_engine.dart';
import '../models/memo.dart';
import '../services/storage_service.dart';

/// 메모 목록과 저장을 담당하는 뷰모델.
///
/// saveMemo()는 "새로 늘어난 글자 수"를 돌려주고,
/// 그 값을 GameViewModel.feed()에 넘기는 것은 화면(View)의 몫이다.
class MemoViewModel extends ChangeNotifier {
  final StorageService _storage;

  List<Memo> _memos = [];

  MemoViewModel(this._storage);

  /// 최근 수정 순으로 정렬된 메모 목록
  List<Memo> get memos {
    final sorted = List<Memo>.from(_memos);
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(sorted);
  }

  Future<void> load() async {
    _memos = _storage.loadMemos();
    notifyListeners();
  }

  Memo? findById(String? id) {
    if (id == null) return null;
    for (final memo in _memos) {
      if (memo.id == id) return memo;
    }
    return null;
  }

  /// 메모를 저장(신규 또는 수정)하고 "새로 늘어난 글자 수(공백 제외)"를 반환한다.
  ///
  /// 반환값의 두 번째 요소는 저장된 메모(신규 생성 시 id 확인용).
  Future<(int, Memo)> saveMemo({
    String? id,
    required String title,
    required String body,
  }) async {
    final newCount = GameEngine.countChars(title) + GameEngine.countChars(body);

    Memo? memo = findById(id);
    int gained;

    if (memo == null) {
      memo = Memo(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        body: body,
        charCount: newCount,
      );
      _memos.add(memo);
      gained = GameEngine.gainedChars(before: 0, after: newCount);
    } else {
      gained = GameEngine.gainedChars(before: memo.charCount, after: newCount);
      memo.title = title;
      memo.body = body;
      memo.charCount = newCount;
      memo.updatedAt = DateTime.now();
    }

    await _storage.saveMemos(_memos);
    notifyListeners();
    return (gained, memo);
  }

  /// 메모 삭제. 정령에게 벌점은 없다 (기획서: 삭제 무벌점 원칙).
  Future<void> deleteMemo(String id) async {
    _memos.removeWhere((m) => m.id == id);
    await _storage.saveMemos(_memos);
    notifyListeners();
  }
}
