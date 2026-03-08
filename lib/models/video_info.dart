class FormatInfo {
  final String formatId;
  final String ext;
  final int? width;
  final int? height;
  final int? tbr;
  final int? abr;
  final String? acodec;
  final String? vcodec;

  const FormatInfo({
    required this.formatId,
    required this.ext,
    this.width,
    this.height,
    this.tbr,
    this.abr,
    this.acodec,
    this.vcodec,
  });

  factory FormatInfo.fromJson(Map<String, dynamic> j) => FormatInfo(
        formatId: j['format_id'] as String? ?? '',
        ext: j['ext'] as String? ?? '',
        width: (j['width'] as num?)?.toInt(),
        height: (j['height'] as num?)?.toInt(),
        tbr: (j['tbr'] as num?)?.toInt(),
        abr: (j['abr'] as num?)?.toInt(),
        acodec: j['acodec'] as String?,
        vcodec: j['vcodec'] as String?,
      );

  bool get hasVideo =>
      vcodec != null && vcodec != 'none' && vcodec!.isNotEmpty;
  bool get hasAudio =>
      acodec != null && acodec != 'none' && acodec!.isNotEmpty;
}

class VideoInfo {
  final String id;
  final String title;
  final String? description;
  final String? thumbnail;
  final String? channelName;
  final String? channelId;
  final int? subscriberCount;
  final int? viewCount;
  final int? likeCount;
  final int? duration;
  final String? uploadDate;
  final String? webpageUrl;
  final List<FormatInfo> formats;
  final String? extractor;
  /// Height of the best format yt-dlp selected (top-level JSON field).
  /// Used as a fallback when the formats list lacks adaptive streams.
  final int? topLevelHeight;

  const VideoInfo({
    required this.id,
    required this.title,
    this.description,
    this.thumbnail,
    this.channelName,
    this.channelId,
    this.subscriberCount,
    this.viewCount,
    this.likeCount,
    this.duration,
    this.uploadDate,
    this.webpageUrl,
    required this.formats,
    this.extractor,
    this.topLevelHeight,
  });

  factory VideoInfo.fromYtDlpJson(Map<String, dynamic> j) {
    final rawFormats = j['formats'] as List? ?? [];
    return VideoInfo(
      id: j['id'] as String? ?? '',
      title: j['title'] as String? ?? 'Unknown Title',
      description: j['description'] as String?,
      thumbnail: j['thumbnail'] as String?,
      channelName: j['channel'] as String? ?? j['uploader'] as String?,
      channelId:
          j['channel_id'] as String? ?? j['uploader_id'] as String?,
      subscriberCount: (j['channel_follower_count'] as num?)?.toInt(),
      viewCount: (j['view_count'] as num?)?.toInt(),
      likeCount: (j['like_count'] as num?)?.toInt(),
      duration: (j['duration'] as num?)?.toInt(),
      uploadDate: j['upload_date'] as String?,
      webpageUrl: j['webpage_url'] as String?,
      formats: rawFormats
          .map((f) => FormatInfo.fromJson(f as Map<String, dynamic>))
          .toList(),
      extractor: j['extractor'] as String?,
      topLevelHeight: (j['height'] as num?)?.toInt(),
    );
  }

  // ── Formatters ────────────────────────────────────────────────────────────

  String get formattedDuration {
    if (duration == null) return '--:--';
    final d = duration!;
    final h = d ~/ 3600;
    final m = (d % 3600) ~/ 60;
    final s = d % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedDate {
    if (uploadDate == null || uploadDate!.length != 8) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final m = int.tryParse(uploadDate!.substring(4, 6)) ?? 1;
    final d = uploadDate!.substring(6, 8);
    final y = uploadDate!.substring(0, 4);
    return '${months[m - 1]} $d, $y';
  }

  String get formattedViews {
    if (viewCount == null) return '';
    final v = viewCount!;
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M views';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K views';
    return '$v views';
  }

  String get formattedSubscribers {
    if (subscriberCount == null) return channelName ?? '';
    final s = subscriberCount!;
    if (s >= 1000000) return '${(s / 1000000).toStringAsFixed(1)}M subscribers';
    if (s >= 1000) return '${(s / 1000).toStringAsFixed(0)}K subscribers';
    return '$s subscribers';
  }

  int get maxVideoHeight {
    int max = 0;
    for (final f in formats) {
      if (f.height != null && f.height! > max) max = f.height!;
    }
    // Fall back to the top-level height yt-dlp reported for its best selection
    // (useful when the formats list only contains combined/legacy streams).
    if (max == 0 && topLevelHeight != null) return topLevelHeight!;
    return (topLevelHeight != null && topLevelHeight! > max) ? topLevelHeight! : max;
  }

  String get bestQualityLabel {
    final h = maxVideoHeight;
    if (h >= 2160) return '4K · HDR';
    if (h >= 1080) return '1080p';
    if (h >= 720) return '720p';
    if (h >= 480) return '480p';
    if (h > 0) return '${h}p';
    return 'Audio';
  }

  /// Estimated file size string for a given quality tier.
  String estimatedSize(String resolution) {
    if (duration == null) return '~? MB';
    // 'Best' delegates to whichever quality tier matches the max available height.
    if (resolution == 'Best') {
      final h = maxVideoHeight;
      if (h >= 2160) return estimatedSize('4K');
      if (h >= 1440) return estimatedSize('1440p');
      if (h >= 1080) return estimatedSize('1080p');
      if (h >= 720)  return estimatedSize('720p');
      if (h >= 480)  return estimatedSize('480p');
      if (h >= 360)  return estimatedSize('360p');
      if (h >= 240)  return estimatedSize('240p');
      return estimatedSize('144p');
    }
    final d = duration!;
    double mbps;
    switch (resolution) {
      case '4K':
        mbps = 8.0;   // VP9/AV1 4K
      case '1440p':
        mbps = 4.0;
      case '1080p':
        mbps = 1.5;   // VP9/AV1 1080p (was 3.5 AVC)
      case '720p':
        mbps = 0.8;
      case '480p':
        mbps = 0.4;
      case '360p':
        mbps = 0.2;
      case '240p':
        mbps = 0.12;
      case '144p':
        mbps = 0.06;
      case '320k':
        mbps = 320.0 / 1000;
      case '192k':
        mbps = 192.0 / 1000;
      case '128k':
        mbps = 128.0 / 1000;
      default:
        return '~? MB';
    }
    final sizeMb = mbps * d / 8;
    if (sizeMb >= 1000) {
      return '~${(sizeMb / 1024).toStringAsFixed(1)} GB';
    }
    return '~${sizeMb.toStringAsFixed(0)} MB';
  }
}
