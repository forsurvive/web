import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/items.dart';
import '../data/palette.dart';
import '../viewmodels/game_viewmodel.dart';

/// 상점 · 가방 (Phase 4).
///
/// 상점: 마나로 구매 / 가방: 장착·사용·판매.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameViewModel>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            '상점 · 가방',
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
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${game.state.mana} M',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Palette.accent,
                  ),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            labelColor: Palette.ink,
            unselectedLabelColor: Palette.muted,
            indicatorColor: Palette.accent,
            tabs: [Tab(text: '상점'), Tab(text: '가방')],
          ),
        ),
        body: const TabBarView(
          children: [_ShopTab(), _BagTab()],
        ),
      ),
    );
  }
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
    ));
}

class _ItemCard extends StatelessWidget {
  final ItemSpec item;
  final String? badge;
  final Widget? action;

  const _ItemCard({required this.item, this.badge, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: Palette.surface,
        border: Border.all(color: Palette.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: Palette.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Palette.muted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.desc,
                  style: const TextStyle(fontSize: 11.5, color: Palette.muted),
                ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// 구매 탭
class _ShopTab extends StatelessWidget {
  const _ShopTab();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameViewModel>();
    final items = Items.all.where((i) => i.isBuyable).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final item in items)
          _ItemCard(
            item: item,
            badge: item.isEquipment && game.ownsItem(item.id) ? '보유 중' : null,
            action: TextButton(
              onPressed: item.isEquipment && game.ownsItem(item.id)
                  ? null
                  : () async {
                      final vm = context.read<GameViewModel>();
                      final error = await vm.buyItem(item.id);
                      if (context.mounted) {
                        _showSnack(
                            context, error ?? '[${item.name}] 구매 완료!');
                      }
                    },
              child: Text(
                '${item.price} M',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: item.isEquipment && game.ownsItem(item.id)
                      ? Palette.muted
                      : Palette.accent,
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        const Text(
          '마나는 글을 쓰고 정령이 모험하며 모입니다.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Palette.muted),
        ),
      ],
    );
  }
}

/// 가방 탭 — 장착 슬롯 + 보유 아이템
class _BagTab extends StatelessWidget {
  const _BagTab();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameViewModel>();
    final pet = game.state;
    final entries = pet.inventory.entries
        .where((e) => e.value > 0 && Items.byId(e.key) != null)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Palette.surface,
            border: Border.all(color: Palette.line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '장착 중',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Palette.muted,
                ),
              ),
              const SizedBox(height: 6),
              Text('무기　 ${game.weapon?.name ?? '—'}',
                  style: const TextStyle(fontSize: 12.5, color: Palette.ink)),
              Text('방어구 ${game.armor?.name ?? '—'}',
                  style: const TextStyle(fontSize: 12.5, color: Palette.ink)),
              Text('장신구 ${game.accessory?.name ?? '—'}',
                  style: const TextStyle(fontSize: 12.5, color: Palette.ink)),
            ],
          ),
        ),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text(
              '가방이 비어 있어요.\n상점에서 사거나, 글 속 키워드로 재료를 얻어 보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Palette.muted),
            ),
          )
        else
          for (final entry in entries)
            _BagItem(id: entry.key, count: entry.value),
      ],
    );
  }
}

class _BagItem extends StatelessWidget {
  final String id;
  final int count;

  const _BagItem({required this.id, required this.count});

  @override
  Widget build(BuildContext context) {
    final item = Items.byId(id)!;

    String actionLabel;
    Future<String?> Function(GameViewModel vm) action;
    if (item.isEquipment) {
      actionLabel = '장착';
      action = (vm) => vm.equipItem(id);
    } else if (item.type == ItemType.consumable) {
      actionLabel = '사용';
      action = (vm) => vm.useItem(id);
    } else {
      actionLabel = '판매 +${item.sellPrice} M';
      action = (vm) => vm.sellItem(id);
    }

    return _ItemCard(
      item: item,
      badge: count > 1 ? '×$count' : null,
      action: TextButton(
        onPressed: () async {
          final vm = context.read<GameViewModel>();
          final error = await action(vm);
          if (context.mounted && error != null) {
            _showSnack(context, error);
          }
        },
        child: Text(
          actionLabel,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Palette.accent,
          ),
        ),
      ),
    );
  }
}
