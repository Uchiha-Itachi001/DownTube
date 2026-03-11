import 'dart:io';
import 'package:local_notifier/local_notifier.dart';

/// Wraps [local_notifier] for Windows native toast notifications.
/// Call [init] once at app startup, then [notifyDone] / [notifyError] as needed.
class NotificationService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (!Platform.isWindows) return;
    try {
      await localNotifier.setup(appName: 'DownTube');
      _initialized = true;
    } catch (_) {}
  }

  static Future<void> notifyDone(String title) async {
    if (!_initialized) return;
    try {
      final n = LocalNotification(
        identifier: 'done_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Download Complete',
        body: title,
      );
      await n.show();
    } catch (_) {}
  }

  static Future<void> notifyError(String title, {String? reason}) async {
    if (!_initialized) return;
    try {
      final n = LocalNotification(
        identifier: 'err_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Download Failed',
        body: reason != null ? '$title — $reason' : title,
      );
      await n.show();
    } catch (_) {}
  }
}
