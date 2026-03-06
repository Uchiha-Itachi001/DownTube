import 'package:DownTube/loading_screen.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'YouTube Downloader',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: MaterialColor(0xFF00FF41, {
          50: const Color(0xFFE8F5E8),
          100: const Color(0xFFC8E6C8),
          200: const Color(0xFFA4D4A4),
          300: const Color(0xFF7FC27F),
          400: const Color(0xFF64B664),
          500: const Color(0xFF00FF41),
          600: const Color(0xFF00E63B),
          700: const Color(0xFF00CC33),
          800: const Color(0xFF00B32B),
          900: const Color(0xFF009922),
        }),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardColor: const Color(0xFF1A1A1A),
        dialogBackgroundColor: const Color(0xFF1A1A1A),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          titleMedium: TextStyle(color: Color(0xFFE0E0E0), fontSize: 14),
          bodyMedium: TextStyle(color: Color(0xFFB0B0B0)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00FF41),
            foregroundColor: const Color(0xFF0A0A0A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            elevation: 8,
            shadowColor: const Color(0xFF00FF41).withOpacity(0.3),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF00FF41)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF333333)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00FF41), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF333333)),
          ),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: const TextStyle(color: Colors.white),
          menuStyle: MenuStyle(
            backgroundColor: MaterialStateProperty.all(const Color(0xFF1A1A1A)),
            elevation: MaterialStateProperty.all(8),
          ),
        ),
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF41),
          secondary: Color(0xFFFF6B00),
          tertiary: Color(0xFF9C27B0),
          surface: Color(0xFF1A1A1A),
          background: Color(0xFF0A0A0A),
          error: Color(0xFFFF1744),
        ),
      ),
      home: const LoadingScreen(),
    );
  }
}