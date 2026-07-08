import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/palette.dart';
import '../viewmodels/game_viewmodel.dart';

/// 명예의 전당 — 은퇴한 역대 정령들의 기록 (Phase 5).
class HallScreen extends StatelessWidget {
  const HallScreen({super.key});

  String _formatDate(DateTime t) {
    final mm = t.month.toString().padLeft(2, '0');
    final dd = t.day.toString().padLeft(2, '0');
    return '${t.year}.$mm.$dd';
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameViewModel>();
    final hall = game.hall;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '명예의 전당',
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
      body: hall.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '아직 은퇴한 정령이 없어요.\n\n'
                  'Lv.100까지 함께 글을 쓰면, 정령은 이곳에\n'
                  '훈장처럼 기록되고 다음 세대에게 힘을 물려줍니다.\n'
                  '(첫 환생: 글자당 마나 ×1.5)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Palette.muted, fontSize: 13, height: 1.7),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: hall.length,
              itemBuilder: (context, index) {
                final e = hall[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Palette.surface,
                    border: Border.all(color: Palette.line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '🏆 ${e.generation}세대',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Palette.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Palette.ink,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatDate(e.retiredAt),
                            style: const TextStyle(
                                fontSize: 11, color: Palette.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lv.100 ${e.className} · 함께 쓴 글 ${e.chars}자 · '
                        '${e.days}일의 여정',
                        style: const TextStyle(
                            fontSize: 12, color: Palette.muted),
                      ),
                      Text(
                        '마지막 위치: ${e.dungeonName} ${e.floor}층',
                        style: const TextStyle(
                            fontSize: 12, color: Palette.muted),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
