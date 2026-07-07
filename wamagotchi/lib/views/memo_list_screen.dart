import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/palette.dart';
import '../models/memo.dart';
import '../viewmodels/memo_viewmodel.dart';

/// 작성한 메모 목록. 탭하면 해당 메모를 에디터로 불러온다.
class MemoListScreen extends StatelessWidget {
  const MemoListScreen({super.key});

  String _formatDate(DateTime t) {
    final mm = t.month.toString().padLeft(2, '0');
    final dd = t.day.toString().padLeft(2, '0');
    final hh = t.hour.toString().padLeft(2, '0');
    final mi = t.minute.toString().padLeft(2, '0');
    return '${t.year}.$mm.$dd $hh:$mi';
  }

  Future<void> _confirmDelete(BuildContext context, Memo memo) async {
    final memoVM = context.read<MemoViewModel>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Palette.lcdLight,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: Palette.lcdDark, width: 3),
        ),
        title: const Text('메모 삭제'),
        content: Text("'${memo.displayTitle}' 메모를 삭제할까요?\n"
            '(정령이 이미 먹은 마나와 경험치는 그대로 남아요)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소',
                style: TextStyle(color: Palette.lcdDark)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제',
                style: TextStyle(
                    color: Palette.lcdDark, fontWeight: FontWeight.bold)),
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
    final memos = context.watch<MemoViewModel>().memos;

    return Scaffold(
      appBar: AppBar(title: const Text('메모 목록')),
      body: memos.isEmpty
          ? const Center(
              child: Text(
                '아직 메모가 없어요.\n첫 글을 쓰면 알이 깨어나기 시작합니다!',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: memos.length,
              itemBuilder: (context, index) {
                final memo = memos[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Palette.lcdLight,
                    border: Border.all(color: Palette.lcdDark, width: 2),
                  ),
                  child: ListTile(
                    title: Text(
                      memo.displayTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${_formatDate(memo.updatedAt)} · ${memo.charCount}자',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      tooltip: '삭제',
                      icon: const Icon(Icons.delete_outline,
                          color: Palette.lcdDark),
                      onPressed: () => _confirmDelete(context, memo),
                    ),
                    onTap: () => Navigator.of(context).pop(memo),
                  ),
                );
              },
            ),
    );
  }
}
