import 'dart:async';
import 'dart:io';
import 'dart:convert';

class YtDlpService {
  String? _execPath;
  final Map<String, Process> _activeDownloads = {};
  Process? _playlistStreamProcess;

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

  /// Fetch the latest yt-dlp release tag from GitHub.
  /// Returns the version string (e.g. "2024.12.17") or null on failure.
  Future<String?> checkLatestVersion() async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client
          .getUrl(Uri.parse(
            'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest',
          ))
          .timeout(const Duration(seconds: 15));
      request.headers.set('User-Agent', 'DownTube-App');
      request.headers.set('Accept', 'application/vnd.github+json');
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final tag = json['tag_name'] as String?;
        if (tag != null) {
          // GitHub tags for yt-dlp are like "2024.12.17" (no "v" prefix)
          return tag.replaceFirst(RegExp(r'^v'), '');
        }
      }
    } catch (_) {
      // Network unavailable or API failure — ignore silently
    } finally {
      client?.close(force: false);
    }
    return null;
  }

  /// Download the latest yt-dlp.exe from GitHub releases to [targetPath].
  /// Calls [onProgress] with bytes received / total bytes (total may be -1
  /// when the server doesn't send Content-Length).
  /// Returns true on success.
  Future<bool> downloadLatest(
    String targetPath, {
    void Function(int received, int total)? onProgress,
  }) async {
    HttpClient? client;
    try {
      // Ensure the parent directory exists
      final dir = Directory(File(targetPath).parent.path);
      if (!await dir.exists()) await dir.create(recursive: true);

      client = HttpClient();
      // GitHub releases redirect to a CDN — follow redirects
      final request = await client
          .getUrl(Uri.parse(
            'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe',
          ))
          .timeout(const Duration(seconds: 30));
      request.followRedirects = true;
      request.maxRedirects = 5;
      request.headers.set('User-Agent', 'DownTube-App');
      final response = await request.close();

      if (response.statusCode != 200) return false;

      final total = response.contentLength; // -1 if unknown
      int received = 0;

      // Write to a temp file first so a partial download never replaces a
      // working binary.
      final tmpPath = '$targetPath.download';
      final sink = File(tmpPath).openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      // Atomically replace the target
      if (await File(targetPath).exists()) await File(targetPath).delete();
      await File(tmpPath).rename(targetPath);

      // Update cached exec path
      _execPath = targetPath;
      return true;
    } catch (_) {
      // Clean up temp file if present
      try { await File('$targetPath.download').delete(); } catch (_) {}
      return false;
    } finally {
      client?.close(force: false);
    }
  }

  /// Returns the canonical install path for the bundled yt-dlp.exe.
  /// This is %APPDATA%\DownTube\yt-dlp.exe on Windows.
  static String get defaultInstallPath {
    final appData = Platform.environment['APPDATA'] ?? '.';
    return '$appData\\DownTube\\yt-dlp.exe';
  }

  Future<Map<String, dynamic>?> fetchMetadata(String url) async {
    if (_execPath == null) return null;

    final process = await Process.start(
      _execPath!,
      ['-J', '--no-warnings', '--no-playlist', '--remote-components', 'ejs:github', url],
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

  /// Quick info: fetches only first playlist item to detect type fast (1-3 sec).
  /// For single videos returns the full video JSON.
  /// For playlists returns the playlist envelope with 1 entry + metadata fields.
  Future<Map<String, dynamic>?> fetchQuickInfo(String url) async {
    if (_execPath == null) return null;

    final process = await Process.start(
      _execPath!,
      [
        '--flat-playlist', '--playlist-items', '1', '-J',
        '--no-warnings', '--remote-components', 'ejs:github', url,
      ],
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

  /// Streams all flat playlist entries one-by-one as yt-dlp discovers them.
  /// Each emitted map is a single playlist entry JSON (with playlist metadata fields).
  Stream<Map<String, dynamic>> streamFlatPlaylist(String url) async* {
    if (_execPath == null) return;

    final process = await Process.start(
      _execPath!,
      [
        '--flat-playlist', '-j',
        '--no-warnings', '--remote-components', 'ejs:github', url,
      ],
      runInShell: false,
    );
    _playlistStreamProcess = process;

    try {
      await for (final line in process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        try {
          yield json.decode(line) as Map<String, dynamic>;
        } catch (_) {}
      }
    } finally {
      _playlistStreamProcess = null;
    }
  }

  /// Kill any in-progress playlist stream (called on resetFetch).
  void killPlaylistStream() {
    _playlistStreamProcess?.kill();
    _playlistStreamProcess = null;
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
        '--remote-components', 'ejs:github',
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
        '--remote-components', 'ejs:github',
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
      // Verify yt-dlp exited cleanly — non-zero means the download was
      // interrupted (network dropped, server error, yt-dlp crash).
      final ec = await process.exitCode;
      if (ec != 0) {
        throw Exception(
          'yt-dlp exited with code $ec. The download was interrupted '
          '(network dropped or server error).',
        );
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

// yt-dlp error message parser
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
