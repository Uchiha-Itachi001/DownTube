import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => forAccent(AppColors.accent);

  static ThemeData forAccent(Color accent) {
    final accentDark = Color.lerp(accent, Colors.black, 0.3) ?? accent;
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.surface1,
      cardColor: AppColors.surface1,
      dividerColor: AppColors.border,
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: accentDark,
        surface: AppColors.surface1,
        error: AppColors.red,
        onPrimary: Colors.black,
        onSurface: AppColors.text,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.dragged)) {
            return accent.withValues(alpha: 0.55);
          }
          return accent.withValues(alpha: 0.18);
        }),
        trackColor: WidgetStatePropertyAll(
          Colors.white.withValues(alpha: 0.03),
        ),
        trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
        thickness: const WidgetStatePropertyAll(4.0),
        radius: const Radius.circular(99),
        crossAxisMargin: 2,
        mainAxisMargin: 4,
      ),
      useMaterial3: true,
    );
  }
}
