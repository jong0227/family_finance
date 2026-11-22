import 'package:flutter/material.dart';

import 'tokens.dart';

/// 글자는 작고 단정하게(본문 13), 큰 대제목 없음, 줄무늬 없음 — 사용자 취향(CLAUDE.md).
/// Material 기본 보라·파랑이 새어 나오지 않게 primary = ink 로 둔다(DESIGN_SYSTEM 11장).
ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.ink,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
  ).copyWith(
    primary: p.ink,
    onPrimary: p.onInk,
    primaryContainer: p.surfaceMuted,
    onPrimaryContainer: p.ink,
    secondary: p.ink,
    onSecondary: p.onInk,
    secondaryContainer: p.surfaceMuted,
    onSecondaryContainer: p.ink,
    tertiary: p.info,
    error: p.overMark,
    surface: p.surface,
    onSurface: p.ink,
    onSurfaceVariant: p.textSub,
    surfaceContainerLowest: p.surface,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surfaceMuted,
    surfaceContainerHigh: p.surfaceMuted,
    surfaceContainerHighest: p.surfaceMuted,
    outline: p.lineStrong,
    outlineVariant: p.line,
    surfaceTint: Colors.transparent,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: AppText.fontFamily,
    fontFamilyFallback: AppText.fontFamilyFallback,
    scaffoldBackgroundColor: p.canvas,
    dividerColor: p.line,
    extensions: [p],
  );
  final t = base.textTheme;
  TextStyle s(TextStyle? from, TextStyle tok, Color c) => (from ?? const TextStyle()).merge(tok).copyWith(color: c);
  final selected = WidgetState.selected;

  return base.copyWith(
    // Material 위젯이 쓰는 글자도 AppText 스케일로. 화면 코드는 AppText 를 직접 쓴다.
    textTheme: t.copyWith(
      titleLarge: s(t.titleLarge, AppText.titleLg, p.ink),
      titleMedium: s(t.titleMedium, AppText.title, p.ink),
      titleSmall: s(t.titleSmall, AppText.label, p.ink),
      bodyLarge: s(t.bodyLarge, AppText.body, p.ink),
      bodyMedium: s(t.bodyMedium, AppText.body, p.ink),
      bodySmall: s(t.bodySmall, AppText.caption, p.textSub),
      labelLarge: s(t.labelLarge, AppText.bodyStrong, p.ink),
      labelMedium: s(t.labelMedium, AppText.caption, p.textSub),
      labelSmall: s(t.labelSmall, AppText.caption, p.textMuted),
    ),
    appBarTheme: AppBarTheme(
      toolbarHeight: AppSize.appBar,
      backgroundColor: p.canvas,
      foregroundColor: p.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: AppGap.page,
      titleTextStyle: AppText.title.copyWith(color: p.ink),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: AppSize.tabBar,
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: p.line,
      iconTheme: WidgetStateProperty.resolveWith(
          (st) => IconThemeData(size: AppSize.navIcon, color: st.contains(selected) ? p.ink : p.textMuted)),
      labelTextStyle: WidgetStateProperty.resolveWith((st) => st.contains(selected)
          ? AppText.caption.copyWith(color: p.ink, fontWeight: FontWeight.w600)
          : AppText.caption.copyWith(color: p.textMuted)),
    ),
    // 필터 칩(7.3): 꺼짐 = surfaceMuted + textSub, 켜짐 = ink + onInk. 체크 표시 없음.
    chipTheme: ChipThemeData(
      showCheckmark: false,
      color: WidgetStateProperty.resolveWith((st) => st.contains(selected) ? p.ink : p.surfaceMuted),
      labelStyle: AppText.label.copyWith(
        color: WidgetStateColor.resolveWith((st) => st.contains(selected) ? p.onInk : p.textSub),
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      padding: const EdgeInsets.symmetric(horizontal: AppGap.xs),
      labelPadding: const EdgeInsets.symmetric(horizontal: AppGap.xs),
    ),
    // 세그먼트(SegmentedPills): 알약 모양, 선택 = ink.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: const VisualDensity(horizontal: -2, vertical: -4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        side: WidgetStatePropertyAll(BorderSide(color: p.lineStrong)),
        backgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(selected) ? p.ink : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith((st) => st.contains(selected) ? p.onInk : p.textSub),
        textStyle: const WidgetStatePropertyAll(AppText.label),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppSize.button),
        textStyle: AppText.bodyStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.ink,
        textStyle: AppText.bodyStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceMuted,
      isDense: true,
      hintStyle: AppText.body.copyWith(color: p.textMuted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide(color: p.ink)),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),
    dataTableTheme: DataTableThemeData(
      headingTextStyle: AppText.caption.copyWith(color: p.textMuted),
      dataTextStyle: AppText.label.copyWith(color: p.ink),
      dividerThickness: 1,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.ink, linearTrackColor: p.surfaceMuted),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.ink,
      contentTextStyle: AppText.body.copyWith(color: p.onInk),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
  );
}
