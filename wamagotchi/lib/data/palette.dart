import 'package:flutter/material.dart';

/// 레트로 LCD 색상 팔레트 (기획서 6.1 — 고전 게임보이 감성).
/// Phase 2에서 픽셀 폰트·스프라이트와 함께 본격 적용되지만,
/// Phase 1에서도 기본 색은 이 팔레트만 사용한다.
class Palette {
  Palette._();

  /// 배경: 칙칙한 연두색
  static const Color lcdGreen = Color(0xFF8BAC0F);

  /// 밝은 연두 (패널 배경)
  static const Color lcdLight = Color(0xFF9BBC0F);

  /// 중간 톤 (게이지 바탕)
  static const Color lcdMid = Color(0xFF306230);

  /// 텍스트·테두리: 짙은 흑녹색
  static const Color lcdDark = Color(0xFF0F380F);
}
