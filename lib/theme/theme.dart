import 'package:flutter/material.dart';
import 'tokens.dart';

/// Global theme tuned to match the mock with softer warmth.
ThemeData buildAppTheme() {
  const family = 'SF Pro';

  final baseText = const TextTheme(
    // "Home" — slightly lighter than before
    displaySmall: TextStyle(
      fontSize: 32,
      height: 1.15,
      fontWeight: FontWeight.w700, // was 800
      color: AppColors.text,
      letterSpacing: -0.2,
    ),
    // "Welcome, Maria" / section titles
    titleMedium: TextStyle(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: AppColors.text,
      letterSpacing: -0.2,
    ),
    // Post body
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.40,
      fontWeight: FontWeight.w500,
      color: AppColors.text,
    ),
    // Secondary info (timestamps)
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.30,
      fontWeight: FontWeight.w500,
      color: AppColors.muted,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: family,

    // === COLORS ===
    scaffoldBackgroundColor: AppColors.canvas,
    canvasColor: AppColors.canvas,
    cardColor: AppColors.card,

    // Calm interactions (no splash)
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.canvas,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.text,
    ),

    // Taupe input pills
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
    ),

    // “Connect” buttons (same taupe, lighter)
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ).copyWith(
        overlayColor:
            MaterialStateProperty.all(AppColors.surface.withOpacity(0.65)),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),

    // Cards look off-white with a faint warm stroke
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      shadowColor: Colors.transparent,
      clipBehavior: Clip.none,
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.muted,
      textColor: AppColors.text,
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
    ),

    textTheme: baseText,
    primaryTextTheme: baseText,

    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.surface,
      onSecondary: AppColors.text,
      surface: AppColors.card,
      onSurface: AppColors.text,
      background: AppColors.canvas,
      onBackground: AppColors.text,
      error: AppColors.danger,
      onError: Colors.white,
    ),
  );
}
