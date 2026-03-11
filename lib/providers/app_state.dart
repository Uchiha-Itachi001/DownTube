import 'package:flutter/material.dart';
import 'dart:io';
import '../core/app_colors.dart';
import '../models/video_info.dart';
import '../models/download_item.dart';
import '../models/playlist_info.dart';
import '../models/playlist_entry.dart';
import '../services/prefs_service.dart';
import '../services/ytdlp_service.dart';
import '../services/download_db.dart';

enum FetchState { idle, loading, success, error }

enum PlaylistFetchState { idle, loadingEntries, success, error }

// Phase notifications (consumed by UI to show overlay cards)
enum DownloadNotifType { videoPhase, audioPhase, mergeDone, downloadError }

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

  // Services
  PrefsService? _prefs;
  final YtDlpService ytDlp = YtDlpService();

  // Engine status
  bool ytDlpReady = false;
  String? ytDlpVersion;
  String? downloadPath;

  // Theme color (accent)
  Color themeColor = AppColors.accent;

  // User profile
  String? userFirstName;
  String? userLastName;
  String? userProfilePic;
  bool userSetupDone = false;

  String get userDisplayName {
    final first = userFirstName ?? '';
    final last = userLastName ?? '';
    if (first.isEmpty && last.isEmpty) return 'User';
    return '$first $last'.trim();
  }

  String get userInitial {
    if (userFirstName != null && userFirstName!.isNotEmpty) {
      return userFirstName![0].toUpperCase();
    }
    return 'U';
  }

  // Download settings (persisted)
  bool autoDownload = true;
  bool embedSubs = true;
  bool saveThumbnail = true;
  bool addChapters = false;
  bool autoUpdateYtDlp = true;
  bool notificationsEnabled = true;
  bool soundEffects = false;

  // Video defaults (persisted)
  String defaultQuality = '1080p';
  String defaultFormat = 'MP4';

  // Audio defaults (persisted)
  String defaultAudioFormat = 'MP3';
  String audioBitrate = '320 kbps';

  Future<void> setThemeColor(Color color) async {
    themeColor = color;
    AppColors.accent = color;
    await _prefs?.setThemeColor(color);
    notifyListeners();
  }

  /// Resets every preference to its factory default.
  Future<void> resetAllSettings() async {
    await setThemeColor(AppColors.green);
    autoDownload = true;
    embedSubs = true;
    saveThumbnail = true;
    addChapters = false;
    autoUpdateYtDlp = true;
    notificationsEnabled = true;
    soundEffects = false;
    defaultQuality = '1080p';
    defaultFormat = 'MP4';
    defaultAudioFormat = 'MP3';
    audioBitrate = '320 kbps';
    await Future.wait([
      _prefs?.setAutoDownload(true) ?? Future.value(),
      _prefs?.setEmbedSubs(true) ?? Future.value(),
      _prefs?.setSaveThumbnail(true) ?? Future.value(),
      _prefs?.setAddChapters(false) ?? Future.value(),
      _prefs?.setAutoUpdateYtDlp(true) ?? Future.value(),
      _prefs?.setNotifications(true) ?? Future.value(),
      _prefs?.setSoundEffects(false) ?? Future.value(),
      _prefs?.setDefaultQuality('1080p') ?? Future.value(),
      _prefs?.setDefaultFormat('MP4') ?? Future.value(),
      _prefs?.setDefaultAudioFormat('MP3') ?? Future.value(),
      _prefs?.setAudioBitrate('320 kbps') ?? Future.value(),
    ]);
    notifyListeners();
  }

  // Video fetch state
  FetchState fetchState = FetchState.idle;
  VideoInfo? videoInfo;
  String? fetchError;
  String? currentUrl;

  // Playlist state
  PlaylistFetchState playlistFetchState = PlaylistFetchState.idle;
  PlaylistInfo? playlistInfo;
  String? playlistError;
  int playlistLoadingCount = 0;
  bool get isPlaylist => playlistInfo != null;

  // Downloads
  final List<DownloadItem> downloads = [];
  int maxConcurrentDownloads = 6;
  int maxDownloadLimit = 1000;
  int _activeDownloadCount = 0;
  final List<DownloadItem> _downloadQueue = [];

  // Phase notifications (UI drains this queue after notifyListeners)
  final List<DownloadNotification> pendingNotifications = [];

  List<DownloadNotification> drainNotifications() {
    if (pendingNotifications.isEmpty) return const [];
    final out = List<DownloadNotification>.from(pendingNotifications);
    pendingNotifications.clear();
    return out;
  }

  // Initialisation
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _prefs = await PrefsService.create();
    downloadPath = _prefs!.downloadPath;

    // Load saved theme color and apply it globally
    final savedColor = _prefs!.themeColor;
    if (savedColor != null) {
      themeColor = savedColor;
      AppColors.accent = savedColor;
    }

    // Load user profile
    userFirstName = _prefs!.userFirstName;
    userLastName = _prefs!.userLastName;
    userProfilePic = _prefs!.userProfilePic;
    userSetupDone = _prefs!.userSetupDone;

    // Load persisted settings
    autoDownload = _prefs!.autoDownload;
    embedSubs = _prefs!.embedSubs;
    saveThumbnail = _prefs!.saveThumbnail;
    addChapters = _prefs!.addChapters;
    autoUpdateYtDlp = _prefs!.autoUpdateYtDlp;
    notificationsEnabled = _prefs!.notifications;
    soundEffects = _prefs!.soundEffects;
    defaultQuality = _prefs!.defaultQuality;
    defaultFormat = _prefs!.defaultFormat;
    defaultAudioFormat = _prefs!.defaultAudioFormat;
    audioBitrate = _prefs!.audioBitrate;
    maxConcurrentDownloads = _prefs!.concurrentDownloads;
    maxDownloadLimit = _prefs!.maxDownloadLimit;

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
  // Fetch video (detects playlist vs single video) with progressive playlist loading
  Future<void> fetchVideo(String url) async {
    currentUrl = url;
    fetchState = FetchState.loading;
    videoInfo = null;
    fetchError = null;
    playlistFetchState = PlaylistFetchState.idle;
    playlistInfo = null;
    playlistError = null;
    playlistLoadingCount = 0;
    notifyListeners();

    try {
      // Quick fetch: --playlist-items 1 detects type in 1-3 seconds even for huge playlists
      final json = await ytDlp.fetchQuickInfo(url);
      if (json == null) {
        throw Exception('yt-dlp engine not found. Install yt-dlp and restart the app.');
      }

      final type = json['_type']?.toString();
      // Detect playlist: explicit _type, or presence of playlist metadata fields,
      // or URL patterns that indicate a playlist context.
      final looksLikePlaylist = type == 'playlist' ||
          json.containsKey('playlist_count') ||
          json.containsKey('entries') ||
          (url.contains('list=') && json['playlist_title'] != null) ||
          url.contains('/playlist?');
      if (looksLikePlaylist) {
        // Build initial playlist info from metadata (entries start empty)
        playlistInfo = PlaylistInfo.fromFirstEntry(json);
        playlistFetchState = PlaylistFetchState.loadingEntries;
        // fetchState stays loading — entries are still streaming
        notifyListeners(); // UI sees isPlaylist=true → switches to playlist layout immediately

        // Stream remaining entries progressively
        int loadedCount = 0;
        await for (final entryJson in ytDlp.streamFlatPlaylist(url)) {
          loadedCount++;
          final entry = PlaylistEntry.fromJson(entryJson, loadedCount);
          playlistInfo!.entries.add(entry);
          playlistLoadingCount = loadedCount;
          if (loadedCount % 5 == 0) notifyListeners();
        }
        playlistLoadingCount = loadedCount;
        playlistFetchState = PlaylistFetchState.success;
        fetchState = FetchState.success;
      } else {
        // Single video — use the JSON we already have
        videoInfo = VideoInfo.fromYtDlpJson(json);
        fetchState = FetchState.success;
      }
    } catch (e) {
      fetchError = e.toString().replaceFirst('Exception: ', '');
      fetchState = FetchState.error;
      playlistFetchState = PlaylistFetchState.error;
      playlistError = fetchError;
    }
    notifyListeners();
  }

  void resetFetch() {
    ytDlp.killPlaylistStream(); // abort any in-progress playlist stream
    fetchState = FetchState.idle;
    videoInfo = null;
    fetchError = null;
    currentUrl = null;
    resetPlaylist();
    notifyListeners();
  }

  void resetPlaylist() {
    playlistFetchState = PlaylistFetchState.idle;
    playlistInfo = null;
    playlistError = null;
    playlistLoadingCount = 0;
  }

  // Downloads
  void enqueueDownload(DownloadItem item) {
    downloads.insert(0, item);
    notifyListeners();
    if (_activeDownloadCount < maxConcurrentDownloads) {
      _startDownload(item);
    } else {
      _downloadQueue.add(item);
    }
  }

  void _startDownload(DownloadItem item) {
    _activeDownloadCount++;
    _executeDownload(item);
  }

  void _onDownloadFinished() {
    _activeDownloadCount--;
    // Start the next queued download (FIFO)
    while (_downloadQueue.isNotEmpty && _activeDownloadCount < maxConcurrentDownloads) {
      final next = _downloadQueue.removeAt(0);
      // Only start if still queued (user may have cancelled while waiting)
      if (next.status == DownloadStatus.queued) {
        _startDownload(next);
      }
    }
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
      // Track this download as active for cleanup on error/cancel
      await DownloadDb.trackActive(item.id, effectivePath);
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
            item.partialPath = _firstDest;
            DownloadDb.updateActivePartialPath(item.id, _firstDest);
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
            final idx = line.indexOf('into ');
            if (idx != -1) {
              _mergeDest = line.substring(idx + 5).trim().replaceAll('"', '');
              item.partialPath = _mergeDest;
              DownloadDb.updateActivePartialPath(item.id, _mergeDest);
            }
          } else if (line.contains('Destination:')) {
            // audio-only: [ffmpeg] or [ExtractAudio] Destination: path
            _ffmpegDest = line.substring(line.indexOf('Destination:') + 'Destination:'.length).trim();
            item.partialPath = _ffmpegDest;
            DownloadDb.updateActivePartialPath(item.id, _ffmpegDest);
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
        _onDownloadFinished();
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
      // No longer active – remove tracking row
      await DownloadDb.removeActive(item.id);
      // Persist to SQLite
      await DownloadDb.save(item);
    } catch (e) {
      item.status = DownloadStatus.error;
      item.errorMessage = e.toString();
      // Persist failed downloads so they survive a restart and appear in
      // history. They are never touched by cleanMissing() and can only be
      // removed by explicit delete.
      // Error downloads: don't store file path, delete leftover partial files
      final partialPath = _mergeDest ?? _ffmpegDest ?? _firstDest ?? '';
      if (partialPath.isNotEmpty) {
        try {
          final f = File(partialPath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      item.filePath = ''; // never store path for failed downloads
      await DownloadDb.removeActive(item.id);
      await DownloadDb.save(item);
      pendingNotifications.add(DownloadNotification(
        message: 'Download failed',
        subtitle: item.title,
        type: DownloadNotifType.downloadError,
      ));
    }
    _onDownloadFinished();
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

  // Cancel download
  Future<void> cancelDownload(String id) async {
    // Remove from pending queue if it's still waiting
    _downloadQueue.removeWhere((d) => d.id == id);
    ytDlp.killDownload(id);
    final idx = downloads.indexWhere((d) => d.id == id);
    if (idx == -1) return;
    final wasActive = downloads[idx].status == DownloadStatus.downloading;
    // Delete any leftover partial file before clearing the path
    final partialPath = downloads[idx].partialPath;
    if (partialPath.isNotEmpty) {
      try {
        final f = File(partialPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      // Also try .part file that yt-dlp may create
      try {
        final partFile = File('$partialPath.part');
        if (await partFile.exists()) await partFile.delete();
      } catch (_) {}
    }
    downloads[idx].status = DownloadStatus.error;
    downloads[idx].phase = DownloadPhase.complete;
    downloads[idx].errorMessage = 'Cancelled';
    downloads[idx].progress = 0.0;
    downloads[idx].filePath = '';
    downloads[idx].partialPath = '';
    // Remove from active tracking and persist the cancelled item
    await DownloadDb.removeActive(id);
    await DownloadDb.save(downloads[idx]);
    if (wasActive) _onDownloadFinished();
    notifyListeners();
  }

  /// Soft-delete: hide item from History/Downloads screens but keep it for Library.
  Future<void> removeDownload(String id) async {
    final idx = downloads.indexWhere((d) => d.id == id);
    if (idx != -1) downloads[idx].showInHistory = false;
    await DownloadDb.hideFromHistory(id);
    notifyListeners();
  }

  /// Cancel all active and queued downloads.
  Future<void> cancelAllDownloads() async {
    // Cleanup leftover partial files for all tracked active downloads
    await DownloadDb.cleanupAllActiveLeftovers();
    final toCancel = downloads
        .where((d) =>
            d.status == DownloadStatus.downloading ||
            d.status == DownloadStatus.queued)
        .map((d) => d.id)
        .toList();
    for (final id in toCancel) {
      await cancelDownload(id);
    }
  }

  /// Permanently remove a record AND delete the file from disk then purge from DB.
  Future<void> permanentlyDelete(String id) async {
    final idx = downloads.indexWhere((d) => d.id == id);
    if (idx == -1) {
      // Record not in memory — just remove from DB
      await DownloadDb.remove(id);
      return;
    }
    final item = downloads[idx];
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

  // Settings
  Future<void> setDownloadPath(String path) async {
    downloadPath = path;
    await _prefs?.setDownloadPath(path);
    notifyListeners();
  }

  // Storage stats
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

  // User profile setters
  Future<void> setUserProfile({
    required String firstName,
    required String lastName,
    String? profilePic,
  }) async {
    userFirstName = firstName;
    userLastName = lastName;
    userProfilePic = profilePic;
    userSetupDone = true;
    await _prefs?.setUserFirstName(firstName);
    await _prefs?.setUserLastName(lastName);
    if (profilePic != null) await _prefs?.setUserProfilePic(profilePic);
    await _prefs?.setUserSetupDone(true);
    notifyListeners();
  }

  Future<void> setUserProfilePicture(String path) async {
    userProfilePic = path;
    await _prefs?.setUserProfilePic(path);
    notifyListeners();
  }

  // Setting setters (persisted)
  Future<void> setAutoDownload(bool v) async {
    autoDownload = v;
    await _prefs?.setAutoDownload(v);
    notifyListeners();
  }

  Future<void> setEmbedSubs(bool v) async {
    embedSubs = v;
    await _prefs?.setEmbedSubs(v);
    notifyListeners();
  }

  Future<void> setSaveThumbnail(bool v) async {
    saveThumbnail = v;
    await _prefs?.setSaveThumbnail(v);
    notifyListeners();
  }

  Future<void> setAddChapters(bool v) async {
    addChapters = v;
    await _prefs?.setAddChapters(v);
    notifyListeners();
  }

  Future<void> setAutoUpdateYtDlp(bool v) async {
    autoUpdateYtDlp = v;
    await _prefs?.setAutoUpdateYtDlp(v);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool v) async {
    notificationsEnabled = v;
    await _prefs?.setNotifications(v);
    notifyListeners();
  }

  Future<void> setSoundEffects(bool v) async {
    soundEffects = v;
    await _prefs?.setSoundEffects(v);
    notifyListeners();
  }

  Future<void> setDefaultQuality(String v) async {
    defaultQuality = v;
    await _prefs?.setDefaultQuality(v);
    notifyListeners();
  }

  Future<void> setDefaultFormat(String v) async {
    defaultFormat = v;
    await _prefs?.setDefaultFormat(v);
    notifyListeners();
  }

  Future<void> setDefaultAudioFormat(String v) async {
    defaultAudioFormat = v;
    await _prefs?.setDefaultAudioFormat(v);
    notifyListeners();
  }

  Future<void> setAudioBitrate(String v) async {
    audioBitrate = v;
    await _prefs?.setAudioBitrate(v);
    notifyListeners();
  }

  Future<void> setConcurrentDownloads(int v) async {
    maxConcurrentDownloads = v.clamp(1, 6);
    await _prefs?.setConcurrentDownloads(maxConcurrentDownloads);
    notifyListeners();
  }

  Future<void> setMaxDownloadLimit(int v) async {
    maxDownloadLimit = v.clamp(1, 1000);
    await _prefs?.setMaxDownloadLimit(maxDownloadLimit);
    notifyListeners();
  }
}
