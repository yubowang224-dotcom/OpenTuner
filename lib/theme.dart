import 'package:flutter/material.dart';

import 'widgets/route_tooltips.dart';

abstract final class TuneColors {
  static const background = Color(0xFFF5F7F8);
  static const ink = Color(0xFF18333C);
  static const muted = Color(0xFF60747D);
  static const accent = Color(0xFF16766D);
  static const pale = Color(0xFFE5F2EF);
  static const border = Color(0xFFE1E9EB);
  static const warm = Color(0xFF92532B);
}

ThemeData buildTheme([Brightness brightness = Brightness.light]) {
  final dark = brightness == Brightness.dark;
  final background = dark ? const Color(0xFF101C22) : TuneColors.background;
  final surface = dark ? const Color(0xFF192A32) : Colors.white;
  final ink = dark ? const Color(0xFFE4F0F1) : TuneColors.ink;
  final muted = dark ? const Color(0xFFB1C7CE) : TuneColors.muted;
  final accent = dark ? const Color(0xFF78D8C6) : TuneColors.accent;
  final pale = dark ? const Color(0xFF264D49) : TuneColors.pale;
  final border = dark ? const Color(0xFF536E79) : TuneColors.border;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: TuneColors.accent,
        brightness: brightness,
        surface: surface,
      ).copyWith(
        primary: accent,
        onPrimary: dark ? const Color(0xFF00382F) : Colors.white,
        primaryContainer: pale,
        onPrimaryContainer: ink,
        onSurface: ink,
        onSurfaceVariant: muted,
        outline: muted,
        outlineVariant: border,
      );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final entry in const PageTransitionsTheme().builders.entries)
          entry.key: RouteTooltipsTransitions(entry.value),
      },
    ),
    scaffoldBackgroundColor: background,
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium!.copyWith(
        fontSize: 27,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
      ),
      titleMedium: base.textTheme.titleMedium!.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: base.textTheme.bodyMedium!.copyWith(height: 1.55),
      bodySmall: base.textTheme.bodySmall!.copyWith(height: 1.5, color: muted),
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        side: BorderSide(color: border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: pale,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surface,
      indicatorColor: pale,
    ),
    chipTheme: base.chipTheme.copyWith(
      side: BorderSide(color: border),
      selectedColor: pale,
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1),
    sliderTheme: base.sliderTheme.copyWith(
      trackHeight: 3,
      inactiveTrackColor: border,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
  );
}
