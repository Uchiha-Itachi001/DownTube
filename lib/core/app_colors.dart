import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bg = Color(0xFF0B0B0D);
  static const Color surface1 = Color(0xFF080C09);
  static const Color surface2 = Color(0xFF17171B);
  static const Color surface3 = Color(0xFF1E1E24);

  // Borders
  static const Color border = Color(0x12FFFFFF); // rgba(255,255,255,0.07)

  // Static green (kept const for legacy/const-widget compatibility)
  static const Color green = Color(0xFF22C55E);
  static const Color greenDim = Color(0x1F22C55E); // rgba(34,197,94,0.12)
  static const Color greenGlow = Color(0x4022C55E); // rgba(34,197,94,0.25)
  static const Color green2 = Color(0xFF16A34A);

  // Dynamic accent color (changes with user theme selection)
  static Color accent = const Color(0xFF22C55E);
  static Color get accentDim =>
      accent.withValues(alpha: 0.12);
  static Color get accentGlow =>
      accent.withValues(alpha: 0.25);

  // Status Colors
  static const Color red = Color(0xFFEF4444);
  static const Color yellow = Color(0xFFF59E0B);
  static const Color blue = Color(0xFF3B82F6);

  // Text
  static const Color text = Color(0xFFF1F1F3);
  static const Color muted = Color(0xFF52525B);
  static const Color muted2 = Color.fromARGB(255, 108, 108, 119);

  // Transparent surfaces (dark with ~60% transparency for glass effect)
  static Color get surfaceTransparent =>
      const Color(0xFF0D0F10).withOpacity(0.40);
  static Color get surfaceTransparent2 =>
      const Color(0xFF17171B).withOpacity(0.40);

  // Radius
  static const double radius = 16.0;
  static const double gap = 10.0;

  // Available theme accent colors
  static const List<({String name, Color color})> themeOptions = [
    (name: 'Green', color: Color(0xFF22C55E)),
    (name: 'Blue', color: Color(0xFF3B82F6)),
    (name: 'Purple', color: Color(0xFFA855F7)),
    (name: 'Orange', color: Color(0xFFF97316)),
    (name: 'Red', color: Color(0xFFEF4444)),
    (name: 'Pink', color: Color(0xFFEC4899)),
    (name: 'Cyan', color: Color(0xFF06B6D4)),
    (name: 'Amber', color: Color(0xFFF59E0B)),
    (name: 'Lime', color: Color(0xFF84CC16)),
    (name: 'Teal', color: Color(0xFF14B8A6)),
    (name: 'Indigo', color: Color(0xFF6366F1)),
    (name: 'Rose', color: Color(0xFFF43F5E)),
  ];
}
