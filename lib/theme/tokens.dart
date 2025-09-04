import 'package:flutter/material.dart';

/// ===== Global design tokens (colors, radii, shadows) =====
class AppColors {
  // Brand / accent
  static const primary = Color(0xFF0F4C46);

  // Core surfaces
  static const canvas = Color(0xFFFFFFFF); // app background (pure white)
  static const card   = Color(0xFFFFFFFF); // cards (pure white)

  /// Buttons / tappable pills (softer than taupe)
  /// Use this for: Connect, Find a helper, Book a consultation, search field fill, etc.
  static const button = Color(0xFFFAF8F6); // near-white, very soft

  /// Secondary neutral surface (chips, non-primary fills)
  static const surface = Color(0xFFF1ECE6); // warm taupe

  // Text
  static const text  = Color(0xFF2D2C2B);
  static const muted = Color(0xFF757370);

  // Lines / borders
  static const border = Color(0xFFF2EBE3);

  // Semantic
  static const danger = Color(0xFFD75A4A);

  // Small chips / avatar defaults
  static const chip = Color(0xFFF7F2EB);

  /// Neutral avatar colors (works on white + soft backgrounds)
  static const avatarBg = Color(0xFFE0DCD6);
  static const avatarFg = text;
}

class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
}

class AppShadows {
  /// Ultra-soft warm shadow for raised cards
  static const soft = BoxShadow(
    color: Color(0x0F6B5E55), // ~6% opacity
    blurRadius: 26,
    offset: Offset(0, 12),
    spreadRadius: -6,
  );
}

@Deprecated('Use AppShadows.soft instead')
class AppShadow {
  static const soft = AppShadows.soft;
}
