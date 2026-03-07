import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'developer_screen.dart';
import 'widgets/app_notification.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final TextEditingController _urlController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _downloadPath = '';
  bool _isFetching = false;
  bool _isDownloading = false;
  bool _isFetchingSize = false;

  String? _title, _thumbnail, _duration;
  double? _filesize;
  String _format = 'bestvideo+bestaudio/best';
  double _progress = 0;
  String _status = '';

  Process? _proc;

  bool isPlaylist = false;
  List<Map<String, dynamic>> playlistVideos = [];
  String? playlistTitle;
  String? downloadMode; // 'all' or 'select'
  int downloadedCount = 0;
  bool _cancelled = false;
  Map<String, Process?> activeProcs = {};

  // Version tracking
  String? _currentVersion;
  String? _latestVersion;
  bool _isCheckingVersion = false;

  List<Map<String, String>> _formatOptions = [
    {'label': 'Best Quality', 'value': 'bestvideo+bestaudio/best'},
    {'label': 'Audio Only (MP3)', 'value': 'bestaudio'},
  ];

  static const int maxPlaylistSize =
      200; // Restriction point for max videos in playlist

  @override
  void initState() {
    super.initState();
    _initializeDownloadPath();
    _checkYtDlpVersion();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _scrollController.dispose();
    _cancelAllDownloads();
    super.dispose();
  }

  void _initializeDownloadPath() {
    if (Platform.isWindows) {
      _downloadPath =
          '${Platform.environment['USERPROFILE']}\\Documents\\Youtube Downloads';
    } else {
      _downloadPath =
          '${Platform.environment['HOME'] ?? '.'}/Youtube Downloads';
    }
  }

  Future<void> _checkYtDlpVersion() async {
    setState(() => _isCheckingVersion = true);

    bool isInstalled = false;
    String? currentVer;

    try {
      // Get current version
      final currentResult = await Process.run('yt-dlp', ['--version']);
      if (currentResult.exitCode == 0) {
        currentVer = (currentResult.stdout as String).trim();
        isInstalled = true;
        if (mounted) {
          setState(() {
            _currentVersion = currentVer;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking yt-dlp version: $e');
      // yt-dlp is likely not installed
      isInstalled = false;
    }

    // Always try to get latest version from GitHub API
    try {
      final client = HttpClient();
      final request = await client
          .getUrl(
            Uri.parse(
              'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest',
            ),
          )
          .timeout(const Duration(seconds: 10));

      request.headers.set('User-Agent', 'YouTube-Downloader-App');
      final response = await request.close();

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final jsonData = jsonDecode(responseBody);
        final latestVer = (jsonData['tag_name'] as String).replaceAll('v', '');

        if (mounted) {
          setState(() {
            _latestVersion = latestVer;
          });
        }

        // Show appropriate dialog
        if (mounted) {
          if (!isInstalled) {
            _showInstallDialog();
          } else if (currentVer != latestVer) {
            _showUpdateDialog(currentVer!, latestVer);
          }
        }
      } else {
        // If API call fails and yt-dlp is installed, assume current version is latest
        if (mounted && isInstalled) {
          setState(() {
            _latestVersion = currentVer;
          });
        }
      }

      client.close();
    } catch (e) {
      debugPrint('Error fetching latest version from GitHub: $e');
      // If GitHub check fails
      if (mounted) {
        if (isInstalled) {
          setState(() {
            _latestVersion = currentVer;
          });
        } else {
          // Still show install dialog even if we can't check latest version
          _showInstallDialog();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingVersion = false);
      }
    }
  }

  void _showInstallDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFFFF1744).withOpacity(0.3)),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFFF1744),
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'yt-dlp Not Found',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'yt-dlp is not installed or not found in your system.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              SizedBox(height: 12),
              Text(
                'Would you like to download and install it now?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00FF41), Color(0xFF00CC33)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _installYtDlp();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Install Now',
                  style: TextStyle(
                    color: Color(0xFF0A0A0A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showUpdateDialog(String currentVersion, String latestVersion) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFF00FF41).withOpacity(0.3)),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.system_update,
                color: Color(0xFFFF6B00),
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Update Available',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A new version of yt-dlp is available!',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF00FF41).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Current Version:',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        Text(
                          currentVersion,
                          style: const TextStyle(
                            color: Color(0xFF00FF41),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Latest Version:',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        Text(
                          latestVersion,
                          style: const TextStyle(
                            color: Color(0xFFFF6B00),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Would you like to update now?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Later',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B00), Color(0xFFFF8C00)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _updateYtDlp();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Update Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _installYtDlp() async {
    _showProgressDialog(
      'Installing yt-dlp...',
      'Please wait while we download and install yt-dlp.',
    );

    try {
      if (Platform.isWindows) {
        // Download yt-dlp.exe for Windows
        final appDir = Directory.current.path;
        final ytDlpPath = '$appDir\\yt-dlp.exe';

        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse(
            'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe',
          ),
        );

        final response = await request.close();
        if (response.statusCode == 200) {
          final file = File(ytDlpPath);
          final sink = file.openWrite();
          await response.pipe(sink);
          await sink.close();

          if (mounted) {
            Navigator.of(context).pop(); // Close progress dialog
            _showSuccessDialog('yt-dlp installed successfully!');
            _checkYtDlpVersion(); // Recheck version
          }
        } else {
          throw Exception(
            'Failed to download yt-dlp. Status: ${response.statusCode}',
          );
        }
        client.close();
      } else {
        // For Linux/Mac, use pip or direct download
        final result = await Process.run('pip3', ['install', '-U', 'yt-dlp']);
        if (result.exitCode == 0) {
          if (mounted) {
            Navigator.of(context).pop(); // Close progress dialog
            _showSuccessDialog('yt-dlp installed successfully!');
            _checkYtDlpVersion(); // Recheck version
          }
        } else {
          throw Exception('Failed to install yt-dlp: ${result.stderr}');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        _showErrorSnackBar('Failed to install yt-dlp: $e');
      }
    }
  }

  Future<void> _updateYtDlp() async {
    _showProgressDialog(
      'Updating yt-dlp...',
      'Please wait while we update yt-dlp to the latest version.',
    );

    try {
      if (Platform.isWindows) {
        // Download latest yt-dlp.exe for Windows
        final appDir = Directory.current.path;
        final ytDlpPath = '$appDir\\yt-dlp.exe';

        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse(
            'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe',
          ),
        );

        final response = await request.close();
        if (response.statusCode == 200) {
          final file = File(ytDlpPath);
          final sink = file.openWrite();
          await response.pipe(sink);
          await sink.close();

          if (mounted) {
            Navigator.of(context).pop(); // Close progress dialog
            _showSuccessDialog('yt-dlp updated successfully!');
            _checkYtDlpVersion(); // Recheck version
          }
        } else {
          throw Exception(
            'Failed to download update. Status: ${response.statusCode}',
          );
        }
        client.close();
      } else {
        // For Linux/Mac, use pip or yt-dlp's update command
        final result = await Process.run('yt-dlp', ['-U']);
        if (result.exitCode == 0) {
          if (mounted) {
            Navigator.of(context).pop(); // Close progress dialog
            _showSuccessDialog('yt-dlp updated successfully!');
            _checkYtDlpVersion(); // Recheck version
          }
        } else {
          throw Exception('Failed to update yt-dlp: ${result.stderr}');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        _showErrorSnackBar('Failed to update yt-dlp: $e');
      }
    }
  }

  void _showProgressDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFF00FF41).withOpacity(0.3)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00FF41)),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessDialog(String message) {
    if (!mounted) return;
    showAppNotification(
      context,
      type: NotificationType.success,
      message: message,
      actionLabel: 'OK',
      duration: const Duration(seconds: 5),
    );
  }

  Future<void> _pickDir() async {
    try {
      String? selected = await FilePicker.platform.getDirectoryPath();
      if (selected != null && mounted) {
        setState(() => _downloadPath = selected);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error selecting directory: $e');
      }
    }
  }

  Future<void> _fetchVideoSize(
    String videoId,
    Map<String, dynamic> video, [
    String? format,
  ]) async {
    try {
      final videoUrl =
          videoId.contains('http')
              ? videoId
              : 'https://www.youtube.com/watch?v=$videoId';

      final formatToUse = format ?? video['selectedFormat'] ?? _format;

      final result = await Process.run('yt-dlp', [
        '--print',
        '%(filesize_approx)s',
        '-f',
        formatToUse,
        '--no-warnings',
        videoUrl,
      ]).timeout(const Duration(seconds: 10));

      if (result.exitCode == 0 && mounted) {
        final sizeStr = (result.stdout as String).trim();
        if (sizeStr.isNotEmpty && sizeStr != 'NA' && sizeStr != 'None') {
          final sizeBytes = double.tryParse(sizeStr) ?? 0;
          if (sizeBytes > 0) {
            setState(() {
              video['filesize'] = sizeBytes / (1024 * 1024);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to get file size for $videoId: $e');
    }
  }

  Future<void> _fetchInfo(String url) async {
    if (url.trim().isEmpty) {
      _showErrorSnackBar('Please enter a valid YouTube URL');
      return;
    }

    // Validate URL
    if (!_isValidYouTubeUrl(url)) {
      _showErrorSnackBar('Please enter a valid YouTube URL');
      return;
    }

    setState(() {
      _isFetching = true;
      _title = null;
      _thumbnail = null;
      _filesize = null;
      _status = 'Fetching video information...';
      isPlaylist = false;
      playlistVideos = [];
      downloadMode = null;
      downloadedCount = 0;
      _cancelled = false;
      _format = 'bestvideo+bestaudio/best';
      _progress = 0;
    });

    try {
      bool isPlaylistUrl = url.contains('list=') || url.contains('/playlist');
      final args = ['-J', '--no-warnings'];

      if (isPlaylistUrl) {
        args.add('--flat-playlist');
      }

      final process = await Process.start('yt-dlp', args + [url]);
      final completer = Completer<ProcessResult>();

      final stdout = <int>[];
      final stderr = <int>[];

      process.stdout.listen(stdout.addAll);
      process.stderr.listen(stderr.addAll);

      process.exitCode.then((exitCode) {
        completer.complete(
          ProcessResult(
            process.pid,
            exitCode,
            String.fromCharCodes(stdout),
            String.fromCharCodes(stderr),
          ),
        );
      });

      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          process.kill();
          throw TimeoutException(
            'Request timed out',
            const Duration(seconds: 30),
          );
        },
      );

      if (!mounted) return;

      if (result.exitCode == 0) {
        final jsonData = jsonDecode(result.stdout);

        if (jsonData['entries'] != null && jsonData['entries'].isNotEmpty) {
          // Handle playlist
          await _handlePlaylistData(jsonData);
        } else {
          // Handle single video
          await _handleSingleVideoData(jsonData, url);
        }
      } else {
        setState(
          () => _status = 'Failed to fetch information: ${result.stderr}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  bool _isValidYouTubeUrl(String url) {
    return url.contains('youtube.com') || url.contains('youtu.be');
  }

  Future<void> _handlePlaylistData(Map<String, dynamic> jsonData) async {
    final entries = jsonData['entries'] as List;

    if (entries.length > maxPlaylistSize) {
      setState(() {
        _status =
            'Playlist too large. Maximum supported videos: $maxPlaylistSize.';
      });
      return;
    }

    setState(() {
      isPlaylist = true;
      playlistTitle = jsonData['title'] ?? 'Untitled Playlist';
      playlistVideos =
          entries.map<Map<String, dynamic>>((entry) {
            final id = entry['id'] ?? '';
            return {
              'id': id,
              'title': entry['title'] ?? 'Unknown Title',
              'thumbnail':
                  entry['thumbnail'] ??
                  'https://i.ytimg.com/vi/$id/hqdefault.jpg',
              'duration':
                  _formatDuration(entry['duration']) ??
                  entry['duration_string'] ??
                  'Unknown',
              'filesize': null,
              'isDownloading': false,
              'progress': 0.0,
              'status': '',
              'selectedFormat': 'bestvideo+bestaudio/best',
            };
          }).toList();
      _status = '';
    });

    // Set default format
    if (mounted) {
      setState(() {
        _format =
            _formatOptions.firstWhere(
              (opt) => opt['label'] == 'Best Quality',
              orElse: () => _formatOptions[0],
            )['value']!;
        for (var video in playlistVideos) {
          video['selectedFormat'] = _format;
        }
      });
    }

    // Fetch file sizes in batches to limit resource usage
    const batchSize = 10;
    for (var i = 0; i < playlistVideos.length; i += batchSize) {
      final batch = playlistVideos.skip(i).take(batchSize).toList();
      final futures = batch.map((video) => _fetchVideoSize(video['id'], video));
      await Future.wait(futures);
    }
  }

  Future<void> _handleSingleVideoData(
    Map<String, dynamic> jsonData,
    String url,
  ) async {
    setState(() {
      isPlaylist = false;
      _title = jsonData['title'] ?? 'Unknown Title';
      _thumbnail = jsonData['thumbnail'];
      _duration =
          jsonData['duration_string'] ?? _formatDuration(jsonData['duration']);

      final sizeBytes =
          jsonData['filesize_approx'] ??
          jsonData['filesize'] ??
          jsonData['filesize_estimate'] ??
          0;
      _filesize = sizeBytes != 0 ? sizeBytes / (1024 * 1024) : null;
      _status = '';
    });

    // Set default format
    if (mounted) {
      setState(() {
        _format =
            _formatOptions.firstWhere(
              (opt) => opt['label'] == 'Best Quality',
              orElse: () => _formatOptions[0],
            )['value']!;
      });
    }
    await _updateFileSize();
  }

  Future<void> _updateFileSize() async {
    if (_urlController.text.isEmpty || isPlaylist) return;

    try {
      setState(() {
        _status = 'Fetching file size...';
        _isFetchingSize = true;
      });

      final result = await Process.run('yt-dlp', [
        '--print',
        '%(filesize_approx)s',
        '-f',
        _format,
        '--no-warnings',
        _urlController.text,
      ]).timeout(const Duration(seconds: 10));

      if (result.exitCode == 0 && mounted) {
        final sizeStr = (result.stdout as String).trim();
        if (sizeStr.isNotEmpty && sizeStr != 'NA' && sizeStr != 'None') {
          final sizeBytes = double.tryParse(sizeStr) ?? 0;
          setState(() {
            _filesize = sizeBytes > 0 ? sizeBytes / (1024 * 1024) : null;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to get file size: $e');
    } finally {
      if (mounted) {
        setState(() {
          _status = '';
          _isFetchingSize = false;
        });
      }
    }
  }

  String? _formatDuration(dynamic duration) {
    if (duration == null) return null;

    final seconds =
        (duration is num)
            ? duration.toInt()
            : int.tryParse(duration.toString());
    if (seconds == null || seconds <= 0) return null;

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _downloadVideo(
    String videoId,
    String? suggestedTitle, [
    Map<String, dynamic>? video,
  ]) async {
    final videoUrl =
        videoId.contains('http')
            ? videoId
            : 'https://www.youtube.com/watch?v=$videoId';

    final isSingle = video == null;
    final formatToUse =
        isSingle ? _format : (video['selectedFormat'] ?? _format);

    if (isSingle) {
      setState(() {
        _isDownloading = true;
        _progress = 0;
        _status = 'Preparing download...';
      });
    } else {
      setState(() {
        video['isDownloading'] = true;
        video['progress'] = 0.0;
        video['status'] = 'Preparing download...';
      });
    }

    try {
      // Ensure download directory exists
      final dir = Directory(_downloadPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Sanitize filename
      final sanitizedTitle = _sanitizeFilename(suggestedTitle ?? 'video');

      final args = [
        '-o',
        '$_downloadPath/$sanitizedTitle.%(ext)s',
        '--newline',
        '--no-warnings',
      ];

      if (formatToUse == 'bestaudio') {
        args.addAll(['-x', '--audio-format', 'mp3', '--audio-quality', '192K']);
      } else {
        args.addAll(['-f', formatToUse]);
        if (!formatToUse.contains('audio only')) {
          args.addAll(['--merge-output-format', 'mp4']);
        }
      }

      args.add(videoUrl);

      final process = await Process.start('yt-dlp', args);

      if (isSingle) {
        _proc = process;
      } else {
        activeProcs[videoId] = process;
      }

      // Handle stdout
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) =>
                _parseDownloadOutput(line, videoId: videoId, video: video),
          );

      // Handle stderr
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) =>
                _handleDownloadError(line, videoId: videoId, video: video),
          );

      final exitCode = await process.exitCode;

      if (!mounted) return;

      if (isSingle) {
        setState(() {
          _isDownloading = false;
          _status = exitCode == 0 ? 'Download completed!' : 'Download failed';
          if (exitCode == 0) _progress = 100;
        });
        _proc = null;
      } else {
        activeProcs.remove(videoId);
        setState(() {
          video['isDownloading'] = false;
          video['status'] = exitCode == 0 ? 'Completed' : 'Failed';
          if (exitCode == 0) {
            video['progress'] = 100.0;
            if (downloadMode == 'all') downloadedCount++;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;

      if (isSingle) {
        setState(() {
          _isDownloading = false;
          _status = 'Error: ${e.toString()}';
        });
        _proc = null;
      } else {
        activeProcs.remove(videoId);
        setState(() {
          video['isDownloading'] = false;
          video['status'] = 'Error: ${e.toString()}';
        });
      }
    }
  }

  String _sanitizeFilename(String filename) {
    return filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _parseDownloadOutput(
    String line, {
    String? videoId,
    Map<String, dynamic>? video,
  }) {
    final isSingle = video == null;

    final progressRegex = RegExp(r'(\d+\.?\d*)%');

    // Detect what's being downloaded
    String phase = '';
    if (line.contains('[download]') && progressRegex.hasMatch(line)) {
      // Determine the file type being downloaded
      if (line.contains('video only')) {
        phase = '📹 Downloading video';
      } else if (line.contains('audio only')) {
        phase = '🎵 Downloading audio';
      } else if (line.contains('.mp4') || line.contains('.webm')) {
        phase = '📹 Downloading video';
      } else if (line.contains('.m4a') ||
          line.contains('.mp3') ||
          line.contains('.opus')) {
        phase = '🎵 Downloading audio';
      } else {
        phase = '⬇️ Downloading';
      }

      final match = progressRegex.firstMatch(line);
      if (match != null) {
        final progress = double.tryParse(match.group(1)!) ?? 0;
        if (isSingle) {
          // Only update if progress increases or it's the first update
          if (progress >= _progress) {
            setState(() {
              _progress = progress;
              _status = '$phase ${progress.toStringAsFixed(1)}%';
            });
          }
        } else {
          // Only update if progress increases or it's the first update
          final currentProgress = video['progress'] ?? 0.0;
          if (progress >= currentProgress) {
            setState(() {
              video['progress'] = progress;
              video['status'] = '$phase ${progress.toStringAsFixed(1)}%';
              video['phase'] = phase;
            });
          }
        }
      }
    } else if (line.contains('[Merger]') || line.contains('Merging')) {
      phase = '🔗 Merging files';
      if (isSingle) {
        setState(() {
          // Ensure progress stays at least at 95% during merging
          if (_progress < 95) _progress = 95;
          _status = phase;
        });
      } else {
        setState(() {
          // Ensure progress stays at least at 95% during merging
          final currentProgress = video['progress'] ?? 0.0;
          if (currentProgress < 95) video['progress'] = 95.0;
          video['status'] = phase;
          video['phase'] = phase;
        });
      }
    } else if (line.contains('[ExtractAudio]')) {
      phase = '🎵 Extracting audio';
      if (isSingle) {
        setState(() {
          // Ensure progress stays at least at 95% during extraction
          if (_progress < 95) _progress = 95;
          _status = phase;
        });
      } else {
        setState(() {
          // Ensure progress stays at least at 95% during extraction
          final currentProgress = video['progress'] ?? 0.0;
          if (currentProgress < 95) video['progress'] = 95.0;
          video['status'] = phase;
          video['phase'] = phase;
        });
      }
    } else if (line.contains('[FixupM4a]')) {
      phase = '🔧 Processing audio';
      if (isSingle) {
        setState(() {
          // Ensure progress stays at least at 96% during processing
          if (_progress < 96) _progress = 96;
          _status = phase;
        });
      } else {
        setState(() {
          // Ensure progress stays at least at 96% during processing
          final currentProgress = video['progress'] ?? 0.0;
          if (currentProgress < 96) video['progress'] = 96.0;
          video['status'] = phase;
          video['phase'] = phase;
        });
      }
    } else if (line.contains('[ffmpeg]')) {
      phase = '🎬 Converting';
      if (isSingle) {
        setState(() {
          // Ensure progress stays at least at 97% during conversion
          if (_progress < 97) _progress = 97;
          _status = phase;
        });
      } else {
        setState(() {
          // Ensure progress stays at least at 97% during conversion
          final currentProgress = video['progress'] ?? 0.0;
          if (currentProgress < 97) video['progress'] = 97.0;
          video['status'] = phase;
          video['phase'] = phase;
        });
      }
    }
  }

  void _handleDownloadError(
    String line, {
    String? videoId,
    Map<String, dynamic>? video,
  }) {
    if (line.toUpperCase().contains('ERROR:')) {
      final isSingle = video == null;
      final errorMsg = 'Error: $line';

      if (isSingle) {
        setState(() => _status = errorMsg);
      } else {
        setState(() => video['status'] = errorMsg);
      }
    }
  }

  void _cancelDownload({String? videoId}) {
    if (videoId == null) {
      _cancelAllDownloads();
    } else {
      final process = activeProcs[videoId];
      if (process != null) {
        process.kill();
        activeProcs.remove(videoId);

        final videoIndex = playlistVideos.indexWhere((v) => v['id'] == videoId);
        if (videoIndex != -1 && mounted) {
          setState(() {
            playlistVideos[videoIndex]['isDownloading'] = false;
            playlistVideos[videoIndex]['status'] = 'Cancelled';
          });
        }
      }
    }
  }

  void _cancelAllDownloads() {
    _cancelled = true;

    if (_proc != null) {
      _proc!.kill();
      _proc = null;
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _status = 'Download cancelled';
        });
      }
    }

    for (final entry in activeProcs.entries) {
      entry.value?.kill();
    }
    activeProcs.clear();

    if (mounted) {
      setState(() {
        for (final video in playlistVideos) {
          if (video['isDownloading'] == true) {
            video['isDownloading'] = false;
            video['status'] = 'Cancelled';
          }
        }
      });
    }
  }

  Future<void> _downloadAllPlaylistVideos() async {
    if (playlistVideos.isEmpty) return;

    _cancelled = false;
    downloadedCount = 0;

    for (int i = 0; i < playlistVideos.length; i++) {
      if (_cancelled) break;

      final video = playlistVideos[i];
      if (video['status'] != 'Completed') {
        await _downloadVideo(video['id'], video['title'], video);

        if (!_cancelled && i < playlistVideos.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    showAppNotification(
      context,
      type: NotificationType.error,
      message: message,
      actionLabel: 'OK',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Fixed Search Section
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF1A1A1A), const Color(0xFF2A2A2A)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF41).withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color.fromARGB(255, 158, 179, 163),
                                const Color(0xFF00CC33),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            image: const DecorationImage(
                              image: AssetImage('assetes/images/icon.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'YouTube Downloader',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // Version info with Install/Update button
                        if (!_isCheckingVersion)
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    _currentVersion == null
                                        ? const Color(
                                          0xFFFF1744,
                                        ).withOpacity(0.5)
                                        : const Color(
                                          0xFF00FF41,
                                        ).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_currentVersion != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.verified,
                                            size: 12,
                                            color: Color(0xFF00FF41),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'yt-dlp version: $_currentVersion',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (_currentVersion == null)
                                      const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            size: 12,
                                            color: Color(0xFFFF1744),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'yt-dlp: Not Installed',
                                            style: TextStyle(
                                              color: Color(0xFFFF1744),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (_latestVersion != null &&
                                        _currentVersion != null &&
                                        _latestVersion != _currentVersion)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.update,
                                            size: 12,
                                            color: Color(0xFFFF6B00),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Latest version: $_latestVersion',
                                            style: const TextStyle(
                                              color: Color(0xFFFF6B00),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (_latestVersion != null &&
                                        _currentVersion != null &&
                                        _latestVersion == _currentVersion)
                                      const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            size: 12,
                                            color: Color(0xFF00FF41),
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Up to date',
                                            style: TextStyle(
                                              color: Color(0xFF00FF41),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                // Show Install/Update button
                                if (_currentVersion == null ||
                                    (_latestVersion != null &&
                                        _currentVersion != _latestVersion))
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: InkWell(
                                      onTap: () {
                                        if (_currentVersion == null) {
                                          _installYtDlp();
                                        } else {
                                          _updateYtDlp();
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors:
                                                _currentVersion == null
                                                    ? [
                                                      const Color(0xFF00FF41),
                                                      const Color(0xFF00CC33),
                                                    ]
                                                    : [
                                                      const Color(0xFFFF6B00),
                                                      const Color(0xFFFF8C00),
                                                    ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _currentVersion == null
                                                  ? Icons.download
                                                  : Icons.system_update,
                                              size: 12,
                                              color:
                                                  _currentVersion == null
                                                      ? const Color(0xFF0A0A0A)
                                                      : Colors.white,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _currentVersion == null
                                                  ? 'Install'
                                                  : 'Update',
                                              style: TextStyle(
                                                color:
                                                    _currentVersion == null
                                                        ? const Color(
                                                          0xFF0A0A0A,
                                                        )
                                                        : Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        if (_isCheckingVersion)
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF00FF41),
                                ),
                              ),
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF00FF41).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF00FF41).withOpacity(0.3),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.info,
                              color: Color(0xFF00FF41),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const DeveloperScreen(),
                                ),
                              );
                            },
                            tooltip: 'About Developer',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: _buildUrlInput(),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: _buildDownloadPath(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    children: [
                      if (isPlaylist)
                        ..._buildPlaylistUI()
                      else if (_title != null)
                        ..._buildSingleVideoUI(),
                      const SizedBox(height: 20),
                      if (_status.isNotEmpty) _buildStatusText(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _urlController,
              onSubmitted: _isFetching ? null : _fetchInfo,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Paste YouTube URL here...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.link, color: Color(0xFF00FF41)),
                suffixIcon:
                    _urlController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _urlController.clear();
                            setState(() {
                              _title = null;
                              isPlaylist = false;
                              playlistVideos.clear();
                              _status = '';
                            });
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF00FF41), const Color(0xFF00CC33)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF41).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed:
                  _isFetching ? null : () => _fetchInfo(_urlController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 24,
                ),
              ),
              child:
                  _isFetching
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF0A0A0A),
                          ),
                        ),
                      )
                      : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, color: Color(0xFF0A0A0A)),
                          SizedBox(width: 8),
                          Text(
                            'Search',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A0A0A),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadPath() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00FF41).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.folder,
            color: const Color(0xFF00FF41).withOpacity(0.7),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Download Path: $_downloadPath',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.folder_open, color: Color(0xFF00FF41)),
            onPressed: _pickDir,
            tooltip: 'Change Download Folder',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00FF41).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF41).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.info_outline,
              color: const Color(0xFF00FF41),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _status,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSingleVideoUI() {
    return [
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00FF41).withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_thumbnail != null)
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        _thumbnail!,
                        height: 220,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 220,
                            decoration: BoxDecoration(
                              color: const Color(0xFF333333),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white54,
                                  size: 48,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Thumbnail not available',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                _title!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_duration != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FF41).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00FF41).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time,
                            color: Color(0xFF00FF41),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _duration!,
                            style: const TextStyle(
                              color: Color(0xFF00FF41),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (_isFetchingSize)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFF6B00).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFFF6B00),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Loading...',
                            style: TextStyle(
                              color: Color(0xFFFF6B00),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_filesize != null && !_isFetchingSize)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFF6B00).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.storage,
                            color: Color(0xFFFF6B00),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_filesize!.toStringAsFixed(1)} MB',
                            style: const TextStyle(
                              color: Color(0xFFFF6B00),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonFormField<String>(
                  value: _format,
                  decoration: const InputDecoration(
                    labelText: 'Quality Selection',
                    labelStyle: TextStyle(color: Color(0xFF00FF41)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xFF00FF41),
                  ),
                  onChanged: (val) async {
                    if (val != null) {
                      setState(() => _format = val);
                      await _updateFileSize();
                    }
                  },
                  items:
                      _formatOptions.map((opt) {
                        return DropdownMenuItem(
                          value: opt['value'],
                          child: Text(
                            opt['label']!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00FF41),
                        const Color(0xFF00CC33),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FF41).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    icon: Icon(
                      _isDownloading
                          ? Icons.downloading
                          : Icons.download_for_offline,
                      size: 24,
                    ),
                    label: Text(
                      _isDownloading ? 'Downloading...' : 'Download Video',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed:
                        _isDownloading
                            ? null
                            : () =>
                                _downloadVideo(_urlController.text, _title!),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: const Color(0xFF0A0A0A),
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      if (_isDownloading) ...[
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00FF41).withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Download Progress',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_progress.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Color(0xFF00FF41),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress / 100,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF00FF41),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF1744).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFF1744).withOpacity(0.3),
                        ),
                      ),
                      child: TextButton.icon(
                        icon: const Icon(
                          Icons.cancel,
                          color: Color(0xFFFF1744),
                        ),
                        label: const Text(
                          'Cancel Download',
                          style: TextStyle(
                            color: Color(0xFFFF1744),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => _cancelDownload(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildPlaylistUI() {
    final widgets = <Widget>[
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9C27B0).withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF9C27B0),
                          const Color(0xFF7B1FA2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.playlist_play,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlistTitle ?? 'Untitled Playlist',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF9C27B0).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF9C27B0).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '${playlistVideos.length} videos',
                            style: const TextStyle(
                              color: Color(0xFF9C27B0),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
    ];

    if (downloadMode == null) {
      widgets.add(
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose Download Option',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF00FF41),
                              const Color(0xFF00CC33),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00FF41).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.download_for_offline,
                            size: 20,
                          ),
                          label: const Text('Download All'),
                          onPressed: () => setState(() => downloadMode = 'all'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: const Color(0xFF0A0A0A),
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF6B00),
                              const Color(0xFFE65100),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B00).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.checklist, size: 20),
                          label: const Text('Select Videos'),
                          onPressed:
                              () => setState(() => downloadMode = 'select'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: const Color(0xFF0A0A0A),
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Format selection
      widgets.add(
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonFormField<String>(
                value: _format,
                decoration: const InputDecoration(
                  labelText: 'Quality for all videos',
                  labelStyle: TextStyle(color: Color(0xFF00FF41)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                dropdownColor: const Color(0xFF2A2A2A),
                style: const TextStyle(color: Colors.white),
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xFF00FF41),
                ),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _format = val);
                    if (downloadMode == 'all') {
                      for (var video in playlistVideos) {
                        video['selectedFormat'] = val;
                        video['filesize'] = null;
                        _fetchVideoSize(video['id'], video, val);
                      }
                    }
                  }
                },
                items:
                    _formatOptions.map((opt) {
                      return DropdownMenuItem(
                        value: opt['value'],
                        child: Text(
                          opt['label']!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
        ),
      );

      widgets.add(const SizedBox(height: 20));

      if (downloadMode == 'all') {
        widgets.add(
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF00FF41).withOpacity(0.2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Batch Download Progress',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Downloaded: $downloadedCount/${playlistVideos.length}',
                            style: const TextStyle(
                              color: Color(0xFF00FF41),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (activeProcs.isNotEmpty && !_cancelled)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF1744).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFF1744).withOpacity(0.3),
                            ),
                          ),
                          child: TextButton.icon(
                            icon: const Icon(
                              Icons.cancel,
                              color: Color(0xFFFF1744),
                              size: 18,
                            ),
                            label: const Text(
                              'Cancel All',
                              style: TextStyle(
                                color: Color(0xFFFF1744),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () => _cancelDownload(),
                          ),
                        ),
                    ],
                  ),

                  // Show current downloading video progress
                  if (activeProcs.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF00FF41).withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF00FF41,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.downloading,
                                  color: Color(0xFF00FF41),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Currently Downloading:',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...() {
                            // Find the currently downloading video
                            final currentVideo = playlistVideos.firstWhere(
                              (v) => v['isDownloading'] == true,
                              orElse: () => {},
                            );

                            if (currentVideo.isNotEmpty) {
                              final progress = currentVideo['progress'] ?? 0.0;
                              final phase =
                                  currentVideo['phase'] ?? '⬇️ Downloading';

                              return [
                                Text(
                                  currentVideo['title'] ?? 'Unknown',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        phase,
                                        style: TextStyle(
                                          color: const Color(0xFF00FF41),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${progress.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        color: Color(0xFF00FF41),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF333333),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress / 100,
                                      backgroundColor: Colors.transparent,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            Color(0xFF00FF41),
                                          ),
                                    ),
                                  ),
                                ),
                              ];
                            }
                            return [
                              const Text(
                                'Preparing download...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ];
                          }(),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF00FF41),
                            const Color(0xFF00CC33),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00FF41).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download_for_offline, size: 24),
                        label: Text(
                          'Download All Videos (${playlistVideos.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed:
                            activeProcs.isNotEmpty
                                ? null
                                : _downloadAllPlaylistVideos,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: const Color(0xFF0A0A0A),
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.checklist, color: Color(0xFFFF6B00), size: 20),
                SizedBox(width: 8),
                Text(
                  'Select videos to download:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );

        widgets.add(const SizedBox(height: 16));

        widgets.add(
          Container(
            constraints: const BoxConstraints(maxHeight: 600),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlistVideos.length,
              itemBuilder: (context, index) {
                final video = playlistVideos[index];
                final isDownloading = video['isDownloading'] == true;
                final progress = video['progress'] ?? 0.0;
                final status = video['status'] ?? '';
                final filesize = video['filesize'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2A2A2A),
                        const Color(0xFF1A1A1A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  video['thumbnail'],
                                  width: 140,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 140,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF333333),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.white54,
                                        size: 32,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    video['title'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      if (video['duration'] != null) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF00FF41,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFF00FF41,
                                              ).withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.access_time,
                                                color: Color(0xFF00FF41),
                                                size: 12,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                video['duration'].toString(),
                                                style: const TextStyle(
                                                  color: Color(0xFF00FF41),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      if (filesize != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFFFF6B00,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFFFF6B00,
                                              ).withOpacity(0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.storage,
                                                color: Color(0xFFFF6B00),
                                                size: 12,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${filesize.toStringAsFixed(1)} MB',
                                                style: const TextStyle(
                                                  color: Color(0xFFFF6B00),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF333333),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF00FF41,
                                        ).withOpacity(0.2),
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: video['selectedFormat'],
                                        dropdownColor: const Color(0xFF2A2A2A),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                        icon: const Icon(
                                          Icons.arrow_drop_down,
                                          color: Color(0xFF00FF41),
                                          size: 16,
                                        ),
                                        isExpanded: true,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        onChanged: (val) async {
                                          if (val != null && mounted) {
                                            setState(() {
                                              video['selectedFormat'] = val;
                                              video['filesize'] = null;
                                            });
                                            _fetchVideoSize(
                                              video['id'],
                                              video,
                                              val,
                                            );
                                          }
                                        },
                                        items:
                                            _formatOptions.map((opt) {
                                              return DropdownMenuItem(
                                                value: opt['value'],
                                                child: Text(
                                                  opt['label']!,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              );
                                            }).toList(),
                                      ),
                                    ),
                                  ),
                                  if (status.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          status,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _getStatusColor(
                                            status,
                                          ).withOpacity(0.3),
                                        ),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          color: _getStatusColor(status),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: _getActionButtonColor(
                                  status,
                                  isDownloading,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getActionButtonColor(
                                    status,
                                    isDownloading,
                                  ).withOpacity(0.3),
                                ),
                              ),
                              child:
                                  isDownloading
                                      ? IconButton(
                                        icon: const Icon(
                                          Icons.cancel,
                                          color: Color(0xFFFF1744),
                                          size: 20,
                                        ),
                                        onPressed:
                                            () => _cancelDownload(
                                              videoId: video['id'],
                                            ),
                                        tooltip: 'Cancel Download',
                                      )
                                      : IconButton(
                                        icon: Icon(
                                          status == 'Completed'
                                              ? Icons.check_circle
                                              : Icons.download_for_offline,
                                          color: _getActionButtonColor(
                                            status,
                                            isDownloading,
                                          ),
                                          size: 20,
                                        ),
                                        onPressed:
                                            status == 'Completed'
                                                ? null
                                                : () => _downloadVideo(
                                                  video['id'],
                                                  video['title'],
                                                  video,
                                                ),
                                        tooltip:
                                            status == 'Completed'
                                                ? 'Downloaded'
                                                : 'Download Video',
                                      ),
                            ),
                          ],
                        ),
                        if (isDownloading && progress > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF333333),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress / 100,
                                backgroundColor: Colors.transparent,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF00FF41),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  video['phase'] ?? '⬇️ Downloading',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${progress.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: Color(0xFF00FF41),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }

      widgets.add(const SizedBox(height: 20));

      widgets.add(
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF333333), const Color(0xFF2A2A2A)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextButton.icon(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            label: const Text(
              'Back to Options',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () {
              setState(() {
                downloadMode = null;
                _cancelAllDownloads();
              });
            },
          ),
        ),
      );
    }

    return widgets;
  }

  Color _getStatusColor(String status) {
    if (status.contains('Error') || status.contains('Failed')) {
      return const Color(0xFFFF1744);
    } else if (status.contains('Completed')) {
      return const Color(0xFF4CAF50);
    } else if (status.contains('Downloading') || status.contains('Merging')) {
      return const Color(0xFF00FF41);
    } else if (status.contains('Cancelled')) {
      return const Color(0xFFFF9800);
    }
    return Colors.white70;
  }

  Color _getActionButtonColor(String status, bool isDownloading) {
    if (isDownloading) {
      return const Color(0xFFFF1744);
    } else if (status == 'Completed') {
      return const Color(0xFF4CAF50);
    }
    return const Color(0xFF00FF41);
  }
}
