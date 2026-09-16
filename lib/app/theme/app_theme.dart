import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Shared Brand Colors
  static const Color primary = Color(0xFFF05454);
  static const Color secondary = Color(0xFF1F9DCC);
  static const Color tertiary = Color(0xFFFFB44C);

  // Dark Theme Palette
  static const Color _darkBackground = Color(0xFF070B12);
  static const Color _darkSurface = Color(0xFF101826);
  static const Color _darkSurfaceHigh = Color(0xFF162235);
  static const Color _darkOutline = Color(0xFF243247);

  // Light Theme Palette
  static const Color _lightBackground = Color(0xFFF8FAFC);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceHigh = Color(0xFFF1F5F9);
  static const Color _lightOutline = Color(0xFFE2E8F0);
  static const Color _lightTextPrimary = Color(0xFF0F172A);
  static const Color _lightTextSecondary = Color(0xFF475569);

  /// Allows tests or offline environments to disable runtime font fetching.
  static bool useGoogleFonts = true;

  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      surface: _darkSurface,
    ).copyWith(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      surface: _darkSurface,
      surfaceContainerHighest: _darkSurfaceHigh,
      outline: _darkOutline,
      onPrimary: Colors.white,
      onSurface: Colors.white,
    );

    final baseTextTheme = useGoogleFonts
        ? GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme)
        : ThemeData.dark().textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _darkBackground,
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          height: 1.5,
          color: Colors.white,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          height: 1.5,
          color: Colors.white70,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _darkOutline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _darkSurfaceHigh,
        selectedColor: primary.withValues(alpha: 0.18),
        secondarySelectedColor: primary.withValues(alpha: 0.18),
        side: const BorderSide(color: _darkOutline),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: baseTextTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: _darkOutline,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white60,
          side: const BorderSide(color: _darkOutline),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _darkOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _darkOutline),
        ),
      ),
    );
  }

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: _lightSurface,
    ).copyWith(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      surface: _lightSurface,
      surfaceContainerHighest: _lightSurfaceHigh,
      outline: _lightOutline,
      onPrimary: Colors.white,
      onSurface: _lightTextPrimary,
    );

    final baseTextTheme = useGoogleFonts
        ? GoogleFonts.outfitTextTheme(ThemeData.light().textTheme)
        : ThemeData.light().textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _lightBackground,
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: _lightTextPrimary,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: _lightTextPrimary,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: _lightTextPrimary,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: _lightTextPrimary,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: _lightTextPrimary,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: _lightTextPrimary,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          height: 1.5,
          color: _lightTextPrimary,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          height: 1.5,
          color: _lightTextSecondary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: _lightTextPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _lightOutline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _lightSurfaceHigh,
        selectedColor: primary.withValues(alpha: 0.12),
        secondarySelectedColor: primary.withValues(alpha: 0.12),
        side: const BorderSide(color: _lightOutline),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: baseTextTheme.labelLarge?.copyWith(
          color: _lightTextPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: _lightOutline,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _lightTextPrimary,
          disabledForegroundColor: _lightTextSecondary,
          side: const BorderSide(color: _lightOutline),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lightSurfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _lightOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _lightOutline),
        ),
      ),
    );
  }
}

/// Dynamic theme color extension for adaptive components.
extension ThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  ColorScheme get colors => Theme.of(this).colorScheme;

  Color get scaffoldBg =>
      isDark ? const Color(0xFF070B12) : const Color(0xFFF8FAFC);
  Color get surfaceBg => isDark ? const Color(0xFF101826) : Colors.white;
  Color get elevatedBg =>
      isDark ? const Color(0xFF162235) : const Color(0xFFF1F5F9);
  Color get borderCol =>
      isDark ? const Color(0xFF243247) : const Color(0xFFE2E8F0);
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? Colors.white70 : const Color(0xFF475569);
  Color get textMuted => isDark ? Colors.white38 : const Color(0xFF94A3B8);

  // Shell & Navigation Colors
  Color get navBg => isDark
      ? const Color(0xFF070B12).withValues(alpha: 0.97)
      : Colors.white.withValues(alpha: 0.97);
  Color get sidebarBg => isDark ? const Color(0xFF0D1520) : Colors.white;
  Color get topBarBg =>
      isDark ? const Color(0xFF0D1520) : const Color(0xFFFFFFFF);
  Color get cardHoverBg => isDark
      ? Colors.white.withValues(alpha: 0.05)
      : Colors.black.withValues(alpha: 0.03);
}
