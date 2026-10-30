import 'package:flutter/material.dart';

class SwaraTheme {
  static const seed = Color(0xFF6A1FD1);
  static const accent = Color(0xFFFF7A59);

  static const brandGradient = LinearGradient(
    colors: [accent, seed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      tertiary: accent,
    );
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF14101F)
          : scheme.surface,
      appBarTheme: const AppBarTheme(centerTitle: false),
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: SliderComponentShape.noOverlay,
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.15),
      ),
    );
  }
}

String formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString();
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}
