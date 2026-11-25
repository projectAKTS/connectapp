import 'package:flutter/material.dart';

class AppColors {
  // Design B "Ink & Sage": ink black, quiet sage, cool porcelain.
  static const primary = Color(0xFF1B1E23); // ink

  /// Quiet accent, used sparingly: Helpful, highlights.
  static const accent = Color(0xFF8A9A86); // sage

  /// Sage text on light surfaces (accent is too light for small text).
  static const accentText = Color(0xFF4E5F4D);

  /// Selected chips and options: sage tint, ink border and text.
  static const selected = Color(0xFFE4EAE2);
  static const selectedBorder = Color(0x731B1E23); // primary at 45%

  // Core surfaces: a cool porcelain page so near-white cards stand out.
  static const canvas = Color(0xFFF1F1EE); // porcelain
  static const card   = Color(0xFFFAFAF8);
  static const postCard = card;
  static const button = Color(0xFFE5E6E1); // stone, for pills/buttons
  static const surface = canvas;
  static const surfaceTonal = button;

  // Text
  static const text  = Color(0xFF15171A);
  static const muted = Color(0xFF6A6D71);

  // Lines / borders
  static const border = Color(0xFFE1E2DD);

  // Semantic
  static const danger = Color(0xFFC2554A);

  // Chips / Avatar defaults
  static const chip = button;

  static const avatarBg = Color(0xFFE2E7DF); // sage-grey
  static const avatarFg = muted;

  // Pills (for PillButton, etc.)
  static const pillBg   = button;
  static const pillIcon = muted;
}

/// Display face for headings and big numbers. Design B uses the system sans
/// with tight tracking; the name stays so call sites need no change.
class AppFonts {
  static const serif = 'SF Pro';
  static const serifFallback = <String>[];
  static const displayWeight = FontWeight.w600;
}

class AppRadius {
  static const sm = 14.0;
  static const md = 20.0;
  static const lg = 26.0;
  static const xl = 32.0;
}

class AppShadows {
  static const soft = BoxShadow(
    color: Color(0x1415171A), // ~8% ink
    blurRadius: 26,
    offset: Offset(0, 12),
    spreadRadius: -6,
  );
}

@Deprecated('Use AppShadows.soft instead')
class AppShadow {
  static const soft = AppShadows.soft;
}
