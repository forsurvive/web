import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/balance.dart';
import '../../data/palette.dart';
import '../../data/sprites.dart';
import '../../viewmodels/game_viewmodel.dart';
import 'pet_sprite.dart';

/// 슬림 정령 칩 (v2 라이팅 퍼스트 UI).
///
/// 화면 상단에서 최소한의 자리만 차지한다: 스프라이트 타일 + 이름/레벨/마나 +
/// 초미니 게이지 2줄. 탭하면 상세 시트([PetDetailSheet])가 열린다.
class PetStatusBar extends StatelessWidget {
  const PetStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameViewModel>();
    final pet = game.state;
    final fainted = pet.hunger <= Balance.hungerMin;

    return Material(
      color: Palette.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showPetDetailSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: Palette.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Palette.tile,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: PetSprite(
                  level: pet.level,
                  asciiFace: pet.face,
                  size: 28,
                  dim: fainted,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.displayName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Palette.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Lv.${pet.level} · 마나 ${pet.mana} M',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 52,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MiniBar(value: game.expProgress),
                    const SizedBox(height: 3),
                    _MiniBar(value: pet.hunger / 100.0),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final double value;

  const _MiniBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0).toDouble(),
        minHeight: 4,
        backgroundColor: Palette.track,
        color: Palette.accent,
      ),
    );
  }
}

/// 정령 상세 시트 열기
void showPetDetailSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const PetDetailSheet(),
  );
}

/// 정령 상세: 큰 스프라이트 + 게이지 + 통계 + 최근 로그
class PetDetailSheet extends StatelessWidget {
  const PetDetailSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameViewModel>();
    final pet = game.state;
    final stage = Sprites.forLevel(pet.level);
    final fainted = pet.hunger <= Balance.hungerMin;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Palette.tile,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: PetSprite(
                    level: pet.level,
                    asciiFace: pet.face,
                    size: 56,
                    dim: fainted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Palette.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lv.${pet.level} · ${stage.label} · ${pet.moodLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _GaugeRow(
              label: '경험치',
              value: game.expProgress,
              valueText: '${pet.exp}/${game.expToNext}',
            ),
            const SizedBox(height: 8),
            _GaugeRow(
              label: '포만감',
              value: pet.hunger / 100.0,
              valueText: '${pet.hunger.toStringAsFixed(0)}%',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '마나 ${pet.mana} M',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Palette.ink,
                  ),
                ),
                const Spacer(),
                Text(
                  '함께 쓴 글 ${pet.totalChars}자',
                  style: const TextStyle(fontSize: 11, color: Palette.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: Palette.line),
            const SizedBox(height: 10),
            ...game.recentLogs.take(6).map(
                  (log) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      log,
                      style:
                          const TextStyle(fontSize: 11, color: Palette.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            if (game.recentLogs.isEmpty)
              const Text(
                '아직 소식이 없어요. 글을 쓰고 저장해 보세요.',
                style: TextStyle(fontSize: 11, color: Palette.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _GaugeRow extends StatelessWidget {
  final String label;
  final double value;
  final String valueText;

  const _GaugeRow({
    required this.label,
    required this.value,
    required this.valueText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Palette.muted),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              backgroundColor: Palette.track,
              color: Palette.accent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 66,
          child: Text(
            valueText,
            style: const TextStyle(fontSize: 11, color: Palette.ink),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
