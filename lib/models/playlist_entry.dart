class PlaylistEntry {
  final String id;
  final String title;
  final String url;
  final String? thumbnail;
  final int? duration;
  final String? channelName;
  final String? uploaderUrl;
  final int index;
  final bool isAvailable;

  const PlaylistEntry({
    required this.id,
    required this.title,
    required this.url,
    this.thumbnail,
    this.duration,
    this.channelName,
    this.uploaderUrl,
    required this.index,
    this.isAvailable = true,
  });

  String get formattedDuration {
    final d = duration;
    if (d == null) return '--:--';
    final h = d ~/ 3600;
    final m = (d % 3600) ~/ 60;
    final s = d % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  factory PlaylistEntry.fromJson(Map<String, dynamic> json, int index) {
    final id = (json['id'] ?? json['url'] ?? '').toString();
    final title = (json['title'] ?? 'Untitled').toString();
    final isAvailable = title != '[Private video]' &&
        title != '[Deleted video]' &&
        json['title'] != null;
    // Build full URL from id if needed
    final url = json['url']?.toString() ??
        (id.isNotEmpty ? 'https://www.youtube.com/watch?v=$id' : '');
    return PlaylistEntry(
      id: id,
      title: title,
      url: url,
      thumbnail: json['thumbnails'] is List && (json['thumbnails'] as List).isNotEmpty
          ? (json['thumbnails'] as List).last['url']?.toString()
          : json['thumbnail']?.toString(),
      duration: json['duration'] is num ? (json['duration'] as num).toInt() : null,
      channelName: json['channel']?.toString() ?? json['uploader']?.toString(),
      uploaderUrl: json['uploader_url']?.toString() ?? json['channel_url']?.toString(),
      index: index,
      isAvailable: isAvailable,
    );
  }
}
