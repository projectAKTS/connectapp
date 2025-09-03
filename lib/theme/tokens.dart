import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF0F4C46); // evergreen

  // Backgrounds
  static const canvas  = Color(0xFFFFFFFF); // ✅ pure white everywhere
  static const card    = Color(0xFFFFFFFF); // post cards also pure white
  static const surface = Color(0xFFF0EAE3); // taupe pills/buttons

  // Text
  static const text  = Color(0xFF2D2C2B);
  static const muted = Color(0xFF757370);

  // Lines
  static const border = Color(0xFFF0EAE3);

  // Semantic
  static const danger = Color(0xFFD75A4A);

  // Small chip (top-right profile)
  static const chip = Color(0xFFF7F2EB);
  static const mintChip = chip;
}

class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const xl = 28.0;
}

class AppShadows {
  static const soft = BoxShadow(
    color: Color(0x0A6B5E55), // ~6% opacity warm gray
    blurRadius: 30,
    offset: Offset(0, 12),
    spreadRadius: -6,
  );
}

@Deprecated('Use AppShadows.soft instead')
class AppShadow {
  static const soft = AppShadows.soft;
}
