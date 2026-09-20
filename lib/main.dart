// © 2025 Pankaj Roy (Uchiha-Itachi001). All rights reserved.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'core/app_colors.dart';
import 'core/app_theme.dart';
import 'providers/app_state.dart';
import 'services/notification_service.dart';
import 'startup/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise SQLite FFI for Windows / Linux desktop
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await windowManager.ensureInitialized();
  await NotificationService.init();

  const minSize = Size(800, 600);

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

  // ─── Suppress known Flutter Windows keyboard state assertion ───────────────
  // Flutter on Windows sometimes fires duplicate KeyDownEvent for modifier keys
  // (Alt, Ctrl, Shift) when focus changes. This causes a failed assertion in
  // HardwareKeyboard that crashes the app in debug mode. It is a Flutter
  // framework bug and safe to ignore — the key event is simply dropped.
  FlutterError.onError = (FlutterErrorDetails details) {
    final msg = details.exceptionAsString();
    if (msg.contains('physical key is already pressed') ||
        msg.contains('_pressedKeys.containsKey') ||
        msg.contains('HardwareKeyboard')) {
      return; // swallow — known Flutter Windows keyboard race
    }
    FlutterError.presentError(details);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    if (error is AssertionError) {
      final msg = error.message?.toString() ?? error.toString();
      if (msg.contains('physical key is already pressed') ||
          msg.contains('_pressedKeys.containsKey')) {
        return true; // handled — swallow silently
      }
    }
    return false; // let other errors propagate
  };

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