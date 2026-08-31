import 'package:flutter/material.dart';

/// Design tokens (prompt §3).
///
/// Nothing in the app hard-codes a colour: every widget reads from here, so the
/// palette can be re-themed (or dark-mode enabled) from a single place.
class AppColors {
  const AppColors._();

  static const Color background = Color(0xFFFFFFFF);
  static const Color primaryNavy = Color(0xFF07164F);
  static const Color navySoft = Color(0xFF1B2C6B);
  static const Color blueAccent = Color(0xFF2585FF);
  static const Color lightUi = Color(0xFFF5F8FC);
  static const Color guideDot = Color(0xFFD9DEE8);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFF0B1A3A);
  static const Color textMuted = Color(0xFF7C879C);
}

/// Spacing / radius scale used across the UI.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  static const double radiusCard = 18;
  static const double radiusButton = 14;
  static const double radiusPill = 999;
}

/// Board visual configuration (kept in sync with [ArrowMetrics]).
class AppBoardTheme {
  const AppBoardTheme._();

  /// Opacity of the always-visible construction grid dots (prompt §12).
  static const double guideDotOpacity = 0.9;

  /// Debug grid opacity.
  static const double debugGridOpacity = 0.16;
}

/// Central theme definition.
class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const base = Typography.material2021(platform: TargetPlatform.android);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.blueAccent,
        onPrimary: Colors.white,
        secondary: AppColors.primaryNavy,
        surface: AppColors.background,
        error: AppColors.error,
      ),
      textTheme: base.black.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.primaryNavy,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.primaryNavy,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightUi,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blueAccent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryNavy,
          backgroundColor: AppColors.lightUi,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
          ),
        ),
      ),
      dividerColor: AppColors.guideDot,
      splashFactory: InkSparkle.splashFactory,
    );
  }

  /// Card shadow used by the status card and the tool bar.
  static List<BoxShadow> get cardShadow => const [
        BoxShadow(
          color: Color(0x1407164F),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get softShadow => const [
        BoxShadow(
          color: Color(0x0F07164F),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];
}
