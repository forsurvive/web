import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/palette.dart';
import '../models/memo.dart';
import '../viewmodels/memo_viewmodel.dart';

/// 작성한 메모 목록. 탭하면 해당 메모를 에디터로 불러온다.
class MemoListScreen extends StatefulWidget {
  const MemoListScreen({super.key});

  @override
  State<MemoListScreen> createState() => _MemoListScreenState();
}

class _MemoListScreenState extends State<MemoListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime t) {
    final mm = t.month.toString().padLeft(2, '0');
    final dd = t.day.toString().padLeft(2, '0');
    return '${t.year}.$mm.$dd';
  }

  Future<void> _confirmDelete(BuildContext context, Memo memo) async {
    final memoVM = context.read<MemoViewModel>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Palette.line),
        ),
        title: const Text('메모 삭제',
            style: TextStyle(color: Palette.ink, fontSize: 17)),
        content: Text(
          "'${memo.displayTitle}' 메모를 삭제할까요?\n"
          '(정령이 이미 먹은 마나와 경험치는 그대로 남아요)',
          style: const TextStyle(fontSize: 13.5, color: Palette.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소', style: TextStyle(color: Palette.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              '삭제',
              style: TextStyle(
                color: Palette.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await memoVM.deleteMemo(memo.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final memos = context.watch<MemoViewModel>().memos.where((m) {
      if (query.isEmpty) return true;
      return '${m.title} ${m.body}'.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '메모 목록',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Palette.ink,
          ),
        ),
        backgroundColor: Palette.paper,
        foregroundColor: Palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 13.5, color: Palette.ink),
              decoration: InputDecoration(
                hintText: '메모 검색…',
                hintStyle: const TextStyle(color: Palette.muted),
                isDense: true,
                filled: true,
                fillColor: Palette.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Palette.line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Palette.accent),
                ),
              ),
            ),
          ),
          Expanded(
            child: memos.isEmpty
                ? Center(
                    child: Text(
                      query.isEmpty
                          ? '아직 메모가 없어요.\n첫 글을 쓰면 알이 깨어나기 시작합니다!'
                          : '검색 결과가 없어요.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Palette.muted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: memos.length,
                    itemBuilder: (context, index) {
                      final memo = memos[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Palette.surface,
                          border: Border.all(color: Palette.line),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          dense: true,
                          title: Text(
                            memo.displayTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Palette.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_formatDate(memo.updatedAt)} · ${memo.charCount}자',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Palette.muted,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: '삭제',
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Palette.muted,
                            ),
                            onPressed: () => _confirmDelete(context, memo),
                          ),
                          onTap: () => Navigator.of(context).pop(memo),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
