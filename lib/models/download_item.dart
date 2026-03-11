import 'package:uuid/uuid.dart';

enum DownloadStatus { queued, downloading, done, error, paused }

/// Which phase of a multi-stream yt-dlp download we are in.
enum DownloadPhase { video, audio, merging, complete }

/// Converts a yt-dlp file-size string (e.g. "383.84MiB", "500 KiB")
/// to a human-readable string using SI decimal labels (KB, MB, GB)
/// and auto-scales: values ≥ 1000 are promoted to the next unit.
String formatFileSize(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final m = RegExp(r'([\d.]+)\s*(T|G|M|K)?i?B', caseSensitive: false)
      .firstMatch(raw.trim());
  if (m == null) return raw;
  final val = double.tryParse(m.group(1)!) ?? 0;
  final unit = (m.group(2) ?? '').toUpperCase();
  // yt-dlp reports IEC sizes (1 MiB = 1024² bytes); convert to bytes
  final bytes = switch (unit) {
    'T' => val * 1024 * 1024 * 1024 * 1024,
    'G' => val * 1024 * 1024 * 1024,
    'M' => val * 1024 * 1024,
    'K' => val * 1024,
    _   => val,
  };
  // Display with SI decimal labels
  if (bytes >= 1e9) return '${(bytes / 1e9).toStringAsFixed(2)} GB';
  if (bytes >= 1e6) return '${(bytes / 1e6).toStringAsFixed(2)} MB';
  if (bytes >= 1e3) return '${(bytes / 1e3).toStringAsFixed(0)} KB';
  return '${bytes.round()} B';
}

class DownloadItem {
  final String id;
  final String title;
  final String url;
  final String resolution;
  final String format;
  final String outputPath;
  final DateTime createdAt;
  /// 0 = first download; N > 0 appends " (N)" to the output filename.
  final int downloadIndex;
  DownloadStatus status;
  DownloadPhase phase;
  double progress;
  String? speed;
  String? eta;
  String? errorMessage;
  String? thumbnailUrl;
  String? extractor; // platform: youtube, instagram, tiktok …
  /// Rolling window of speed samples (KB/s) used for the sparkline chart.
  final List<double> speedHistory;
  /// When false the item is hidden from the History screen but stays in Library.
  bool showInHistory;
  /// When false the item is hidden from the Library screen.
  bool showInLibrary;
  /// The absolute path of the output file on disk (set when download completes).
  String filePath;
  /// Actual total file size parsed from yt-dlp output (e.g. "383.84 MiB").
  String? fileSize;
  /// Video duration in seconds from VideoInfo (set at enqueue time).
  int? videoDuration;
  /// Playlist metadata (set when download is part of a playlist).
  String? playlistId;
  String? playlistTitle;
  /// Transient: tracks the current partial download path for cleanup on cancel.
  /// Not persisted to DB.
  String partialPath = '';

  /// Parse [fileSize] string to bytes. Returns 0 if unavailable.
  int get fileSizeBytes {
    if (fileSize == null || fileSize!.isEmpty) return 0;
    final m = RegExp(r'([\d.]+)\s*(K|M|G|T)?i?B', caseSensitive: false)
        .firstMatch(fileSize!);
    if (m == null) return 0;
    final val = double.tryParse(m.group(1)!) ?? 0;
    final unit = (m.group(2) ?? '').toUpperCase();
    return switch (unit) {
      'T' => (val * 1024 * 1024 * 1024 * 1024).round(),
      'G' => (val * 1024 * 1024 * 1024).round(),
      'M' => (val * 1024 * 1024).round(),
      'K' => (val * 1024).round(),
      _ => val.round(),
    };
  }

  DownloadItem({
    String? id,
    required this.title,
    required this.url,
    required this.resolution,
    required this.format,
    required this.outputPath,
    this.status = DownloadStatus.queued,
    this.phase = DownloadPhase.video,
    this.progress = 0.0,
    this.speed,
    this.eta,
    this.errorMessage,
    this.thumbnailUrl,
    this.extractor,
    this.downloadIndex = 0,
    this.showInHistory = true,
    this.showInLibrary = true,
    this.filePath = '',
    this.fileSize,
    this.videoDuration,
    this.playlistId,
    this.playlistTitle,
    DateTime? createdAt,
    List<double>? speedHistory,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        speedHistory = speedHistory ?? [];

  /// Formats [videoDuration] (seconds) as MM:SS or HH:MM:SS.
  String get formattedDuration {
    final d = videoDuration;
    if (d == null) return '—';
    final h = d ~/ 3600;
    final m = (d % 3600) ~/ 60;
    final s = d % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // Database serialisation
  Map<String, dynamic> toDbMap() => {
        'id': id,
        'title': title,
        'url': url,
        'output_path': outputPath,
        'resolution': resolution,
        'format': format,
        'thumbnail_url': thumbnailUrl,
        'extractor': extractor,
        'status': status.name,
        'created_at': createdAt.millisecondsSinceEpoch,
        'download_index': downloadIndex,
        'show_in_history': showInHistory ? 1 : 0,
        'show_in_library': showInLibrary ? 1 : 0,
        'file_path': filePath,
        'file_size': fileSize,
        'video_duration': videoDuration,
        'error_message': errorMessage,
        'playlist_id': playlistId,
        'playlist_title': playlistTitle,
      };

  factory DownloadItem.fromDbMap(Map<String, dynamic> row) => DownloadItem(
        id: row['id'] as String,
        title: row['title'] as String? ?? '',
        url: row['url'] as String? ?? '',
        resolution: row['resolution'] as String? ?? '',
        format: row['format'] as String? ?? '',
        outputPath: row['output_path'] as String? ?? '',
        thumbnailUrl: row['thumbnail_url'] as String?,
        extractor: row['extractor'] as String?,
        // Restore actual status — error items have no output file so we never
        // want to auto-clean them; they're only removed by explicit delete.
        status: DownloadStatus.values.firstWhere(
          (s) => s.name == (row['status'] as String? ?? 'done'),
          orElse: () => DownloadStatus.done,
        ),
        phase: DownloadPhase.complete,
        downloadIndex: (row['download_index'] as int?) ?? 0,
        showInHistory: ((row['show_in_history'] as int?) ?? 1) != 0,
        showInLibrary: ((row['show_in_library'] as int?) ?? 1) != 0,
        filePath: row['file_path'] as String? ?? '',
        fileSize: row['file_size'] as String?,
        videoDuration: row['video_duration'] as int?,
        errorMessage: row['error_message'] as String?,
        playlistId: row['playlist_id'] as String?,
        playlistTitle: row['playlist_title'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (row['created_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      );
}
