import 'package:flutter/material.dart';

class AppColors {
  // Brand / accent
  static const primary = Color(0xFF0F4C46);

  // Core surfaces
  static const canvas = Color(0xFFFFFFFF); // Pure White background
  static const card   = Color(0xFFFBFAF8); // Ultra-white Card
  static const button = Color(0xFFF7F5F2); // Soft Surface
  static const surface = button;
  static const surfaceTonal = button;

  // Text
  static const text  = Color(0xFF2D2C2B);
  static const muted = Color(0xFF757370);

  // Lines / borders
  static const border = Color(0xFFEFEAE3);

  // Semantic
  static const danger = Color(0xFFD75A4A);

  // Chips / Avatar defaults
  static const chip = button; // 🔹 fix: alias to button so HomeScreen works
  static const avatarBg = Color(0xFFE6E1DA);
  static const avatarFg = text;
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
