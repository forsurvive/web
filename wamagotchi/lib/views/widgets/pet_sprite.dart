import 'package:flutter/material.dart';

import '../../data/palette.dart';
import '../../data/sprites.dart';

/// 정령 스프라이트 표시 위젯.
///
/// 레벨에 맞는 PNG를 픽셀 선명하게(nearest-neighbor) 그린다.
/// 아직 에셋을 넣지 않았다면 [asciiFace] 텍스트로 대체 표시해 앱이 죽지 않는다.
class PetSprite extends StatelessWidget {
  final int level;
  final String asciiFace;
  final double size;

  /// 기절 상태 등에서 살짝 흐리게
  final bool dim;

  const PetSprite({
    super.key,
    required this.level,
    required this.asciiFace,
    this.size = 84,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    final stage = Sprites.forLevel(level);

    Widget sprite = Image.asset(
      stage.asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // 픽셀 아트는 보간 없이 확대해야 선명하다
      filterQuality: FilterQuality.none,
      isAntiAlias: false,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) => _AsciiFallback(
        face: asciiFace,
        size: size,
      ),
    );

    if (dim) {
      sprite = Opacity(opacity: 0.45, child: sprite);
    }
    return SizedBox(width: size, height: size, child: Center(child: sprite));
  }
}

/// 에셋이 없을 때의 텍스트 얼굴 (Phase 1 감성 유지)
class _AsciiFallback extends StatelessWidget {
  final String face;
  final double size;

  const _AsciiFallback({required this.face, required this.size});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        face,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: size * 0.26,
          fontWeight: FontWeight.bold,
          color: Palette.lcdDark,
        ),
      ),
    );
  }
}
