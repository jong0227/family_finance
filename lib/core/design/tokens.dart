import 'package:flutter/material.dart';

/// 디자인 토큰 (docs/DESIGN_SYSTEM.md 3~5장). 화면은 숫자·색을 직접 쓰지 않고 여기만 쓴다.
abstract final class AppGap {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, page = 16.0;
}

abstract final class AppRadius {
  static const sm = 8.0, md = 14.0, lg = 20.0, pill = 999.0;
}

abstract final class AppSize {
  static const appBar = 44.0, row = 40.0, tabBar = 56.0;
}

/// 무채색 바탕·글자 + 의미색(초과/여유/안내) + 사람색. 라이트/다크 두 벌.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.canvas,
    required this.surface,
    required this.surfaceMuted,
    required this.ink,
    required this.textSub,
    required this.textMuted,
    required this.line,
    required this.lineStrong,
    required this.onInk,
    required this.over,
    required this.overBg,
    required this.under,
    required this.underBg,
    required this.info,
    required this.infoBg,
    required this.personA,
    required this.personB,
  });

  final Color canvas, surface, surfaceMuted, ink, textSub, textMuted, line, lineStrong, onInk;
  final Color over, overBg, under, underBg, info, infoBg, personA, personB;

  static const light = Palette(
    canvas: Color(0xFFF4F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF7F8FA),
    ink: Color(0xFF191A1D),
    textSub: Color(0xFF5B5F67),
    textMuted: Color(0xFF6C7078),
    line: Color(0xFFE9EAED),
    lineStrong: Color(0xFFD5D7DC),
    onInk: Color(0xFFFFFFFF),
    over: Color(0xFFB7191C),
    overBg: Color(0xFFFFEDEB),
    under: Color(0xFF00703E),
    underBg: Color(0xFFE5F7EB),
    info: Color(0xFF1A609E),
    infoBg: Color(0xFFE8F3FF),
    personA: Color(0xFF3B82F6),
    personB: Color(0xFFF43F5E),
  );

  static const dark = Palette(
    canvas: Color(0xFF111214),
    surface: Color(0xFF1C1D21),
    surfaceMuted: Color(0xFF24262B),
    ink: Color(0xFFEDEEF0),
    textSub: Color(0xFFA8ACB4),
    textMuted: Color(0xFF8A8E96),
    line: Color(0xFF2C2E33),
    lineStrong: Color(0xFF3A3D43),
    onInk: Color(0xFF111214),
    over: Color(0xFFF66D62),
    overBg: Color(0xFF442320),
    under: Color(0xFF4EC983),
    underBg: Color(0xFF173523),
    info: Color(0xFF73B0EE),
    infoBg: Color(0xFF192F46),
    personA: Color(0xFF60A5FA),
    personB: Color(0xFFFB7185),
  );

  /// 사람 칸(a/b)의 색. Ninedogs 와 같은 원칙(칸에 고정).
  Color person(String key) => key == 'b' ? personB : personA;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) => t < 0.5 ? this : (other as Palette? ?? this);
}

extension PaletteX on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
}
