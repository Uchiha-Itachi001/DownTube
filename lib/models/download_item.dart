import 'package:uuid/uuid.dart';

enum DownloadStatus { queued, downloading, done, error, paused }

class DownloadItem {
  final String id;
  final String title;
  final String url;
  final String resolution;
  final String format;
  final String outputPath;
  final DateTime createdAt;
  DownloadStatus status;
  double progress;
  String? speed;
  String? eta;
  String? errorMessage;
  String? thumbnailUrl;

  DownloadItem({
    String? id,
    required this.title,
    required this.url,
    required this.resolution,
    required this.format,
    required this.outputPath,
    this.status = DownloadStatus.queued,
    this.progress = 0.0,
    this.speed,
    this.eta,
    this.errorMessage,
    this.thumbnailUrl,
  })  : id = id ?? const Uuid().v4(),
        createdAt = DateTime.now();
}
