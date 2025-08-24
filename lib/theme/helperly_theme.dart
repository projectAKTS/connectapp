import 'package:flutter/material.dart';

/// ===== Brand tokens (exported) =====
const Color brandCream    = Color(0xFFFBF7F2); // page background
const Color brandSpruce   = Color(0xFF0F4C46); // primary/CTAs
const Color brandSpruceTx = Color(0xFF0F3A34); // primary text
const Color brandMint     = Color(0xFFEAF2EE); // soft fills / chips
const Color brandStroke   = Color(0xFFE9E5DE); // borders / outline
const Color brandCoral    = Color(0xFFF08963); // accent (e.g., Boosted)

/*  Helperly light theme (Material 3)  */
ThemeData helperlyTheme() {
  final ColorScheme scheme = ColorScheme(
    brightness: Brightness.light,
    primary: brandSpruce,
    onPrimary: Colors.white,
    secondary: const Color(0xFF3AA572),
    onSecondary: Colors.white,
    error: const Color(0xFFB3261E),
    onError: Colors.white,
    background: brandCream,
    onBackground: brandSpruceTx,
    surface: Colors.white,
    onSurface: brandSpruceTx,
    outline: brandStroke,
    // Material 3 additional roles
    surfaceVariant: brandMint,
    onSurfaceVariant: brandSpruceTx.withOpacity(.8),
    inverseSurface: const Color(0xFF1F2320),
    onInverseSurface: Colors.white,
    inversePrimary: const Color(0xFF8CC7B7),
    tertiary: brandCoral,
    onTertiary: Colors.white,
  );

  final InputDecorationTheme inputs = InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    labelStyle: const TextStyle(color: brandSpruceTx),
    hintStyle: TextStyle(color: brandSpruceTx.withOpacity(.6)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: brandStroke),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: brandSpruce, width: 1.2),
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: brandCream,

    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: brandCream,
      foregroundColor: brandSpruceTx,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: brandSpruceTx,
        fontWeight: FontWeight.w800,
        fontSize: 20,
      ),
      iconTheme: IconThemeData(color: brandSpruceTx),
    ),

    inputDecorationTheme: inputs,

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: brandSpruce,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
        elevation: 2,
        shadowColor: const Color(0x140F4C46),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: brandSpruceTx,
        side: const BorderSide(color: brandSpruce, width: 1.2),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: brandSpruce,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: brandMint,
      selectedColor: brandMint,
      disabledColor: Colors.grey.shade200,
      labelStyle: const TextStyle(color: brandSpruceTx, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: brandSpruceTx),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: const StadiumBorder(side: BorderSide(color: brandStroke)),
      brightness: Brightness.light,
    ),

    // ✅ Flutter 3.24+: ThemeData.cardTheme expects CardThemeData
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: brandStroke),
      ),
      shadowColor: const Color(0x140F4C46),
      clipBehavior: Clip.antiAlias,
    ),

    dividerTheme: const DividerThemeData(color: brandStroke, thickness: 1),

    iconTheme: const IconThemeData(color: brandSpruceTx),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF2F3E3B),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // A few defaults for ListTile to feel card-like
    listTileTheme: ListTileThemeData(
      iconColor: brandSpruce,
      textColor: brandSpruceTx,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}

/* Optional dark theme (keeps tokens coherent) */
ThemeData helperlyDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final scheme = base.colorScheme.copyWith(
    primary: const Color(0xFF7DD6C2),
    onPrimary: const Color(0xFF00201B),
    secondary: const Color(0xFF93E0C8),
    onSecondary: const Color(0xFF03201A),
    background: const Color(0xFF0F1413),
    onBackground: Colors.white,
    surface: const Color(0xFF151B1A),
    onSurface: Colors.white,
    outline: const Color(0xFF2E3A38),
    surfaceVariant: const Color(0xFF1D2422),
    onSurfaceVariant: Colors.white70,
    tertiary: brandCoral,
    onTertiary: Colors.white,
  );

  return base.copyWith(
    colorScheme: scheme,
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: const Color(0xFF1E2423),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.2),
      ),
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF1A201F),
      elevation: 1,
      shadowColor: Colors.black54,
    ),
  );
}
