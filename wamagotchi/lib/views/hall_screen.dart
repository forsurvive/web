import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/achievements.dart';
import '../data/palette.dart';
import '../viewmodels/game_viewmodel.dart';

/// 명예의 전당 — 역대 정령 기록 + 업적·칭호 (Phase 5).
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
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const _SectionHeader('🏆 역대 정령'),
          if (hall.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                '아직 은퇴한 정령이 없어요.\n'
                'Lv.100까지 함께 글을 쓰면 이곳에 훈장처럼 기록되고,\n'
                '다음 세대에게 힘을 물려줍니다. (첫 환생: 글자당 마나 ×1.5)',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Palette.muted, fontSize: 12.5, height: 1.7),
              ),
            )
          else
            for (final e in hall)
              Container(
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
                      style:
                          const TextStyle(fontSize: 12, color: Palette.muted),
                    ),
                    Text(
                      '마지막 위치: ${e.dungeonName} ${e.floor}층',
                      style:
                          const TextStyle(fontSize: 12, color: Palette.muted),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 14),
          const _SectionHeader('📜 업적 · 칭호'),
          for (final a in Achievements.all) _AchievementCard(spec: a),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Palette.muted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final AchievementSpec spec;

  const _AchievementCard({required this.spec});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameViewModel>();
    final earned = game.state.achievements.contains(spec.id);
    final title = Achievements.titleById(spec.titleId);
    final titleEquipped = title != null && game.state.titleId == title.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: Palette.surface,
        border: Border.all(
            color: earned ? Palette.accent : Palette.line,
            width: earned ? 1.4 : 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${earned ? '✓ ' : ''}${spec.name}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: earned ? Palette.ink : Palette.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${spec.desc} · 보상 ${spec.rewardMana} M'
                  '${title != null ? ' + 칭호 「${title.name}」' : ''}',
                  style:
                      const TextStyle(fontSize: 11.5, color: Palette.muted),
                ),
              ],
            ),
          ),
          if (title != null && earned)
            TextButton(
              onPressed: () async {
                final vm = context.read<GameViewModel>();
                await vm.setTitle(titleEquipped ? null : title.id);
              },
              child: Text(
                titleEquipped ? '해제' : '칭호 장착',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Palette.accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
