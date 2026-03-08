import 'dart:io';
import 'dart:convert';

class YtDlpService {
  String? _execPath;

  String? get execPath => _execPath;

  /// Try to find yt-dlp: saved pref → %APPDATA%\DownTube\yt-dlp.exe → PATH
  Future<bool> detectPath({String? savedPath}) async {
    if (savedPath != null && savedPath.isNotEmpty) {
      if (await File(savedPath).exists()) {
        _execPath = savedPath;
        return true;
      }
    }

    // Windows default location
    final appData = Platform.environment['APPDATA'];
    if (appData != null) {
      final candidate = '$appData\\DownTube\\yt-dlp.exe';
      if (await File(candidate).exists()) {
        _execPath = candidate;
        return true;
      }
    }

    // PATH lookup
    try {
      final result = await Process.run(
        'where',
        ['yt-dlp'],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        final lines = (result.stdout as String)
            .trim()
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        if (lines.isNotEmpty) {
          _execPath = lines.first;
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  Future<String?> getVersion() async {
    if (_execPath == null) return null;
    try {
      final result = await Process.run(
        _execPath!,
        ['--version'],
        runInShell: false,
      );
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> fetchMetadata(String url) async {
    if (_execPath == null) return null;
    final result = await Process.run(
      _execPath!,
      ['--dump-json', '--no-playlist', url],
      runInShell: false,
    );
    if (result.exitCode == 0) {
      return json.decode(result.stdout as String) as Map<String, dynamic>;
    }
    return null;
  }

  Stream<String> startDownload({
    required String url,
    required String formatSelector,
    required String outputTemplate,
  }) async* {
    if (_execPath == null) return;
    final process = await Process.start(
      _execPath!,
      [
        '-f', formatSelector,
        '--merge-output-format', 'mp4',
        '-o', outputTemplate,
        '--no-playlist',
        url,
      ],
      runInShell: false,
    );
    await for (final line
        in process.stdout.transform(utf8.decoder).transform(const LineSplitter())) {
      yield line;
    }
  }
}
