import 'playlist_entry.dart';

class PlaylistInfo {
  final String id;
  final String title;
  final String? description;
  final String? thumbnail;
  final String? channelName;
  final String? channelUrl;
  final int? viewCount;
  final String? modifiedDate;
  final int entryCount;
  final List<PlaylistEntry> entries; // mutable — filled progressively during streaming
  final String webpageUrl;

  PlaylistInfo({
    required this.id,
    required this.title,
    this.description,
    this.thumbnail,
    this.channelName,
    this.channelUrl,
    this.viewCount,
    this.modifiedDate,
    required this.entryCount,
    required this.entries,
    required this.webpageUrl,
  });

  /// Total duration of all available entries in seconds.
  int get totalDurationSeconds {
    int total = 0;
    for (final e in entries) {
      if (e.isAvailable && e.duration != null) total += e.duration!;
    }
    return total;
  }

  String get formattedTotalDuration {
    final d = totalDurationSeconds;
    final h = d ~/ 3600;
    final m = (d % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  int get availableCount => entries.where((e) => e.isAvailable).length;

  /// Create from the first-entry JSON returned by --flat-playlist --playlist-items 1 -J.
  /// `entries` starts empty and is populated progressively via streamFlatPlaylist.
  factory PlaylistInfo.fromFirstEntry(Map<String, dynamic> json) {
    final rawEntries = (json['entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Thumbnail from first entry if available
    String? thumbnail;
    if (rawEntries.isNotEmpty) {
      final first = rawEntries.first;
      final thumbs = first['thumbnails'] as List?;
      thumbnail = thumbs != null && thumbs.isNotEmpty
          ? thumbs.last['url']?.toString()
          : first['thumbnail']?.toString();
    }
    thumbnail ??= (json['thumbnails'] as List?)?.lastOrNull?['url']?.toString();

    final count = json['playlist_count'] is num
        ? (json['playlist_count'] as num).toInt()
        : json['n_entries'] is num
            ? (json['n_entries'] as num).toInt()
            : rawEntries.length;

    return PlaylistInfo(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Unknown Playlist').toString(),
      description: json['description']?.toString(),
      thumbnail: thumbnail,
      channelName: json['channel']?.toString() ?? json['uploader']?.toString(),
      channelUrl: json['channel_url']?.toString() ?? json['uploader_url']?.toString(),
      viewCount: json['view_count'] is num ? (json['view_count'] as num).toInt() : null,
      modifiedDate: json['modified_date']?.toString(),
      entryCount: count,
      entries: [], // filled progressively
      webpageUrl: json['webpage_url']?.toString() ?? '',
    );
  }

  factory PlaylistInfo.fromJson(Map<String, dynamic> json) {
    final rawEntries = (json['entries'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final entries = <PlaylistEntry>[];
    for (int i = 0; i < rawEntries.length; i++) {
      entries.add(PlaylistEntry.fromJson(rawEntries[i], i + 1));
    }

    final thumbnails = json['thumbnails'] as List?;
    final thumbnail = thumbnails != null && thumbnails.isNotEmpty
        ? thumbnails.last['url']?.toString()
        : (entries.isNotEmpty ? entries.first.thumbnail : null);

    return PlaylistInfo(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Unknown Playlist').toString(),
      description: json['description']?.toString(),
      thumbnail: thumbnail,
      channelName: json['channel']?.toString() ?? json['uploader']?.toString(),
      channelUrl: json['channel_url']?.toString() ?? json['uploader_url']?.toString(),
      viewCount: json['view_count'] is num ? (json['view_count'] as num).toInt() : null,
      modifiedDate: json['modified_date']?.toString(),
      entryCount: json['playlist_count'] is num
          ? (json['playlist_count'] as num).toInt()
          : rawEntries.length,
      entries: entries,
      webpageUrl: json['webpage_url']?.toString() ?? '',
    );
  }
}
