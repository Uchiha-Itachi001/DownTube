import 'dart:async';
import 'dart:io';

/// Lightweight one-shot connectivity check.
/// Does NOT poll continuously — call only when an outgoing network operation
/// is about to happen (video fetch, download start).
class ConnectivityService {
  /// Returns true if the device can reach the internet.
  /// Performs a DNS lookup with a 3-second timeout.
  static Future<bool> isOnline() async {
    try {
      final result = await InternetAddress.lookup('www.google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }
}
