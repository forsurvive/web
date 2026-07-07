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
import 'widgets/pet_status_panel.dart';

/// 메인 화면: 상단 정령 상태창 + 하단 텍스트 에디터 (기획서 4.1 스플릿 뷰)
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

  void _updateLiveCharCount() {
    setState(() {
      _liveCharCount = GameEngine.countChars(_titleController.text) +
          GameEngine.countChars(_bodyController.text);
    });
  }

  /// 저장 = 정령에게 밥 주기 (기획서 핵심 트리거)
  Future<void> _save() async {
    final memoVM = context.read<MemoViewModel>();
    final gameVM = context.read<GameViewModel>();

    final title = _titleController.text;
    final body = _bodyController.text;

    if (title.trim().isEmpty && body.trim().isEmpty) {
      _showSnack('빈 메모는 저장할 수 없어요.');
      return;
    }

    final (gained, memo) =
        await memoVM.saveMemo(id: _editingMemoId, title: title, body: body);
    setState(() => _editingMemoId = memo.id);

    final result = await gameVM.feed(gained);

    if (result.gainedChars > 0) {
      _showSnack(
          '저장 완료! 마나 +${result.manaGained} · 경험치 +${result.expGained}');
    } else {
      _showSnack('저장 완료! (새로 늘어난 글자는 없어요)');
    }

    if (result.justHatched && mounted) {
      await _showNamingDialog();
    }
  }

  void _newMemo() {
    setState(() {
      _editingMemoId = null;
      _titleController.clear();
      _bodyController.clear();
      _liveCharCount = 0;
    });
  }

  Future<void> _openMemoList() async {
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
      });
      _updateLiveCharCount();
    } else if (_editingMemoId != null &&
        memoVM.findById(_editingMemoId) == null) {
      // 목록 화면에서 편집 중이던 메모를 삭제하고 돌아온 경우
      _newMemo();
    }
  }

  /// 부화한 정령의 이름을 유저가 직접 짓는 다이얼로그 (시스템 기획서 1.1)
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
              backgroundColor: Palette.lcdLight,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide(color: Palette.lcdDark, width: 3),
              ),
              title: const Text(
                '정령이 깨어났어요!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('이름을 지어 주세요. (1~8자)'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          autofocus: true,
                          maxLength: Balance.nameMaxLength,
                          decoration: InputDecoration(
                            hintText: '예: 잉크, 모모, 도트…',
                            errorText: errorText,
                            counterText: '',
                            enabledBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                  color: Palette.lcdDark, width: 2),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                  color: Palette.lcdDark, width: 2),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '이름 뽑기',
                        icon: const Icon(Icons.casino,
                            color: Palette.lcdDark),
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
                      color: Palette.lcdDark,
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

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WAMAGOTCHI',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        actions: [
          IconButton(
            tooltip: '새 메모',
            icon: const Icon(Icons.note_add_outlined),
            onPressed: _newMemo,
          ),
          IconButton(
            tooltip: '메모 목록',
            icon: const Icon(Icons.list),
            onPressed: _openMemoList,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 🅰️ 게임 영역: 키보드가 열리면 로그를 접어 화면을 아낀다
            PetStatusPanel(compact: keyboardOpen),
            // 🅱️ 생산성 영역: 텍스트 에디터
            Expanded(child: _buildEditor()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.save),
        label: const Text('저장', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Palette.lcdLight,
        border: Border.all(color: Palette.lcdDark, width: 3),
      ),
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            onChanged: (_) => _updateLiveCharCount(),
            style: const TextStyle(fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: '제목',
              border: InputBorder.none,
            ),
          ),
          Container(height: 2, color: Palette.lcdDark),
          Expanded(
            child: TextField(
              controller: _bodyController,
              onChanged: (_) => _updateLiveCharCount(),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: '이곳에 쓰는 모든 글자가 정령의 밥이 됩니다…',
                border: InputBorder.none,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Text(
                  _editingMemoId == null ? '새 메모' : '편집 중',
                  style: const TextStyle(fontSize: 11),
                ),
                const Spacer(),
                Text(
                  '현재 $_liveCharCount자 (공백 제외)',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
