import 'package:flutter/material.dart';

class AppTheme {
  // Primary Background - Light Blue Solid
  static const Color primaryBackground =
      Color(0xFFB7D4FF); // RGB: 183, 212, 255

  // Secondary Blue (Accent)
  static const Color secondaryBlue = Color(0xFF5B8DEF); // RGB: 91, 141, 239

  // Lighter Blue (for login screen left square)
  static const Color lighterBlue =
      Color(0xFF8BB0F5); // Lighter version of secondaryBlue

  // White
  static const Color white = Color(0xFFFFFFFF);

  // Text - Primary
  static const Color textPrimary = Color(0xFF1F1F1F);

  // Text - Secondary
  static const Color textSecondary = Color(0xFF8C8C8C);

  // Divider / Stroke
  static const Color divider = Color(0xFFEDEDED);

  // Success
  static const Color success = Color(0xFF4CAF50);

  // Error
  static const Color error = Color(0xFFE53935);

  // Input Background
  static const Color inputBackground = Color(0xFFF6F6F6);

  // Search Bar Background
  static const Color searchBarBackground = Color(0xFFF2F2F2);

  // Icon Gray
  static const Color iconGray = Color(0xFF9E9E9E);

  // Yellow (for links)
  static const Color yellow = Color(0xFFFFC107);

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: white,
        primaryColor: secondaryBlue,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: secondaryBlue,
          secondary: success,
          surface: white,
          error: error,
          onPrimary: white,
          onSecondary: white,
          onSurface: textPrimary,
        ),
        fontFamily: 'IBMPlexSansArabic',
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textPrimary,
            fontFamily: 'IBMPlexSansArabic',
          ),
          headlineLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textPrimary,
            fontFamily: 'IBMPlexSansArabic',
          ),
          headlineMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPrimary,
            fontFamily: 'IBMPlexSansArabic',
          ),
          titleLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            fontFamily: 'IBMPlexSansArabic',
          ),
          bodyLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: textPrimary,
            fontFamily: 'IBMPlexSansArabic',
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: textSecondary,
            fontFamily: 'IBMPlexSansArabic',
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: textSecondary,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
        cardTheme: CardThemeData(
          color: white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: divider, width: 1),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: secondaryBlue,
            foregroundColor: white,
            minimumSize: const Size(double.infinity, 48),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'IBMPlexSansArabic',
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: inputBackground,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: secondaryBlue, width: 2),
          ),
          labelStyle: const TextStyle(
            fontSize: 14,
            color: textSecondary,
            fontFamily: 'IBMPlexSansArabic',
          ),
          hintStyle: const TextStyle(
            fontSize: 12,
            color: textSecondary,
            fontFamily: 'IBMPlexSansArabic',
          ),
        ),
      );
}
