import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF0F6D3F);
  static const Color primaryDark = Color(0xFF0B4F2E);
  static const Color primaryLight = Color(0xFFE8F5EC);

  static const Color accent = Color(0xFF2ECC71);
  static const Color accentSoft = Color(0xFFD9F7E7);

  static const Color background = Color(0xFFF6FAF7);
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFF2F7F3);

  static const Color border = Color(0xFFDDE7DF);
  static const Color divider = Color(0xFFE3EBE5);

  static const Color textPrimary = Color(0xFF1E2A22);
  static const Color textSecondary = Color(0xFF66756B);

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED8B00);
  static const Color info = Color(0xFF1565C0);
  static const Color error = Color(0xFFC62828);
}

class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

class AppRadii {
  const AppRadii._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
}

class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,

      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
