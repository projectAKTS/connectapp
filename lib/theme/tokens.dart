import 'package:flutter/material.dart';

class AppColors {
  // Brand / accent
  static const primary = Color(0xFF0F4C46);

  /// Warm accent, used sparingly: Helpful, highlights.
  static const accent = Color(0xFFE8915B);

  /// Selected chips and options: light green fill, green border and text.
  static const selected = Color(0xFFE3EFEC);
  static const selectedBorder = Color(0x730F4C46); // primary at 45%

  // Core surfaces: a warm off-white page so white cards stand out.
  static const canvas = Color(0xFFFAF8F5);
  static const card   = Color(0xFFFFFFFF);
  static const postCard = card;
  static const button = Color(0xFFF1EDE7); // Soft beige for pills/buttons
  static const surface = canvas;
  static const surfaceTonal = button;

  // Text
  static const text  = Color(0xFF2D2C2B);
  static const muted = Color(0xFF757370);

  // Lines / borders
  static const border = Color(0xFFEFEAE3);

  // Semantic
  static const danger = Color(0xFFD75A4A);

  // Chips / Avatar defaults
  static const chip = button;

  // Softer default avatar so it doesn’t shout on Home/Profile
  static const avatarBg = Color(0xFFF2EFE9); // lighter, closer to canvas
  static const avatarFg = muted;             // softer icon color

  // Pills (for PillButton, etc.)
  static const pillBg   = button;
  static const pillIcon = muted;
}

class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
}

class AppShadows {
  static const soft = BoxShadow(
    color: Color(0x106B5E55), // ~6% opacity
    blurRadius: 26,
    offset: Offset(0, 12),
    spreadRadius: -6,
  );
}

@Deprecated('Use AppShadows.soft instead')
class AppShadow {
  static const soft = AppShadows.soft;
}
