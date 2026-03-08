import 'dart:async';
import 'dart:io';
import 'dart:convert';

class YtDlpService {
  String? _execPath;

  String? get execPath => _execPath;

  /// Try to find yt-dlp: saved pref → %APPDATA%\DownTube\yt-dlp.exe → PATH
  Future<bool> detectPath({String? savedPath}) async {
    bool found = false;

    if (savedPath != null && savedPath.isNotEmpty) {
      if (await File(savedPath).exists()) {
        _execPath = savedPath;
        found = true;
      }
    }

    if (!found) {
      // Windows default location
      final appData = Platform.environment['APPDATA'];
      if (appData != null) {
        final candidate = '$appData\\DownTube\\yt-dlp.exe';
        if (await File(candidate).exists()) {
          _execPath = candidate;
          found = true;
        }
      }
    }

    if (!found) {
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
            found = true;
          }
        }
      } catch (_) {}
    }

    return found;
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

    try {
      final process = await Process.start(
        _execPath!,
        ['-J', '--no-warnings', '--no-playlist', url],
        runInShell: false,
      );

      final stdout = <int>[];
      final stderr = <int>[];
      process.stdout.listen(stdout.addAll);
      process.stderr.listen(stderr.addAll);

      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          process.kill();
          return -1;
        },
      );

      if (exitCode == 0) {
        final output = utf8.decode(stdout).trim();
        if (output.isNotEmpty) {
          try {
            return json.decode(output) as Map<String, dynamic>;
          } catch (_) {}
        }
      }
    } catch (_) {}
    return null;
  }

  Stream<String> startDownload({
    required String url,
    required String formatSelector,
    required String outputTemplate,
    String outputFormat = 'mp4',
    bool audioOnly = false,
    String audioQuality = '0',
  }) async* {
    if (_execPath == null) return;

    final List<String> args;
    if (audioOnly) {
      // Use -x (extract audio) with --audio-format and --audio-quality
      // for proper audio conversion (mp3/wav/flac at the chosen bitrate).
      args = [
        '-f', formatSelector,
        '-x',
        '--audio-format', outputFormat,
        '--audio-quality', audioQuality,
        '-o', outputTemplate,
        '--no-playlist',
        '--no-warnings',
        url,
      ];
    } else {
      args = [
        '-f', formatSelector,
        '--merge-output-format', outputFormat,
        '-o', outputTemplate,
        '--no-playlist',
        '--no-warnings',
        url,
      ];
    }

    final process = await Process.start(_execPath!, args, runInShell: false);
    await for (final line
        in process.stdout.transform(utf8.decoder).transform(const LineSplitter())) {
      yield line;
    }
    // Also stream stderr so progress lines emitted there are captured
    await for (final line
        in process.stderr.transform(utf8.decoder).transform(const LineSplitter())) {
      yield line;
    }
  }
}
