import 'package:flutter/material.dart';
import 'tokens.dart';

/// Global theme tuned to the soft, mostly-white palette.
ThemeData buildAppTheme() {
  const family = 'SF Pro';

  final baseText = const TextTheme(
    displaySmall: TextStyle(
      fontSize: 32,
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: AppColors.text,
      letterSpacing: -0.2,
    ),
    titleMedium: TextStyle(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: AppColors.text,
      letterSpacing: -0.2,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.40,
      fontWeight: FontWeight.w500,
      color: AppColors.text,
    ),
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

    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.canvas,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.text,
    ),

    // Inputs / search pill
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.button, // Soft Surface
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
    ),

    // “Connect” style text buttons (taupe fill)
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        backgroundColor: AppColors.button,
        foregroundColor: AppColors.text,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ).copyWith(
        overlayColor: MaterialStateProperty.all(
          AppColors.button.withOpacity(0.65),
        ),
      ),
    ),

    // Primary elevated buttons
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

    // Card theme: very clean, almost like LinkedIn/Reddit
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: AppColors.border.withOpacity(0.6),
          width: 1,
        ),
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
      secondary: AppColors.button,
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
