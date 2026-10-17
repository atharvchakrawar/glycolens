import 'package:flutter/material.dart';

class AppTheme {
  // Clinical High-Contrast Modern Color Palette
  static const Color primaryTeal = Color(0xFF00695C);
  static const Color tealDark = Color(0xFF004D40);
  static const Color tealLight = Color(0xFFE0F2F1);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE2E8F0);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // Clinical Alert State Colors (Color + Icon Accessible)
  static const Color inRangeGreen = Color(0xFF10B981);
  static const Color inRangeGreenDark = Color(0xFF047857);
  static const Color watchAmber = Color(0xFFF59E0B);
  static const Color watchAmberDark = Color(0xFFB45309);
  static const Color warningRed = Color(0xFFEF4444);
  static const Color warningRedDark = Color(0xFFB91C1C);
  static const Color criticalCrimson = Color(0xFF991B1B);
  static const Color highPurple = Color(0xFF7C3AED);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: null, // Default system font (Roboto/SF Pro)
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        primary: primaryTeal,
        secondary: const Color(0xFF0284C7),
        surface: surfaceWhite,
        background: backgroundLight,
      ),
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceWhite,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: cardBorder, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryTeal,
          side: const BorderSide(color: primaryTeal, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // Accessibility Helper: Returns (Color, IconData, StatusLabel, Description) for any glucose value
  static (Color, IconData, String, String) getGlucoseStatus(double glucose, {String? alertLevel}) {
    if (alertLevel == 'CRITICAL' || glucose < 54.0) {
      return (
        criticalCrimson,
        Icons.emergency_rounded,
        'CRITICAL HYPO',
        'Immediate fast-acting carbs & assistance required'
      );
    } else if (alertLevel == 'WARNING' || glucose < 70.0) {
      return (
        warningRed,
        Icons.warning_amber_rounded,
        'HYPO WARNING',
        'Rapid drop predicted — apply Rule of 15'
      );
    } else if (alertLevel == 'WATCH' || (glucose >= 70.0 && glucose < 85.0)) {
      return (
        watchAmber,
        Icons.visibility_outlined,
        'LOW-NORMAL WATCH',
        'Trending toward lower target boundary'
      );
    } else if (glucose > 180.0) {
      return (
        highPurple,
        Icons.arrow_upward_rounded,
        'ABOVE TARGET',
        'Elevated postprandial glucose level'
      );
    } else {
      return (
        inRangeGreen,
        Icons.check_circle_outline_rounded,
        'IN TARGET RANGE',
        'Safe physiological glucose zone (70–180 mg/dL)'
      );
    }
  }

  // Helper for Glycemic Load (GL) rating
  static (Color, String) getGlycemicLoadBadge(double gl) {
    if (gl <= 10.0) {
      return (inRangeGreen, 'LOW GL');
    } else if (gl <= 19.0) {
      return (watchAmber, 'MED GL');
    } else {
      return (warningRed, 'HIGH GL');
    }
  }
}
