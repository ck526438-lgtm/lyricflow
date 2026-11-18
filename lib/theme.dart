import 'package:flutter/material.dart';

/// Couleurs reprises de l'icône LyricFlow (néon violet → bleu → cyan).
class LF {
  static const bg = Color(0xFF060716);
  static const surface = Color(0xFF10122A);
  static const surface2 = Color(0xFF181B3A);
  static const border = Color(0xFF262A55);
  static const magenta = Color(0xFFE23BFF);
  static const violet = Color(0xFF8B3DFF);
  static const blue = Color(0xFF2F6BFF);
  static const cyan = Color(0xFF26D9F5);
  static const gold = Color(0xFFF7B733);
  static const text = Color(0xFFF2F3FF);
  static const muted = Color(0xFF8C90B8);
  static const success = Color(0xFF34D399);
  static const danger = Color(0xFFFF5C7A);

  static const gradient = LinearGradient(
    colors: [magenta, violet, blue, cyan],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const softGradient = LinearGradient(
    colors: [Color(0xFF1A0B33), Color(0xFF0A1240)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: violet,
      brightness: Brightness.dark,
    ).copyWith(
      primary: violet,
      secondary: cyan,
      surface: surface,
      onSurface: text,
      error: danger,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: text,
        titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: text),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: violet, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: violet.withValues(alpha: 0.25),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        showDragHandle: true,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface2,
        contentTextStyle: TextStyle(color: text),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: cyan,
        thumbColor: Colors.white,
        inactiveTrackColor: border,
        trackHeight: 3,
      ),
    );
  }
}

String formatDuration(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
