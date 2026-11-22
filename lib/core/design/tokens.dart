import 'package:flutter/material.dart';

/// 디자인 토큰 (docs/DESIGN_SYSTEM.md 3~6장). 화면은 숫자·색을 직접 쓰지 않고 여기만 쓴다.

/// 글자 크기 스케일 (DESIGN_SYSTEM 4.3). 색은 넣지 않는다 — 테마 기본색(ink)을 받거나 화면에서 팔레트 색을 덧입힌다.
/// 굵기는 400·500·600·700 네 개만(`FontWeight.bold` 같은 별칭 금지).
abstract final class AppText {
  /// Pretendard 를 번들하면 'Pretendard' 로 바꾼다(4.1). 지금은 시스템 글꼴.
  static const String? fontFamily = null;
  static const fontFamilyFallback = <String>['Noto Sans KR'];

  static const micro = TextStyle(fontSize: 10, fontWeight: FontWeight.w500, height: 1.2);
  static const caption = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.3);
  static const label = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.3);
  static const body = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.45);
  static const bodyStrong = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.45);
  static const title = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.35);
  static const titleLg = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3);
  static const numMd = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.15);
  static const kpi = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.1);
  static const hero = TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.1);

  /// 가족 코드처럼 한 글자씩 읽어야 하는 값.
  static const code = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: 3);

  /// 표 숫자(tnum) — 세로로 줄 맞춰 비교하는 모든 숫자(4.2).
  static const tabular = <FontFeature>[FontFeature.tabularFigures()];
}

extension TabularText on TextStyle {
  /// 표 숫자로. 혼자 크게 보이는 KPI 숫자에는 쓰지 않는다(4.2).
  TextStyle get tnum => copyWith(fontFeatures: AppText.tabular);
}

/// 간격 — 4 기반 (5.1).
abstract final class AppGap {
  static const xxs = 2.0, xs = 4.0, snug = 6.0, sm = 8.0, cozy = 10.0, md = 12.0, lg = 16.0, xl = 20.0, xxl = 24.0;

  /// 화면 좌우 여백(compact). 폭 구간(Breakpoint)이 생기면 거기서 정한다.
  static const page = 16.0;
}

/// 모서리 (5.3).
abstract final class AppRadius {
  static const xs = 4.0, sm = 8.0, md = 10.0, lg = 14.0, xl = 20.0, pill = 999.0;
}

/// 고정 높이·크기 (5.2).
abstract final class AppSize {
  static const appBar = 44.0, tabBar = 56.0;
  static const rowDense = 36.0, row = 40.0, rowTwoLine = 52.0;
  static const sectionHead = 28.0, tableHead = 28.0, chip = 28.0;
  static const button = 44.0, touchMin = 44.0;
  static const dot = 6.0, progress = 6.0, progressLg = 8.0, planTick = 2.0;
  static const icon = 16.0, iconMd = 18.0, navIcon = 22.0;

  /// 표·행 안 오른쪽 숫자 칸 폭(`12.3만 초과`가 한 줄에 들어가게).
  static const numCol = 72.0;
}

/// 투명도.
abstract final class AppAlpha {
  /// 다른 항목에 포커스가 있을 때 나머지 행.
  static const dimmed = 0.45;

  /// 차트에서 지난 달 막대(현재 달만 진하게, 6.2).
  static const past = 0.2;

  /// 진행 바 채움(분류색이 붙기 전까지 무채색).
  static const barFill = 0.55;

  /// 일회성 등 보조 조각.
  static const faint = 0.12;
}

/// 차트 공통 값 (6장, fl_chart).
abstract final class AppChart {
  static const height = 180.0, heightSm = 160.0;
  static const axisReserved = 32.0;
  static const barWidth = 10.0; // compact
  static const gridDash = <int>[2, 3];
  static const planDash = <int>[4, 3];
  static const planStroke = 1.5, gridStroke = 1.0;

  /// 맨 위 막대 위 여유.
  static const headroom = 1.12;
}

/// 무채색 바탕·글자 + 의미색(초과/여유/안내). 라이트/다크 두 벌.
/// 의미색은 `mark`(막대·점) / `text`(글자, 4.5:1 이상) / `Bg`(옅은 면) 한 벌 — 3.2장.
/// 의미색은 **판단**(초과·여유·안내)에만 쓴다. 선택·강조·장식은 `ink`.
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
    required this.overMark,
    required this.overBg,
    required this.under,
    required this.underMark,
    required this.underBg,
    required this.info,
    required this.infoMark,
    required this.infoBg,
  });

  final Color canvas, surface, surfaceMuted, ink, textSub, textMuted, line, lineStrong, onInk;

  /// `over`/`under`/`info` 는 글자색(text). 막대·점은 `*Mark`.
  final Color over, overMark, overBg, under, underMark, underBg, info, infoMark, infoBg;

  /// 판단 없음(계획대로, ±5% 안).
  Color get neutral => textSub;

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
    overMark: Color(0xFFCC3430),
    overBg: Color(0xFFFFEDEB),
    under: Color(0xFF00703E),
    underMark: Color(0xFF1A8A51),
    underBg: Color(0xFFE5F7EB),
    info: Color(0xFF1A609E),
    infoMark: Color(0xFF3275B4),
    infoBg: Color(0xFFE8F3FF),
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
    overMark: Color(0xFFF66D62),
    overBg: Color(0xFF442320),
    under: Color(0xFF4EC983),
    underMark: Color(0xFF4EC983),
    underBg: Color(0xFF173523),
    info: Color(0xFF73B0EE),
    infoMark: Color(0xFF73B0EE),
    infoBg: Color(0xFF192F46),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) {
    if (other is! Palette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      ink: l(ink, other.ink),
      textSub: l(textSub, other.textSub),
      textMuted: l(textMuted, other.textMuted),
      line: l(line, other.line),
      lineStrong: l(lineStrong, other.lineStrong),
      onInk: l(onInk, other.onInk),
      over: l(over, other.over),
      overMark: l(overMark, other.overMark),
      overBg: l(overBg, other.overBg),
      under: l(under, other.under),
      underMark: l(underMark, other.underMark),
      underBg: l(underBg, other.underBg),
      info: l(info, other.info),
      infoMark: l(infoMark, other.infoMark),
      infoBg: l(infoBg, other.infoBg),
    );
  }
}

extension PaletteX on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
}

/// 구독 주인 배지 색 — 사용자 지정(a = 파랑, b = 빨강), Ninedogs 와 같은 값.
/// 판단색(over/under)과 헷갈리지 않게 배지(옅은 면 + 이름)에만 쓴다.
class PersonColors {
  PersonColors._();
  static const aLight = Color(0xFF3B82F6), bLight = Color(0xFFF43F5E);
  static const aDark = Color(0xFF60A5FA), bDark = Color(0xFFFB7185);
  static const badgeAlpha = 0.16;

  static Color of(BuildContext context, String key) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (key == 'b') return dark ? bDark : bLight;
    return dark ? aDark : aLight;
  }
}
