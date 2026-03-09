import 'package:flutter/material.dart';
import 'dart:io';
import '../models/video_info.dart';
import '../models/download_item.dart';
import '../services/prefs_service.dart';
import '../services/ytdlp_service.dart';
import '../services/download_db.dart';

enum FetchState { idle, loading, success, error }

// ── Phase notifications (consumed by UI to show overlay cards) ────────────────

enum DownloadNotifType { videoPhase, audioPhase, mergeDone }

class DownloadNotification {
  final String message;
  final String? subtitle;
  final DownloadNotifType type;
  const DownloadNotification({
    required this.message,
    this.subtitle,
    required this.type,
  });
}

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

  // ── Phase notifications (UI drains this queue after notifyListeners) ───────
  final List<DownloadNotification> pendingNotifications = [];

  List<DownloadNotification> drainNotifications() {
    if (pendingNotifications.isEmpty) return const [];
    final out = List<DownloadNotification>.from(pendingNotifications);
    pendingNotifications.clear();
    return out;
  }

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

    // Load persisted download history from SQLite
    await _loadHistory();

    // Auto-clean records whose files were deleted from disk
    await cleanMissingFiles();

    notifyListeners();
  }

  Future<void> _loadHistory() async {
    try {
      final saved = await DownloadDb.loadAndClean();
      // Only add records whose id isn’t already in the in-memory list
      final existingIds = downloads.map((d) => d.id).toSet();
      for (final item in saved) {
        if (!existingIds.contains(item.id)) downloads.add(item);
      }
    } catch (_) {
      // First install or DB error — continue with empty history
    }
  }
  /// Reload completed/history items from DB (used by the refresh button).
  Future<void> refreshFromDb() async {
    try {
      final saved = await DownloadDb.loadAndClean();
      // Replace all non-active items with fresh DB data
      final activeIds = downloads
          .where((d) =>
              d.status == DownloadStatus.downloading ||
              d.status == DownloadStatus.queued)
          .map((d) => d.id)
          .toSet();
      downloads.removeWhere((d) => !activeIds.contains(d.id));
      final existingIds = downloads.map((d) => d.id).toSet();
      for (final item in saved) {
        if (!existingIds.contains(item.id)) downloads.add(item);
      }
      notifyListeners();
    } catch (_) {}
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
        throw Exception('yt-dlp engine not found. Install yt-dlp and restart the app.');
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
    item.phase = DownloadPhase.video;
    notifyListeners();

    final res = item.resolution;
    final fmt = item.format.toLowerCase(); // e.g. 'mp4', 'mkv', 'webm', 'mp3'
    final String formatSelector;
    final String outputFormat;
    bool audioOnly = false;
    String audioQuality = '0';

    if (res.endsWith('k')) {
      // Audio download: use bestaudio and post-process with -x --audio-format
      final kbps = int.tryParse(res.replaceAll('k', '')) ?? 320;
      formatSelector = 'bestaudio/best';
      outputFormat = fmt.isEmpty ? 'mp3' : fmt;
      audioOnly = true;
      audioQuality = switch (kbps) {
        >= 320 => '320K',
        >= 192 => '192K',
        _ => '128K',
      };
    } else if (res == 'Best') {
      formatSelector = 'bestvideo+bestaudio/best';
      outputFormat = fmt.isEmpty ? 'mp4' : fmt;
    } else {
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

    // Append numeric suffix for re-downloads so filenames don't clash
    final suffix = item.downloadIndex > 0 ? ' (${item.downloadIndex})' : '';
    final outputTmpl = '$effectivePath\\%(title)s$suffix.%(ext)s';

    int destinationCount = 0;
    String? _firstDest;   // first [download] Destination: path
    String? _mergeDest;   // [ffmpeg] Merging formats into "path"
    String? _ffmpegDest;  // [ffmpeg] Destination: path (audio conversion)

    try {
      await for (final line in ytDlp.startDownload(
        id: item.id,
        url: item.url,
        formatSelector: formatSelector,
        outputTemplate: outputTmpl,
        outputFormat: outputFormat,
        audioOnly: audioOnly,
        audioQuality: audioQuality,
      )) {
        if (line.contains('[download] Destination:')) {
          destinationCount++;
          // Capture the first destination as likely-final for single-stream DLs
          if (destinationCount == 1) {
            _firstDest = line.substring(line.indexOf('Destination:') + 'Destination:'.length).trim();
            // First file — video (or audio for audio-only)
            item.phase = audioOnly ? DownloadPhase.audio : DownloadPhase.video;
            item.progress = 0.0;
          } else {
            // Second file — audio track (video+audio download)
            item.phase = DownloadPhase.audio;
            item.progress = 0.0;
            pendingNotifications.add(DownloadNotification(
              message: 'Video stream downloaded',
              subtitle: item.title,
              type: DownloadNotifType.videoPhase,
            ));
          }
          notifyListeners();
        } else if (line.contains('[ffmpeg] Merging formats') ||
            line.contains('[Merger] Merging formats') ||
            (audioOnly && (line.contains('[ffmpeg] Destination:') ||
                line.contains('[ExtractAudio] Destination:')))) {
          // Capture final merged / converted path
          if (line.contains('Merging formats')) {
            final m = RegExp(r'into "(.+)"').firstMatch(line);
            if (m != null) _mergeDest = m.group(1);
          } else if (line.contains('Destination:')) {
            // audio-only: [ffmpeg] or [ExtractAudio] Destination: path
            _ffmpegDest = line.substring(line.indexOf('Destination:') + 'Destination:'.length).trim();
          }
          // Merging video+audio OR ffmpeg audio conversion
          item.phase = DownloadPhase.merging;
          item.progress = 0.95;
          if (!audioOnly) {
            pendingNotifications.add(DownloadNotification(
              message: 'Audio track downloaded',
              subtitle: item.title,
              type: DownloadNotifType.audioPhase,
            ));
          }
          notifyListeners();
        } else if (line.contains('[download]') && line.contains('%')) {
          final pct = RegExp(r'(\d+\.?\d*)%').firstMatch(line);
          if (pct != null) {
            item.progress =
                (double.tryParse(pct.group(1)!) ?? (item.progress * 100)) /
                    100;
          }
          // Parse total file size on first occurrence (e.g. "383.84MiB")
          if (item.fileSize == null) {
            final sizeMatch = RegExp(r'of\s+([\d.]+\s*[KMGT]iB)', caseSensitive: false).firstMatch(line);
            if (sizeMatch != null) item.fileSize = sizeMatch.group(1);
          }
          final spd = RegExp(r'at\s+(\S+/s)').firstMatch(line);
          if (spd != null) {
            item.speed = spd.group(1);
            final kbs = _parseSpeedKbs(spd.group(1)!);
            if (kbs > 0) {
              item.speedHistory.add(kbs);
              if (item.speedHistory.length > 15) item.speedHistory.removeAt(0);
            }
          }
          final eta = RegExp(r'ETA\s+(\S+)').firstMatch(line);
          if (eta != null) item.eta = eta.group(1);
          notifyListeners();
        }
      }
      // If download was cancelled mid-way, don't overwrite the cancelled state
      if (item.status == DownloadStatus.error) {
        notifyListeners();
        return;
      }
      item.status = DownloadStatus.done;
      item.phase = DownloadPhase.complete;
      item.progress = 1.0;
      item.speed = null;
      item.eta = null;
      // Store the actual output file path so DB can detect when user deletes it
      item.filePath = _mergeDest ?? _ffmpegDest ?? _firstDest ?? '';
      // If stored path doesn't exist, scan output dir for the actual file
      if (item.filePath.isNotEmpty && !File(item.filePath).existsSync()) {
        final dir = Directory(effectivePath);
        if (dir.existsSync()) {
          final candidates = dir
              .listSync()
              .whereType<File>()
              .where((f) => f.statSync().modified.isAfter(
                    DateTime.now().subtract(const Duration(minutes: 5)),
                  ))
              .toList();
          if (candidates.isNotEmpty) {
            candidates.sort(
              (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
            );
            item.filePath = candidates.first.path;
          }
        }
      }
      pendingNotifications.add(DownloadNotification(
        message: audioOnly ? 'Audio download complete!' : 'Download complete!',
        subtitle: item.title,
        type: DownloadNotifType.mergeDone,
      ));
      // Persist to SQLite
      try {
        await DownloadDb.save(item);
      } catch (_) {}
    } catch (e) {
      item.status = DownloadStatus.error;
      item.errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Parse a yt-dlp speed string like "1.42MiB/s" or "512.3KiB/s" → KB/s.
  static double _parseSpeedKbs(String speed) {
    final m = RegExp(
      r'^([\d.]+)\s*(K|M|G)?(?:i?B)/s$',
      caseSensitive: false,
    ).firstMatch(speed.trim());
    if (m == null) return 0;
    final val = double.tryParse(m.group(1)!) ?? 0;
    final unit = (m.group(2) ?? '').toUpperCase();
    if (unit == 'M') return val * 1024;
    if (unit == 'G') return val * 1024 * 1024;
    return val; // already KB/s
  }

  // ── Cancel download ───────────────────────────────────────────────────────
  void cancelDownload(String id) {
    ytDlp.killDownload(id);
    final idx = downloads.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    downloads[idx].status = DownloadStatus.error;
    downloads[idx].phase = DownloadPhase.complete;
    downloads[idx].errorMessage = 'Cancelled';
    downloads[idx].progress = 0.0;
    notifyListeners();
  }

  /// Soft-delete: hide item from History/Downloads screens but keep it for Library.
  Future<void> removeDownload(String id) async {
    final idx = downloads.indexWhere((d) => d.id == id);
    if (idx != -1) downloads[idx].showInHistory = false;
    await DownloadDb.hideFromHistory(id);
    notifyListeners();
  }

  /// Permanently remove a record AND delete the file from disk then purge from DB.
  Future<void> permanentlyDelete(String id) async {
    final item = downloads.firstWhere((d) => d.id == id, orElse: () => downloads.first);
    // Prefer the exact file path; fall back to outputPath (treated as directory)
    final target = item.filePath.isNotEmpty ? item.filePath : item.outputPath;
    if (target.isNotEmpty) {
      try {
        final f = File(target);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    downloads.removeWhere((d) => d.id == id);
    await DownloadDb.remove(id);
    notifyListeners();
  }

  /// Clear all completed and error downloads from list and DB.
  Future<void> clearHistory() async {
    downloads.removeWhere(
      (d) => d.status == DownloadStatus.done || d.status == DownloadStatus.error,
    );
    await DownloadDb.clearAll();
    notifyListeners();
  }

  /// Remove download records whose output files no longer exist on disk.
  Future<int> cleanMissingFiles() async {
    final removed = await DownloadDb.cleanMissing();
    if (removed > 0) {
      await refreshFromDb();
    }
    return removed;
  }

  // ── Settings ──────────────────────────────────────────────────────────────
  Future<void> setDownloadPath(String path) async {
    downloadPath = path;
    await _prefs?.setDownloadPath(path);
    notifyListeners();
  }

  // ── Storage stats ─────────────────────────────────────────────────────────

  /// Total bytes of all completed downloads.
  int get totalStorageBytes {
    int total = 0;
    for (final d in downloads) {
      if (d.status == DownloadStatus.done) total += d.fileSizeBytes;
    }
    return total;
  }

  /// Total bytes of video downloads only.
  int get videoStorageBytes {
    int total = 0;
    for (final d in downloads) {
      if (d.status == DownloadStatus.done && !d.resolution.endsWith('k')) {
        total += d.fileSizeBytes;
      }
    }
    return total;
  }

  /// Total bytes of audio downloads only.
  int get audioStorageBytes {
    int total = 0;
    for (final d in downloads) {
      if (d.status == DownloadStatus.done && d.resolution.endsWith('k')) {
        total += d.fileSizeBytes;
      }
    }
    return total;
  }

  /// Format bytes to human-readable string.
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size < 10 && i > 0 ? 1 : 0)} ${units[i]}';
  }

  Future<void> setYtDlpPath(String path) async {
    await _prefs?.setYtDlpPath(path);
    final found = await ytDlp.detectPath(savedPath: path);
    ytDlpReady = found;
    if (found) ytDlpVersion = await ytDlp.getVersion();
    notifyListeners();
  }
}
