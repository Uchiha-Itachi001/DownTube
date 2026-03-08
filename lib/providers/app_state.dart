import 'package:flutter/material.dart';
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
      if (json == null) throw Exception('No metadata returned from yt-dlp');
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
    final String formatSelector;
    if (res.endsWith('k')) {
      final kbps = res.replaceAll('k', '');
      formatSelector = 'ba[abr<=$kbps]';
    } else {
      final h = res.replaceAll('p', '').replaceAll('K', '').replaceAll('4', '2160');
      formatSelector = 'bv[height<=$h]+ba/best';
    }

    final outputTmpl =
        '${item.outputPath}\\%(title)s.%(ext)s';

    try {
      await for (final line in ytDlp.startDownload(
        url: item.url,
        formatSelector: formatSelector,
        outputTemplate: outputTmpl,
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
