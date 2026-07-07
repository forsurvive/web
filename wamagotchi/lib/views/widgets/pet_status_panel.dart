import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/palette.dart';
import '../../viewmodels/game_viewmodel.dart';

/// 상단 정령 상태창 (기획서 4.1 🅰️ 영역).
///
/// [compact]가 true면 로그를 숨긴다 (키보드가 올라왔을 때 화면 절약).
class PetStatusPanel extends StatelessWidget {
  final bool compact;

  const PetStatusPanel({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameViewModel>();
    final pet = game.state;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.lcdLight,
        // 기획서 6.1: 두꺼운 실선 테두리, 각진 모서리
        border: Border.all(color: Palette.lcdDark, width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                pet.face,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${pet.displayName}  Lv.${pet.level}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '상태: ${pet.moodLabel}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _GaugeBar(
            label: 'EXP',
            value: game.expProgress,
            valueText: '${pet.exp}/${game.expToNext}',
          ),
          const SizedBox(height: 6),
          _GaugeBar(
            label: '포만감',
            value: pet.hunger / 100.0,
            valueText: '${pet.hunger.toStringAsFixed(0)}%',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '마나 ${pet.mana} M',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '누적 ${pet.totalChars}자',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            Container(height: 2, color: Palette.lcdDark),
            const SizedBox(height: 6),
            ...game.recentLogs.take(3).map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '> $log',
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _GaugeBar extends StatelessWidget {
  final String label;
  final double value;
  final String valueText;

  const _GaugeBar({
    required this.label,
    required this.value,
    required this.valueText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0).toDouble(),
            minHeight: 12,
            backgroundColor: Palette.lcdMid,
            color: Palette.lcdDark,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            valueText,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
