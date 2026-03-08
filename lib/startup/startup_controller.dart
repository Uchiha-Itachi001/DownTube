import 'package:flutter/material.dart';
import '../providers/app_state.dart';

enum StartupStage {
  checking,
  ytDlpMissing,
  locationNeeded,
  ready,
}

class StartupController extends ChangeNotifier {
  StartupStage stage = StartupStage.checking;
  String statusMessage = 'Initializing…';

  Future<void> run() async {
    stage = StartupStage.checking;
    statusMessage = 'Initializing engine…';
    notifyListeners();

    // Small delay so the splash ring animation is visible
    await Future.delayed(const Duration(milliseconds: 700));

    statusMessage = 'Checking yt-dlp installation…';
    notifyListeners();

    await AppState.instance.init();

    if (!AppState.instance.ytDlpReady) {
      stage = StartupStage.ytDlpMissing;
      statusMessage = 'yt-dlp not found';
      notifyListeners();
      return;
    }

    statusMessage = 'Loading download history…';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 200));

    statusMessage = 'Checking download location…';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));

    final path = AppState.instance.downloadPath;
    if (path == null || path.isEmpty) {
      stage = StartupStage.locationNeeded;
      statusMessage = 'Select a download folder';
      notifyListeners();
      return;
    }

    stage = StartupStage.ready;
    statusMessage = 'All systems ready';
    notifyListeners();
  }

  Future<void> markLocationSet(String path) async {
    await AppState.instance.setDownloadPath(path);
    stage = StartupStage.ready;
    statusMessage = 'All systems ready';
    notifyListeners();
  }

  Future<void> retryAfterYtDlpSet(String execPath) async {
    await AppState.instance.setYtDlpPath(execPath);
    if (AppState.instance.ytDlpReady) {
      // Continue the startup check from where we left off
      statusMessage = 'Checking download location…';
      stage = StartupStage.checking;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));

      final path = AppState.instance.downloadPath;
      if (path == null || path.isEmpty) {
        stage = StartupStage.locationNeeded;
        statusMessage = 'Select a download folder';
      } else {
        stage = StartupStage.ready;
        statusMessage = 'All systems ready';
      }
      notifyListeners();
    }
  }
}
