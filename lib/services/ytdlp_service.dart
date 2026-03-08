import 'dart:async';
import 'dart:io';
import 'dart:convert';

class YtDlpService {
  String? _execPath;
  final Map<String, Process> _activeDownloads = {};

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

    final errText = utf8.decode(stderr, allowMalformed: true).trim();
    throw Exception(_friendlyYtDlpError(errText, exitCode));
  }

  Stream<String> startDownload({
    required String id,
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
      args = [
        '-f', formatSelector,
        '-x',
        '--audio-format', outputFormat,
        '--audio-quality', audioQuality,
        '-o', outputTemplate,
        '--no-playlist',
        '--no-warnings',
        '--force-overwrites',
        url,
      ];
    } else {
      args = [
        '-f', formatSelector,
        '--merge-output-format', outputFormat,
        '-o', outputTemplate,
        '--no-playlist',
        '--no-warnings',
        '--force-overwrites',
        url,
      ];
    }

    final process = await Process.start(_execPath!, args, runInShell: false);
    _activeDownloads[id] = process;
    try {
      // Merge stdout and stderr so phase/progress lines from either stream
      // are delivered in real-time during the download.
      final controller = StreamController<String>();
      int openStreams = 2;
      void onDone() {
        openStreams--;
        if (openStreams == 0) controller.close();
      }
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(controller.add, onError: controller.addError, onDone: onDone);
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(controller.add, onError: controller.addError, onDone: onDone);
      await for (final line in controller.stream) {
        yield line;
      }
    } finally {
      _activeDownloads.remove(id);
    }
  }

  /// Kill an active download by item id.
  /// On Windows, kills the entire process tree (including ffmpeg subprocesses).
  void killDownload(String id) {
    final process = _activeDownloads.remove(id);
    if (process == null) return;
    if (Platform.isWindows) {
      // taskkill /F (force) /T (tree) kills yt-dlp and any ffmpeg children
      Process.run('taskkill', ['/F', '/T', '/PID', '${process.pid}']);
    } else {
      process.kill(ProcessSignal.sigterm);
    }
  }
}

// ── yt-dlp error message parser ──────────────────────────────────────────────

String _friendlyYtDlpError(String stderr, int exitCode) {
  if (exitCode == -1) {
    return 'Request timed out. Check your internet connection.';
  }
  if (stderr.contains('Sign in to confirm') ||
      stderr.contains('not a bot') ||
      stderr.contains('cookies')) {
    return 'YouTube cookie authentication required.\n\n'
        'yt-dlp was blocked by YouTube\'s bot-check. This is a YouTube restriction, not a bug.\n\n'
        'Fix: Export cookies from Chrome or Firefox and point yt-dlp to the cookies.txt file.\n'
        'Guide: yt-dlp wiki → Extractors → Exporting YouTube Cookies';
  }
  if (stderr.contains('Video unavailable') ||
      stderr.contains('This video is not available')) {
    return 'This video is unavailable or private.';
  }
  if (stderr.contains('HTTP Error 429') ||
      stderr.contains('Too Many Requests')) {
    return 'YouTube is rate-limiting yt-dlp. Wait a few minutes then try again.';
  }
  if (stderr.contains('Unsupported URL') ||
      stderr.contains('Unable to extract')) {
    return 'This URL is not supported. Make sure it is a valid video link.';
  }
  // Extract the ERROR: line from yt-dlp output
  for (final line in stderr.split('\n')) {
    final t = line.trim();
    if (t.startsWith('ERROR:')) {
      final msg = t
          .replaceFirst('ERROR:', '')
          .trim()
          .replaceFirst(RegExp(r'^\[.*?\]\s*\S+:\s*'), '');
      if (msg.isNotEmpty) return msg;
    }
  }
  if (stderr.isNotEmpty) {
    final short = stderr.length > 300 ? '${stderr.substring(0, 300)}...' : stderr;
    return 'yt-dlp failed:\n$short';
  }
  return 'yt-dlp could not fetch video info. Try updating yt-dlp.';
}
