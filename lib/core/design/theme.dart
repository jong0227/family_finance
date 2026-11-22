import 'package:flutter/material.dart';

import 'tokens.dart';

/// 글자는 작고 단정하게(본문 13), 큰 대제목 없음, 줄무늬 없음 — 사용자 취향(CLAUDE.md).
ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? Palette.dark : Palette.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.info,
      brightness: brightness,
      surface: p.surface,
    ),
    scaffoldBackgroundColor: p.canvas,
    dividerColor: p.line,
    extensions: [p],
  );
  final t = base.textTheme;
  return base.copyWith(
    textTheme: t.copyWith(
      titleLarge: t.titleLarge?.copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: p.ink),
      titleMedium: t.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: p.ink),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: 14, color: p.ink),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: 13, color: p.ink),
      bodySmall: t.bodySmall?.copyWith(fontSize: 12, color: p.textSub),
      labelMedium: t.labelMedium?.copyWith(fontSize: 12, color: p.textMuted),
      labelSmall: t.labelSmall?.copyWith(fontSize: 11, color: p.textMuted),
    ),
    appBarTheme: AppBarTheme(
      toolbarHeight: AppSize.appBar,
      backgroundColor: p.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: p.ink),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: AppSize.tabBar,
      backgroundColor: p.surface,
      indicatorColor: p.surfaceMuted,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11, color: p.textSub)),
    ),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
  );
}
