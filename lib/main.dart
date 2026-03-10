import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'core/app_colors.dart';
import 'core/app_theme.dart';
import 'providers/app_state.dart';
import 'startup/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise SQLite FFI for Windows / Linux desktop
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await windowManager.ensureInitialized();

  const minSize = Size(700, 600);

  await windowManager.waitUntilReadyToShow(
    WindowOptions(
      minimumSize: minSize,
      size: const Size(1200, 760),
      center: true,
      backgroundColor: const Color(0xFF0B0B0D),
      titleBarStyle: TitleBarStyle.normal,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'DownTube',
          theme: AppTheme.forAccent(AppColors.accent),
          home: const SplashScreen(),
        );
      },
    );
  }
}