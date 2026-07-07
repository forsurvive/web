import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/balance.dart';
import '../data/palette.dart';
import '../logic/game_engine.dart';
import '../models/memo.dart';
import '../viewmodels/game_viewmodel.dart';
import '../viewmodels/memo_viewmodel.dart';
import 'memo_list_screen.dart';
import 'widgets/pet_status_bar.dart';

/// 메인 화면 — v2 "라이팅 퍼스트".
///
/// 에디터가 화면의 주인공이다. 게임은 상단의 슬림 정령 칩 하나로 물러나고,
/// 상세(게이지·로그)는 칩을 탭했을 때 시트로 열린다.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  /// 지금 편집 중인 메모의 id (null이면 새 메모)
  String? _editingMemoId;

  /// 에디터에 현재 입력된 글자 수 (공백 제외, 실시간 표시용)
  int _liveCharCount = 0;

  /// 초안 자동 저장 디바운스
  Timer? _draftTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 앱을 껐다 켰을 때: 부화했지만 아직 이름이 없는 정령이 있으면 이름을 물어본다
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final game = context.read<GameViewModel>();
      if (game.state.needsNaming) {
        _showNamingDialog();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드에 있다가 돌아오면 그동안의 포만감 감소를 정산
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<GameViewModel>().applyTimeDecay();
    }
  }

  // ── 입력 · 초안 자동 저장 ────────────────────────────────

  void _onChanged() {
    setState(() {
      _liveCharCount = GameEngine.countChars(_titleController.text) +
          GameEngine.countChars(_bodyController.text);
    });
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 800), _saveDraft);
  }

  /// 초안 자동 저장: 글 내용만 보존한다. (charCount는 건드리지 않아
  /// "저장 시 늘어난 글자" 정산은 그대로 유지된다 — 밥 주기는 저장 버튼의 몫)
  Future<void> _saveDraft() async {
    if (!mounted) return;
    final title = _titleController.text;
    final body = _bodyController.text;
    if (_editingMemoId == null && title.trim().isEmpty && body.trim().isEmpty) {
      return;
    }
    final memo = await context
        .read<MemoViewModel>()
        .saveDraft(id: _editingMemoId, title: title, body: body);
    if (mounted && _editingMemoId == null) {
      setState(() => _editingMemoId = memo.id);
    }
  }

  // ── 저장 = 정령에게 밥 주기 ──────────────────────────────

  Future<void> _save() async {
    final memoVM = context.read<MemoViewModel>();
    final gameVM = context.read<GameViewModel>();

    final title = _titleController.text;
    final body = _bodyController.text;

    if (title.trim().isEmpty && body.trim().isEmpty) {
      _showSnack('빈 메모는 저장할 수 없어요.');
      return;
    }

    _draftTimer?.cancel();
    final (gained, memo) =
        await memoVM.saveMemo(id: _editingMemoId, title: title, body: body);
    setState(() => _editingMemoId = memo.id);

    final result = await gameVM.feed(gained);

    if (result.levelsGained > 0) {
      _showSnack('저장 +${result.gainedChars}자 · 레벨 업! '
          'Lv.${gameVM.state.level}');
    } else if (result.gainedChars > 0) {
      _showSnack('저장했어요. 마나 +${result.manaGained} · '
          '경험치 +${result.expGained}');
    } else {
      _showSnack('저장했어요. (새로 늘어난 글자는 없어요)');
    }

    if (result.justHatched && mounted) {
      await _showNamingDialog();
    }
  }

  void _newMemo() {
    _draftTimer?.cancel();
    setState(() {
      _editingMemoId = null;
      _titleController.clear();
      _bodyController.clear();
      _liveCharCount = 0;
    });
  }

  Future<void> _openMemoList() async {
    _draftTimer?.cancel();
    await _saveDraft();
    if (!mounted) return;

    final selected = await Navigator.of(context).push<Memo>(
      MaterialPageRoute(builder: (_) => const MemoListScreen()),
    );

    if (!mounted) return;
    final memoVM = context.read<MemoViewModel>();

    if (selected != null) {
      setState(() {
        _editingMemoId = selected.id;
        _titleController.text = selected.title;
        _bodyController.text = selected.body;
        _liveCharCount = GameEngine.countChars(selected.title) +
            GameEngine.countChars(selected.body);
      });
    } else if (_editingMemoId != null &&
        memoVM.findById(_editingMemoId) == null) {
      // 목록 화면에서 편집 중이던 메모를 삭제하고 돌아온 경우
      _newMemo();
    }
  }

  // ── 이름 짓기 (부화 이벤트) ──────────────────────────────

  Future<void> _showNamingDialog() async {
    final gameVM = context.read<GameViewModel>();
    final nameController = TextEditingController();
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Palette.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Palette.line),
              ),
              title: const Text(
                '정령이 깨어났어요!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Palette.ink,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '글이 쌓여 알이 부화했어요.\n이름을 지어 주세요. (1~8자)',
                    style: TextStyle(fontSize: 13, color: Palette.muted),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          autofocus: true,
                          maxLength: Balance.nameMaxLength,
                          style: const TextStyle(color: Palette.ink),
                          decoration: InputDecoration(
                            hintText: '예: 잉크, 모모, 도트…',
                            errorText: errorText,
                            counterText: '',
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Palette.line),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Palette.accent),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '이름 뽑기',
                        icon: const Icon(Icons.casino, color: Palette.accent),
                        onPressed: () {
                          final names = Balance.nameSuggestions;
                          nameController.text =
                              names[Random().nextInt(names.length)];
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final error = await gameVM.setName(nameController.text);
                    if (error != null) {
                      setDialogState(() => errorText = error);
                    } else if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text(
                    '결정!',
                    style: TextStyle(
                      color: Palette.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (mounted && context.read<GameViewModel>().state.name != null) {
      _showSnack('정령의 이름은 이제부터 '
          "'${context.read<GameViewModel>().state.name}'!");
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ));
  }

  // ── 레이아웃 ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 상단 한 줄: 정령 칩 + 액션 (게임은 여기까지만)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 0),
              child: Row(
                children: [
                  const Expanded(child: PetStatusBar()),
                  IconButton(
                    tooltip: '새 메모',
                    icon: const Icon(Icons.note_add_outlined,
                        color: Palette.muted),
                    onPressed: _newMemo,
                  ),
                  IconButton(
                    tooltip: '메모 목록',
                    icon: const Icon(Icons.list, color: Palette.muted),
                    onPressed: _openMemoList,
                  ),
                ],
              ),
            ),
            // 에디터: 화면의 나머지 전부
            Expanded(child: _buildEditor()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.save_outlined),
        label: const Text('저장', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEditor() {
    final savedCount = context
            .watch<MemoViewModel>()
            .findById(_editingMemoId)
            ?.charCount ??
        0;
    final gainPreview = GameEngine.gainedChars(
      before: savedCount,
      after: _liveCharCount,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Palette.surface,
        border: Border.all(color: Palette.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            onChanged: (_) => _onChanged(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: Palette.ink,
            ),
            decoration: const InputDecoration(
              hintText: '제목',
              border: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: Palette.line,
          ),
          Expanded(
            child: TextField(
              controller: _bodyController,
              onChanged: (_) => _onChanged(),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontSize: 15.5,
                height: 1.7,
                color: Palette.ink,
              ),
              decoration: const InputDecoration(
                hintText: '쓰고 싶은 것을 쓰세요. 저장하면 그만큼 정령의 밥이 됩니다.',
                border: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(16, 12, 16, 12),
              ),
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: Palette.line,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                Text(
                  _editingMemoId == null ? '새 메모' : '자동 저장됨',
                  style: const TextStyle(fontSize: 11, color: Palette.muted),
                ),
                const Spacer(),
                if (gainPreview > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '저장하면 +$gainPreview자',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Palette.accent,
                      ),
                    ),
                  ),
                Text(
                  '$_liveCharCount자',
                  style: const TextStyle(fontSize: 11, color: Palette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
