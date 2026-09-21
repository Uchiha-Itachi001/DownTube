import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/app_version.dart';

/// Handles GitHub release checking and installer download for DownTube app updates.
class AppUpdateService {
  static const String _repo = 'Uchiha-Itachi001/DownTube';
  static const String _apiUrl =
      'https://api.github.com/repos/$_repo/releases/latest';

  /// Returns the latest release tag from GitHub (e.g. "2.8.0"), or null on failure.
  /// Retries up to [maxRetries] times with a 2-second gap.
  Future<String?> checkLatestVersion({int maxRetries = 3}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 8);
        final req = await client.getUrl(Uri.parse(_apiUrl));
        req.headers.set('User-Agent', 'DownTube-App');
        req.headers.set('Accept', 'application/vnd.github.v3+json');
        final res = await req.close().timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) {
          client.close();
          await _delay(attempt);
          continue;
        }
        final body = await res.transform(utf8.decoder).join();
        client.close();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final tag = (json['tag_name'] as String?)?.replaceAll(RegExp(r'^v'), '');
        if (tag != null && tag.isNotEmpty) return tag;
      } catch (_) {
        // Network error — retry
      }
      await _delay(attempt);
    }
    return null; // all retries failed — silently ignored
  }

  /// Returns the browser_download_url for [_assetName] in the latest release,
  /// or null if not found / network failure.
  Future<String?> getReleaseAssetUrl({int maxRetries = 3}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 8);
        final req = await client.getUrl(Uri.parse(_apiUrl));
        req.headers.set('User-Agent', 'DownTube-App');
        req.headers.set('Accept', 'application/vnd.github.v3+json');
        final res = await req.close().timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) {
          client.close();
          await _delay(attempt);
          continue;
        }
        final body = await res.transform(utf8.decoder).join();
        client.close();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final assets = json['assets'] as List<dynamic>? ?? [];
        for (final asset in assets) {
          final m = asset as Map<String, dynamic>;
          if (m['name'] == AppVersion.installerAssetName) {
            return m['browser_download_url'] as String?;
          }
        }
      } catch (_) {
        // Network error — retry
      }
      await _delay(attempt);
    }
    return null;
  }

  /// Downloads the installer from [url] to [savePath], reporting byte-level
  /// progress via [onProgress(received, total)].
  /// Returns true on success, false on any error.
  Future<bool> downloadInstaller(
    String url,
    String savePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final file = File(savePath);
      final sink = file.openWrite();
      final client = HttpClient();

      // Follow up to 5 redirects (GitHub uses redirects for release assets)
      HttpClientResponse? res;
      var currentUrl = url;
      for (int r = 0; r < 5; r++) {
        final req = await client.getUrl(Uri.parse(currentUrl));
        req.headers.set('User-Agent', 'DownTube-App');
        res = await req.close();
        if (res.statusCode == 301 ||
            res.statusCode == 302 ||
            res.statusCode == 307 ||
            res.statusCode == 308) {
          currentUrl = res.headers.value('location') ?? currentUrl;
          await res.drain<void>();
          continue;
        }
        break;
      }

      if (res == null || res.statusCode != 200) {
        await sink.close();
        client.close();
        return false;
      }

      final total = res.contentLength; // -1 if unknown
      int received = 0;

      await for (final chunk in res) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total > 0 ? total : received);
      }

      await sink.flush();
      await sink.close();
      client.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _delay(int attempt) async {
    if (attempt < 2) await Future.delayed(const Duration(seconds: 2));
  }
}
