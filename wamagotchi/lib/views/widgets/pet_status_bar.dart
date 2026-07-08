import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/achievements.dart';
import '../../data/balance.dart';
import '../../data/palette.dart';
import '../../data/sprites.dart';
import '../../logic/game_engine.dart';
import '../../viewmodels/game_viewmodel.dart';
import '../hall_screen.dart';
import '../shop_screen.dart';
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

/// 정령 상세 시트 열기 (상점·전당·은퇴 액션 처리)
Future<void> showPetDetailSheet(BuildContext context) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const PetDetailSheet(),
  );
  if (!context.mounted) return;

  if (action == 'shop') {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShopScreen()),
    );
  } else if (action == 'hall') {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HallScreen()),
    );
  } else if (action == 'retire') {
    await _confirmRetire(context);
  }
}

/// 은퇴(환생) 확인 다이얼로그 (Phase 5)
Future<void> _confirmRetire(BuildContext context) async {
  final game = context.read<GameViewModel>();
  final pet = game.state;
  final nextMult =
      (pet.prestigeManaMult + (pet.prestigeCount == 0 ? 0.5 : 0.25))
          .toStringAsFixed(2);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Palette.line),
      ),
      title: const Text('명예로운 은퇴',
          style: TextStyle(color: Palette.ink, fontSize: 17)),
      content: Text(
        "'${pet.displayName}'을(를) 은퇴시키면 명예의 전당에 기록되고\n"
        '새로운 알과 함께 1레벨부터 다시 시작해요.\n\n'
        '· 유지: 마나, 장비, 가방, 전당 기록\n'
        '· 초기화: 레벨, 클래스, 던전 진행\n'
        '· 보상: 글자당 마나 ×$nextMult (영구)',
        style: const TextStyle(
            fontSize: 13, color: Palette.muted, height: 1.6),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('아직은…', style: TextStyle(color: Palette.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(
            '은퇴식 거행!',
            style: TextStyle(
                color: Palette.accent, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    final error = await context.read<GameViewModel>().retire();
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }
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

    final title = Achievements.titleById(pet.titleId);
    final today = GameEngine.ymd(DateTime.now());
    final quest = pet.questYmd == today ? Quests.byId(pet.questId) : null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 정령을 톡 — 쓰다듬기 (Phase 5 2차)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final reaction =
                        await context.read<GameViewModel>().pat();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          content: Text(reaction),
                          duration: const Duration(seconds: 2),
                        ));
                    }
                  },
                  child: Container(
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          '「${title.name}」',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Palette.accent,
                          ),
                        ),
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
                        'Lv.${pet.level} · '
                        '${game.classSpec?.name ?? stage.label} · '
                        '${pet.moodLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Palette.muted,
                        ),
                      ),
                      if (pet.prestigeCount > 0)
                        Text(
                          '🏆 ${pet.prestigeCount + 1}세대 · 글자당 마나 '
                          '×${pet.prestigeManaMult.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Palette.accent,
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
            const SizedBox(height: 6),
            Text(
              pet.isEgg
                  ? '알은 아직 모험을 떠날 수 없어요.'
                  : pet.isExploring
                      ? '🗺 ${game.dungeon.name} ${pet.floor}층 탐험 중 '
                          '(${Balance.tickMinutes}분마다 전진)'
                      : '탐험 대기 중 — 포만감 '
                          '${Balance.exploreHungerThreshold.toStringAsFixed(0)}% '
                          ' 이상이면 출발해요. 글을 써 주세요!',
              style: const TextStyle(fontSize: 11, color: Palette.muted),
            ),
            const SizedBox(height: 4),
            Text(
              '장비: ${game.weapon?.name ?? '—'} · '
              '${game.armor?.name ?? '—'} · ${game.accessory?.name ?? '—'}',
              style: const TextStyle(fontSize: 11, color: Palette.muted),
            ),
            if (!pet.isEgg) ...[
              const SizedBox(height: 4),
              Text(
                '💚 친밀도 Lv.${pet.bondLevel} (${pet.bondLabel}) — '
                '정령을 톡 하면 쓰다듬기 · 🔥 연속 ${pet.streak}일',
                style: const TextStyle(fontSize: 11, color: Palette.muted),
              ),
              const SizedBox(height: 4),
              Text(
                quest == null
                    ? '📌 오늘의 부탁 — 글을 쓰거나 쓰다듬으면 도착해요'
                    : pet.questDone
                        ? '📌 오늘의 부탁 완료! ✓'
                        : '📌 오늘의 부탁: "${quest.desc}" '
                            '(${pet.questProgress}/${quest.target})',
                style: TextStyle(
                  fontSize: 11,
                  color:
                      pet.questDone ? Palette.accent : Palette.muted,
                  fontWeight:
                      pet.questDone ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
            if (pet.lastLetter != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: InkWell(
                  onTap: () => _showLetter(context, pet.lastLetter!),
                  child: const Text(
                    '📮 정령의 편지 읽기',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Palette.accent,
                    ),
                  ),
                ),
              ),
            if (pet.buffActive)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '✨ 성취의 기운 — 마나 +20% '
                  '(${pet.buffManaUntil!.difference(DateTime.now()).inMinutes + 1}분 남음)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Palette.accent,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Palette.accent,
                      side: const BorderSide(color: Palette.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.storefront_outlined, size: 18),
                    label: const Text(
                      '상점 · 가방',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => Navigator.of(context).pop('shop'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Palette.accent,
                      side: const BorderSide(color: Palette.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.emoji_events_outlined, size: 18),
                    label: const Text(
                      '명예의 전당',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => Navigator.of(context).pop('hall'),
                  ),
                ),
              ],
            ),
            if (pet.level >= Balance.maxLevel)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.accent,
                      foregroundColor: const Color(0xFFF4F6E8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text(
                      '명예로운 은퇴 (환생)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => Navigator.of(context).pop('retire'),
                  ),
                ),
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

/// 정령의 편지 다이얼로그 (Phase 5 2차)
void _showLetter(BuildContext context, String letter) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Palette.line),
      ),
      title: const Text('📮 정령의 편지',
          style: TextStyle(color: Palette.ink, fontSize: 16)),
      content: Text(
        letter,
        style: const TextStyle(
            fontSize: 13.5, color: Palette.ink, height: 1.8),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('소중히 접어 두기',
              style: TextStyle(
                  color: Palette.accent, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
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
