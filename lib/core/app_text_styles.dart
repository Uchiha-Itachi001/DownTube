import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // Syne - headings, bold UI text
  static TextStyle syne({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w700,
    Color color = AppColors.text,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.syne(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Outfit - body, labels, UI text
  static TextStyle outfit({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.text,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.outfit(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Space Grotesk - quality badges, technical numbers, data labels
  static TextStyle spaceGrotesk({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w700,
    Color color = AppColors.text,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // JetBrains Mono - file sizes, bitrates, technical data values
  static TextStyle mono({
    double fontSize = 11,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.text,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Pre-built styles
  static TextStyle get heroTitle => syne(
        fontSize: 38,
        fontWeight: FontWeight.w800,
        height: 1.15,
      );

  static TextStyle get sectionTitle => syne(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get logoText => syne(
        fontSize: 15,
        fontWeight: FontWeight.w800,
      );

  static TextStyle get bodyText => outfit(
        fontSize: 13,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get labelSmall => outfit(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
      );

  static TextStyle get navGroupLabel => outfit(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
        letterSpacing: 1.5,
      );

  static TextStyle get statValue => syne(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.green,
      );

  static TextStyle get bigStatValue => syne(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.green,
      );
}
