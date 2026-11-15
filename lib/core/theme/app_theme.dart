import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color sky = Color(0xFF0EA5E9);
  static const Color skyDark = Color(0xFF0284C7);
  static const Color skyLight = Color(0xFF7DD3FC);
  static const Color skyPale = Color(0xFFE6F5FE);
  static const Color background = Color(0xFFF6FBFF);
  static const Color surface = Colors.white;
  static const Color ink = Color(0xFF0B2A40);
  static const Color muted = Color(0xFF5B7C93);
  static const Color border = Color(0xFFD6EAF8);

  // Detection colours
  static const Color shelf = Color(0xFF0EA5E9);
  static const Color product = Color(0xFF16A34A);
  static const Color empty = Color(0xFFF97316);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.sky,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.sky,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.sky,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.skyDark,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.sky,
        thumbColor: AppColors.sky,
        inactiveTrackColor: AppColors.skyPale,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.sky : null),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Soft shadow used by white cards.
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: AppColors.sky.withAlpha(30),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
}
