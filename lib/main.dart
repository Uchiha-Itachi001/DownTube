import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'core/app_theme.dart';
import 'startup/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const minSize = Size(860, 560);

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DownTube',
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}