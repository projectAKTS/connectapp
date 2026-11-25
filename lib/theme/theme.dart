import 'package:connect_app/navigation/swipe_back.dart';
import 'package:flutter/material.dart';
import 'tokens.dart';

/// Global theme, design D "Paper & Clay": flat and quiet.
ThemeData buildAppTheme() {
  const family = 'SF Pro';

  final baseText = const TextTheme(
    displaySmall: TextStyle(
      fontFamily: AppFonts.serif,
      fontFamilyFallback: AppFonts.serifFallback,
      fontSize: 28,
      height: 1.15,
      fontWeight: FontWeight.w600,
      color: AppColors.text,
      letterSpacing: -0.5,
    ),
    titleMedium: TextStyle(
      fontFamily: AppFonts.serif,
      fontFamilyFallback: AppFonts.serifFallback,
      fontSize: 18,
      height: 1.3,
      fontWeight: AppFonts.displayWeight,
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
    // Swipe right anywhere to go back, on every page and platform.
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: SwipeBackPageTransitionsBuilder(),
      TargetPlatform.android: SwipeBackPageTransitionsBuilder(),
    }),

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
      // One title style for every screen (some were light, some bold).
      titleTextStyle: TextStyle(
        fontFamily: AppFonts.serif,
        fontFamilyFallback: AppFonts.serifFallback,
        color: AppColors.text,
        fontSize: 17,
        fontWeight: AppFonts.displayWeight,
        letterSpacing: -0.2,
      ),
    ),

    // Inputs / search pill
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.button, // flat field, no border
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
        shape: const StadiumBorder(),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: -0.2),
      ),
    ),

    // Card theme: very clean, almost like LinkedIn/Reddit
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

    // Selected chips read clearly: green tint, green border and text.
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.selected,
      side: WidgetStateBorderSide.resolveWith((states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? AppColors.selectedBorder
                : AppColors.border,
          )),
      // A state-resolved label style rendered invisible text: keep it fixed.
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
      checkmarkColor: AppColors.primary,
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
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      surface: AppColors.card,
      onSurface: AppColors.text,
      background: AppColors.canvas,
      onBackground: AppColors.text,
      error: AppColors.danger,
      onError: Colors.white,
    ),
  );
}
