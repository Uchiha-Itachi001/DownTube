import 'package:flutter/material.dart';
import 'dart:io';
import '../models/video_info.dart';
import '../models/download_item.dart';
import '../services/prefs_service.dart';
import '../services/ytdlp_service.dart';

enum FetchState { idle, loading, success, error }

class AppState extends ChangeNotifier {
  static final AppState instance = AppState._();
  AppState._();

  // ── Services ──────────────────────────────────────────────────────────────
  PrefsService? _prefs;
  final YtDlpService ytDlp = YtDlpService();

  // ── Engine status ─────────────────────────────────────────────────────────
  bool ytDlpReady = false;
  String? ytDlpVersion;
  String? downloadPath;

  // ── Video fetch state ─────────────────────────────────────────────────────
  FetchState fetchState = FetchState.idle;
  VideoInfo? videoInfo;
  String? fetchError;
  String? currentUrl;

  // ── Downloads ─────────────────────────────────────────────────────────────
  final List<DownloadItem> downloads = [];

  // ── Initialisation ────────────────────────────────────────────────────────
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _prefs = await PrefsService.create();
    downloadPath = _prefs!.downloadPath;

    ytDlpReady =
        await ytDlp.detectPath(savedPath: _prefs!.ytDlpPath);
    if (ytDlpReady) {
      ytDlpVersion = await ytDlp.getVersion();
    }
    notifyListeners();
  }

  // ── Fetch video ───────────────────────────────────────────────────────────
  Future<void> fetchVideo(String url) async {
    currentUrl = url;
    fetchState = FetchState.loading;
    videoInfo = null;
    fetchError = null;
    notifyListeners();

    try {
      final json = await ytDlp.fetchMetadata(url);
      if (json == null) {
        throw Exception(
          'yt-dlp could not fetch video info.\n'
          'Try: update yt-dlp, install Node.js, or sign in to YouTube in Chrome/Firefox.',
        );
      }
      videoInfo = VideoInfo.fromYtDlpJson(json);
      fetchState = FetchState.success;
    } catch (e) {
      fetchError = e.toString().replaceFirst('Exception: ', '');
      fetchState = FetchState.error;
    }
    notifyListeners();
  }

  void resetFetch() {
    fetchState = FetchState.idle;
    videoInfo = null;
    fetchError = null;
    currentUrl = null;
    notifyListeners();
  }

  // ── Downloads ─────────────────────────────────────────────────────────────
  void enqueueDownload(DownloadItem item) {
    downloads.insert(0, item);
    notifyListeners();
    _executeDownload(item);
  }

  Future<void> _executeDownload(DownloadItem item) async {
    item.status = DownloadStatus.downloading;
    notifyListeners();

    final res = item.resolution;
    final fmt = item.format.toLowerCase(); // e.g. 'mp4', 'mkv', 'webm', 'mp3'
    final String formatSelector;
    final String outputFormat;
    bool audioOnly = false;
    String audioQuality = '0';

    if (res.endsWith('k')) {
      // Audio download: use bestaudio and post-process with -x --audio-format
      // The quality tier maps directly to a bitrate for the output encoder.
      final kbps = int.tryParse(res.replaceAll('k', '')) ?? 320;
      formatSelector = 'bestaudio/best';
      outputFormat = fmt.isEmpty ? 'mp3' : fmt;
      audioOnly = true;
      // Map kbps to an audio-quality spec that yt-dlp/ffmpeg understand
      audioQuality = switch (kbps) {
        >= 320 => '320K',
        >= 192 => '192K',
        _ => '128K',
      };
    } else if (res == 'Best') {
      // "Best" tile — let yt-dlp pick the absolute best video+audio stream,
      // same behaviour as the original DownTube app.
      formatSelector = 'bestvideo+bestaudio/best';
      outputFormat = fmt.isEmpty ? 'mp4' : fmt;
    } else {
      // Video quality like '4K', '1080p', '720p', '480p', '360p', '240p', '144p'
      // NOTE: replaceAll('4','2160') would corrupt any height that contains
      // the digit 4 (1440p→12160, 480p→21608, 240p→22160).  Parse cleanly:
      final String heightStr = res == '4K' ? '2160' : res.replaceAll('p', '');
      formatSelector = 'bestvideo[height<=$heightStr]+bestaudio/best[height<=$heightStr]/best';
      outputFormat = fmt.isEmpty ? 'mp4' : fmt;
    }

    final String effectivePath = item.outputPath.isNotEmpty
        ? item.outputPath
        : '${Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.'}\\Videos\\DownTube';

    // Ensure output directory exists
    final dir = Directory(effectivePath);
    if (!await dir.exists()) await dir.create(recursive: true);

    final outputTmpl = '$effectivePath\\%(title)s.%(ext)s';

    try {
      await for (final line in ytDlp.startDownload(
        url: item.url,
        formatSelector: formatSelector,
        outputTemplate: outputTmpl,
        outputFormat: outputFormat,
        audioOnly: audioOnly,
        audioQuality: audioQuality,
      )) {
        if (line.contains('[download]') && line.contains('%')) {
          final pct = RegExp(r'(\d+\.?\d*)%').firstMatch(line);
          if (pct != null) {
            item.progress =
                (double.tryParse(pct.group(1)!) ?? (item.progress * 100)) /
                    100;
          }
          final spd = RegExp(r'at\s+(\S+/s)').firstMatch(line);
          if (spd != null) item.speed = spd.group(1);
          final eta = RegExp(r'ETA\s+(\S+)').firstMatch(line);
          if (eta != null) item.eta = eta.group(1);
          notifyListeners();
        }
      }
      item.status = DownloadStatus.done;
      item.progress = 1.0;
      item.speed = null;
      item.eta = null;
    } catch (e) {
      item.status = DownloadStatus.error;
      item.errorMessage = e.toString();
    }
    notifyListeners();
  }

  // ── Settings ──────────────────────────────────────────────────────────────
  Future<void> setDownloadPath(String path) async {
    downloadPath = path;
    await _prefs?.setDownloadPath(path);
    notifyListeners();
  }

  Future<void> setYtDlpPath(String path) async {
    await _prefs?.setYtDlpPath(path);
    final found = await ytDlp.detectPath(savedPath: path);
    ytDlpReady = found;
    if (found) ytDlpVersion = await ytDlp.getVersion();
    notifyListeners();
  }
}
