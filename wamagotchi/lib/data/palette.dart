import 'package:flutter/material.dart';

/// 색상 팔레트 — v2 "라이팅 퍼스트" 개정.
///
/// 화면의 주인공은 글쓰기 공간이므로 종이·잉크 기조의 차분한 색을 쓰고,
/// 게임 아이덴티티(레트로 그린)는 정령 칩과 게이지에만 응축한다.
class Palette {
  Palette._();

  // ── 종이 & 잉크 (앱 전반) ─────────────────────────────
  /// 앱 배경 (은은한 종이색)
  static const Color paper = Color(0xFFF2F1E8);

  /// 카드·에디터 표면
  static const Color surface = Color(0xFFFBFAF4);

  /// 본문 텍스트
  static const Color ink = Color(0xFF262B1E);

  /// 보조 텍스트
  static const Color muted = Color(0xFF83816F);

  /// 얇은 구분선·테두리
  static const Color line = Color(0xFFDCDACA);

  // ── 게임 아이덴티티 (정령 칩·게이지·버튼) ─────────────
  /// 액션·게이지 색 = 스프라이트 잉크색
  static const Color accent = Color(0xFF0F380F);

  /// 정령 칩의 작은 LCD 타일 (스프라이트 배경)
  static const Color tile = Color(0xFFA9C43C);

  /// 게이지 바탕
  static const Color track = Color(0xFFE6E3D3);

  // ── 하위 호환 별칭 (기존 코드 참조용) ─────────────────
  static const Color lcdGreen = Color(0xFF8BAC0F);
  static const Color lcdLight = Color(0xFF9BBC0F);
  static const Color lcdMid = Color(0xFF306230);
  static const Color lcdDark = accent;
}
