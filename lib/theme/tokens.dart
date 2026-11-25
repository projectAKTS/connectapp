import 'package:flutter/material.dart';

class AppColors {
  // Design D "Paper & Clay": paper page, graphite text, one clay accent.
  static const primary = Color(0xFF22211F); // graphite

  /// The one accent: active tab, Helpful, small highlights. Never large.
  static const accent = Color(0xFFB4694A); // clay

  /// Clay text on light surfaces.
  static const accentText = Color(0xFF8E4E33);

  /// Selected chips and options: faint clay tint, graphite border.
  static const selected = Color(0xFFF3E9E3);
  static const selectedBorder = Color(0x7322211F); // primary at 45%

  // Core surfaces: soft paper, cards barely lighter, no shadows.
  static const canvas = Color(0xFFF8F7F4); // paper
  static const card   = Color(0xFFFDFCFA);
  static const postCard = card;
  static const button = Color(0xFFEFEDE8);
  static const surface = canvas;
  static const surfaceTonal = button;

  // Text
  static const text  = Color(0xFF22211F);
  static const muted = Color(0xFF75726C);

  // Lines / borders
  static const border = Color(0xFFE7E4DE);

  // Semantic
  static const danger = Color(0xFFC0504A);

  // Chips / Avatar defaults
  static const chip = button;

  static const avatarBg = Color(0xFFEFEDE8);
  static const avatarFg = muted;

  // Pills (for PillButton, etc.)
  static const pillBg   = button;
  static const pillIcon = muted;
}

/// Display face for headings and big numbers: the system sans. The name stays
/// so call sites need no change.
class AppFonts {
  static const serif = 'SF Pro';
  static const serifFallback = <String>[];
  static const displayWeight = FontWeight.w600;
}

class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
}

class AppShadows {
  static const soft = BoxShadow(
    color: Color(0x00000000), // design D is flat: no shadows
    blurRadius: 26,
    offset: Offset(0, 12),
    spreadRadius: -6,
  );
}

@Deprecated('Use AppShadows.soft instead')
class AppShadow {
  static const soft = AppShadows.soft;
}
