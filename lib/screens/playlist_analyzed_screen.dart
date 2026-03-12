import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/download_item.dart';
import '../models/playlist_entry.dart';
import '../models/playlist_info.dart';
import '../models/video_info.dart';
import '../providers/app_state.dart';
import '../widgets/app_notification.dart';
import '../widgets/shimmer_box.dart';

class PlaylistAnalyzedScreen extends StatefulWidget {
  final String url;
  final VoidCallback? onDownloadAll;
  final VoidCallback? onQueueAll;
  final VoidCallback? onDownloadOne;
  final VoidCallback? onError;

  const PlaylistAnalyzedScreen({
    super.key,
    required this.url,
    this.onDownloadAll,
    this.onQueueAll,
    this.onDownloadOne,
    this.onError,
  });

  @override
  State<PlaylistAnalyzedScreen> createState() => _PlaylistAnalyzedScreenState();
}

class _PlaylistAnalyzedScreenState extends State<PlaylistAnalyzedScreen> {
  String _globalQuality = '1080p';
  String _globalFormat = 'MP4';
  String _globalAudioFormat = 'MP3';
  bool _isAudioMode = false;
  String? _outputPath;
  final Set<String> _checkedEntries = {};
  final Set<String> _userUncheckedEntries = {};
  final Map<String, String> _rowQualityOverrides = {};
  bool _selectAll = true;
  PlaylistFetchState _lastState = PlaylistFetchState.idle;

  static const _qualities = ['Best', '4K', '1440p', '1080p', '720p', '480p', '360p'];
  static const _formats = ['MP4', 'MKV', 'WEBM'];
  static const _audioFormats = ['MP3', 'M4A', 'FLAC', 'WAV', 'OGG'];

  // Calibration: first-video fetch gives real bitrates & max quality for filtering
  VideoInfo? _calibrationInfo;
  bool _calibrationFetching = false;

  static int _minHeightForQual(String q) {
    switch (q) {
      case '4K': return 2160;
      case '1440p': return 1440;
      case '1080p': return 1080;
      case '720p': return 720;
      case '480p': return 480;
      case '360p': return 360;
      default: return 0;
    }
  }

  List<String> get _filteredQualities {
    final info = _calibrationInfo;
    if (info == null) return _qualities;
    final maxH = info.maxVideoHeight;
    if (maxH <= 0) return _qualities;
    return _qualities.where((q) {
      if (q == 'Best') return true;
      return _minHeightForQual(q) <= maxH;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _outputPath = AppState.instance.downloadPath;
    _lastState = AppState.instance.playlistFetchState;
    AppState.instance.addListener(_onStateChange);
    // If playlist already loaded, initialize checked entries
    _initChecked();
  }

  Future<void> _fetchCalibrationInfo() async {
    if (_calibrationFetching || _calibrationInfo != null) return;
    final entries = AppState.instance.playlistInfo?.entries ?? [];
    final first = entries.firstWhere((e) => e.isAvailable, orElse: () => entries.isNotEmpty ? entries.first : throw Exception('empty'));
    _calibrationFetching = true;
    try {
      final json = await AppState.instance.ytDlp.fetchMetadata(first.url);
      if (json != null && mounted) {
        final info = VideoInfo.fromYtDlpJson(json);
        setState(() {
          _calibrationInfo = info;
          _calibrationFetching = false;
          // Clamp global quality to available tiers
          if (!_filteredQualities.contains(_globalQuality)) {
            _globalQuality = _filteredQualities.last;
          }
          // Clamp per-row overrides
          for (final key in _rowQualityOverrides.keys.toList()) {
            if (!_filteredQualities.contains(_rowQualityOverrides[key])) {
              _rowQualityOverrides.remove(key);
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _calibrationFetching = false);
    }
  }

  void _initChecked() {
    final info = AppState.instance.playlistInfo;
    if (info != null) {
      _checkedEntries.clear();
      for (final e in info.entries) {
        if (e.isAvailable) _checkedEntries.add(e.id);
      }
      final availableCount = info.entries.where((e) => e.isAvailable).length;
      _selectAll = availableCount > 0 && _checkedEntries.length >= availableCount;
    }
  }

  void _onStateChange() {
    if (!mounted) return;
    final state = AppState.instance.playlistFetchState;
    final info = AppState.instance.playlistInfo;

    // Auto-check newly streamed available entries (but not ones user unchecked)
    if (info != null) {
      for (final e in info.entries) {
        if (e.isAvailable &&
            !_checkedEntries.contains(e.id) &&
            !_userUncheckedEntries.contains(e.id)) {
          _checkedEntries.add(e.id);
        }
      }
      final availableCount = info.entries.where((e) => e.isAvailable).length;
      _selectAll = availableCount > 0 && _checkedEntries.length >= availableCount;
    }

    if (state == PlaylistFetchState.success && _lastState != PlaylistFetchState.success) {
      // Final sync when streaming completes
      _initChecked();
    }

    // Start calibration fetch once we have at least one available entry
    if (!_calibrationFetching && _calibrationInfo == null && info != null &&
        info.entries.any((e) => e.isAvailable)) {
      _fetchCalibrationInfo();
    }

    _lastState = state;
    setState(() {});
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onStateChange);
    super.dispose();
  }

  /// True while entries are still streaming in.
  bool get _isStreamingEntries =>
      AppState.instance.playlistFetchState == PlaylistFetchState.loadingEntries;

  PlaylistInfo? get _info => AppState.instance.playlistInfo;

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      _checkedEntries.clear();
      _userUncheckedEntries.clear();
      if (_selectAll && _info != null) {
        for (final e in _info!.entries) {
          if (e.isAvailable) _checkedEntries.add(e.id);
        }
      } else if (!_selectAll && _info != null) {
        // User deselected all track them as unchecked
        for (final e in _info!.entries) {
          if (e.isAvailable) _userUncheckedEntries.add(e.id);
        }
      }
    });
  }

  void _toggleEntry(String id, bool? value) {
    setState(() {
      if (value == true) {
        _checkedEntries.add(id);
        _userUncheckedEntries.remove(id);
      } else {
        _checkedEntries.remove(id);
        _userUncheckedEntries.add(id);
      }
      _selectAll = _info != null &&
          _checkedEntries.length == _info!.entries.where((e) => e.isAvailable).length;
    });
  }

  // Shared helper — enqueue all selected entries to a specific folder.
  void _enqueueEntries(String outputPath, PlaylistInfo info) {
    final selected = info.entries.where((e) => _checkedEntries.contains(e.id) && e.isAvailable);
    // Only skip entries that are currently active (queued/downloading/paused).
    // Completed or errored downloads can be re-downloaded to a different folder.
    final activeUrls = AppState.instance.downloads
        .where((d) =>
            d.status == DownloadStatus.queued ||
            d.status == DownloadStatus.downloading ||
            d.status == DownloadStatus.paused)
        .map((d) => d.url)
        .toSet();
    for (final entry in selected) {
      if (activeUrls.contains(entry.url)) continue;
      final DownloadItem item;
      if (_isAudioMode) {
        item = DownloadItem(
          title: entry.title,
          url: entry.url,
          resolution: '320k',
          format: _globalAudioFormat.toLowerCase(),
          outputPath: outputPath,
          thumbnailUrl: entry.thumbnail,
          extractor: 'youtube',
          videoDuration: entry.duration,
          playlistId: info.id,
          playlistTitle: info.title,
        );
      } else {
        final resolution = _rowQualityOverrides[entry.id] ?? _globalQuality;
        item = DownloadItem(
          title: entry.title,
          url: entry.url,
          resolution: resolution,
          format: _globalFormat,
          outputPath: outputPath,
          thumbnailUrl: entry.thumbnail,
          extractor: 'youtube',
          videoDuration: entry.duration,
          playlistId: info.id,
          playlistTitle: info.title,
        );
      }
      AppState.instance.enqueueDownload(item);
      activeUrls.add(entry.url);
    }
  }

  void _onDownloadAll() {
    final info = _info;
    if (info == null) return;
    final path = _outputPath ?? AppState.instance.downloadPath ?? '';
    _enqueueEntries(path, info);
    widget.onDownloadAll?.call();
  }

  void _onQueueAll() {
    final info = _info;
    if (info == null) return;
    final path = _outputPath ?? AppState.instance.downloadPath ?? '';
    _enqueueEntries(path, info);
    widget.onQueueAll?.call();
  }

  void _onDownloadOne(PlaylistEntry entry) {
    // Skip only if currently active (not completed/errored — user may re-download)
    final isActive = AppState.instance.downloads.any((d) =>
        d.url == entry.url &&
        (d.status == DownloadStatus.queued ||
         d.status == DownloadStatus.downloading ||
         d.status == DownloadStatus.paused));
    if (isActive) return;
    final outputPath = _outputPath ?? AppState.instance.downloadPath ?? '';
    final info = _info;
    final DownloadItem item;
    if (_isAudioMode) {
      item = DownloadItem(
        title: entry.title,
        url: entry.url,
        resolution: '320k',
        format: _globalAudioFormat.toLowerCase(),
        outputPath: outputPath,
        thumbnailUrl: entry.thumbnail,
        extractor: 'youtube',
        videoDuration: entry.duration,
        playlistId: info?.id,
        playlistTitle: info?.title,
      );
    } else {
      final resolution = _rowQualityOverrides[entry.id] ?? _globalQuality;
      item = DownloadItem(
        title: entry.title,
        url: entry.url,
        resolution: resolution,
        format: _globalFormat,
        outputPath: outputPath,
        thumbnailUrl: entry.thumbnail,
        extractor: 'youtube',
        videoDuration: entry.duration,
        playlistId: info?.id,
        playlistTitle: info?.title,
      );
    }
    AppState.instance.enqueueDownload(item);
    widget.onDownloadOne?.call();
  }

  Future<void> _pickOutputFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) setState(() => _outputPath = result);
  }

  @override
  Widget build(BuildContext context) {
    if (_info == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // LEFT PANEL
        SizedBox(
          width: 300,
          child: _buildLeftPanel(),
        ),
        const SizedBox(width: 12),
        Container(width: 1, color: AppColors.border),
        const SizedBox(width: 12),
        // RIGHT PANEL
        Expanded(child: _buildRightPanel()),
      ],
    );
  }

  // ─── LEFT PANEL ──────────────────────────────────────────────────────
  Widget _buildLeftPanel() {
    final info = _info!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceTransparent,
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: info.thumbnail != null
                  ? Image.network(info.thumbnail!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbPlaceholder())
                  : _thumbPlaceholder(),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Scrollable info + settings
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          info.title,
                          style: AppTextStyles.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Channel
                        if (info.channelName != null)
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded, size: 13, color: AppColors.muted),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  info.channelName!,
                                  style: AppTextStyles.outfit(fontSize: 12, color: AppColors.muted),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 6),
                        // Stats
                        Text(
                          '${info.entryCount} videos · ${info.formattedTotalDuration}',
                          style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted),
                        ),
                        if (info.modifiedDate != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Updated ${info.modifiedDate}',
                            style: AppTextStyles.outfit(fontSize: 10, color: AppColors.muted),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _divider(),
                        const SizedBox(height: 12),
                        // SETTINGS
                        Text(
                          'SETTINGS',
                          style: AppTextStyles.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Audio / Video toggle
                        _audioModeToggle(),
                        const SizedBox(height: 10),
                        if (_isAudioMode) ...[
                          _settingsRow('FORMAT', _globalAudioFormat, _audioFormats, (v) {
                            setState(() => _globalAudioFormat = v);
                          }),
                        ] else ...[
                          _settingsRow('QUALITY', _globalQuality, _filteredQualities, (v) {
                            setState(() => _globalQuality = v);
                          }),
                          const SizedBox(height: 8),
                          _settingsRow('FORMAT', _globalFormat, _formats, (v) {
                            setState(() => _globalFormat = v);
                          }),
                        ],
                        const SizedBox(height: 8),
                        _outputFolderRow(),
                        const SizedBox(height: 8),
                        _selectedSizeWidget(),
                      ],
                    ),
                  ),
                ),
                // Fixed bottom: download action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _divider(),
                      const SizedBox(height: 12),
                      _downloadAllBtn(),
                      const SizedBox(height: 8),
                      _queueAllBtn(),
                      const SizedBox(height: 12),
                      _copyUrlChip(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: AppColors.surface2,
      child: Center(
        child: Icon(Icons.playlist_play_rounded, size: 48, color: AppColors.accent.withOpacity(0.3)),
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.transparent,
          AppColors.accent.withOpacity(0.18),
          Colors.transparent,
        ]),
      ),
    );
  }

  Widget _audioModeToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isAudioMode = !_isAudioMode),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _isAudioMode
                ? AppColors.accent.withOpacity(0.12)
                : AppColors.surface2,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _isAudioMode
                  ? AppColors.accent.withOpacity(0.45)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isAudioMode ? Icons.music_note_rounded : Icons.videocam_rounded,
                size: 14,
                color: _isAudioMode ? AppColors.accent : AppColors.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isAudioMode ? 'Audio Only' : 'Video',
                  style: AppTextStyles.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _isAudioMode ? AppColors.accent : AppColors.text,
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 17,
                decoration: BoxDecoration(
                  color: _isAudioMode
                      ? AppColors.accent
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 150),
                  alignment: _isAudioMode
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
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
  }

  Widget _settingsRow(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: AppTextStyles.outfit(fontSize: 10, color: AppColors.muted, letterSpacing: 0.8)),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: AppColors.surface1,
              style: AppTextStyles.mono(fontSize: 11, color: AppColors.text),
              icon: Icon(Icons.expand_more_rounded, size: 14, color: AppColors.muted),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ),
      ],
    );
  }

  Widget _outputFolderRow() {
    final path = _outputPath ?? AppState.instance.downloadPath ?? '';
    final display = path.isEmpty ? 'Default folder' : path;
    return GestureDetector(
      onTap: _pickOutputFolder,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, size: 13, color: AppColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  display,
                  style: AppTextStyles.mono(fontSize: 10, color: AppColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.accent.withOpacity(0.35)),
                ),
                child: Text('Browse', style: AppTextStyles.outfit(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Estimated download size ────────────────────────────────────────────────

  String _estimatedTotalSize() {
    final info = _info;
    if (info == null || _checkedEntries.isEmpty) return '—';

    // Uses the same Mbps bitrate table as VideoInfo.estimatedSize() so that
    // per-video estimates are consistent: sizeMb = mbps * durationSeconds / 8
    double totalMb = 0;
    for (final e in info.entries) {
      if (!_checkedEntries.contains(e.id) || !e.isAvailable) continue;
      final d = e.duration;
      if (d == null || d == 0) continue;

      final double mbps;
      if (_isAudioMode) {
        mbps = switch (_globalAudioFormat.toUpperCase()) {
          'FLAC' || 'WAV' => 1.411, // CD quality ~1411 kbps
          'MP3' || 'M4A' => 0.320, // 320 kbps
          _ => 0.256, // OGG / other
        };
      } else {
        // Use per-row override if set, otherwise global quality
        final qual = _rowQualityOverrides[e.id] ?? _globalQuality;
        // Prefer real calibrated Mbps from the first-video fetch (much more
        // accurate). Fall back to YouTube VP9/AV1 average bitrate table.
        // 'Best' == '4K' in the fallback so Best never shows less than 4K.
        final calibrated = _calibrationInfo?.calibratedMbps(qual);
        mbps = calibrated ?? switch (qual) {
          'Best'  => 4.0,  // same as 4K — best available is at most 4K-level
          '4K'    => 4.0,
          '1440p' => 2.5,
          '1080p' => 1.2,
          '720p'  => 0.6,
          '480p'  => 0.3,
          '360p'  => 0.15,
          _       => 1.2,
        };
      }

      totalMb += mbps * d / 8;
    }

    if (totalMb == 0) return '—';
    if (totalMb >= 1024 * 1024) return '~${(totalMb / (1024 * 1024)).toStringAsFixed(1)} TB';
    if (totalMb >= 1024) return '~${(totalMb / 1024).toStringAsFixed(1)} GB';
    return '~${totalMb.toStringAsFixed(0)} MB';
  }

  Widget _selectedSizeWidget() {
    final size = _estimatedTotalSize();
    final count = _checkedEntries.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.data_usage_rounded,
              size: 13, color: AppColors.accent.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EST. DOWNLOAD SIZE',
                  style: AppTextStyles.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  size,
                  style: AppTextStyles.syne(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$count selected',
            style: AppTextStyles.outfit(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _downloadAllBtn() {
    final count = _checkedEntries.length;
    return GestureDetector(
      onTap: count > 0 ? _onDownloadAll : null,
      child: MouseRegion(
        cursor: count > 0 ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: count > 0 ? AppColors.accent : AppColors.accent.withOpacity(0.3),
            borderRadius: BorderRadius.circular(9),
            boxShadow: count > 0
                ? [BoxShadow(color: AppColors.accent.withOpacity(0.35), blurRadius: 16)]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.download_rounded, size: 16, color: Colors.black),
              const SizedBox(width: 6),
              Text(
                'Download All ($count)',
                style: AppTextStyles.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _queueAllBtn() {
    final count = _checkedEntries.length;
    return GestureDetector(
      onTap: count > 0 ? _onQueueAll : null,
      child: MouseRegion(
        cursor: count > 0 ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.accent.withOpacity(count > 0 ? 0.5 : 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.queue_rounded, size: 14, color: AppColors.accent.withOpacity(count > 0 ? 1 : 0.4)),
              const SizedBox(width: 6),
              Text(
                'Queue All',
                style: AppTextStyles.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent.withOpacity(count > 0 ? 1 : 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _copyUrlChip() {
    return Center(
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: _info?.webpageUrl ?? widget.url));
          if (!mounted) return;
          showAppNotification(
            context,
            type: NotificationType.info,
            message: 'Playlist URL copied',
            duration: const Duration(seconds: 2),
          );
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_rounded, size: 12, color: AppColors.muted),
              const SizedBox(width: 4),
              Text('Copy URL', style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── RIGHT PANEL ─────────────────────────────────────────────────────
  Widget _buildRightPanel() {
    final info = _info!;
    final entries = info.entries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter / Sort bar
        _buildFilterBar(info),
        const SizedBox(height: 8),
        // Video list
        Expanded(
          child: entries.isEmpty && _isStreamingEntries
              ? _buildVideoCardSkeletons()
              : ListView.builder(
                  itemCount: entries.length + (_isStreamingEntries ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == entries.length) return _buildLoadingFooter();
                    final entry = entries[index];
                    return _PlaylistVideoRow(
                      entry: entry,
                      isChecked: _checkedEntries.contains(entry.id),
                      onToggle: (v) => _toggleEntry(entry.id, v),
                      qualityOverride: _rowQualityOverrides[entry.id],
                      globalQuality: _globalQuality,
                      availableQualities: _filteredQualities,
                      onQualityChanged: (q) {
                        setState(() => _rowQualityOverrides[entry.id] = q);
                      },
                      onDownload: () { _onDownloadOne(entry); },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildVideoCardSkeletons() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceTransparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const ShimmerBox(width: 18, height: 18, borderRadius: 4),
              const SizedBox(width: 6),
              const ShimmerBox(width: 24, height: 14),
              const SizedBox(width: 8),
              const ShimmerBox(width: 120, height: 68, borderRadius: 6),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShimmerBox(height: 14),
                    SizedBox(height: 6),
                    ShimmerBox(width: 120, height: 11),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const ShimmerBox(width: 60, height: 24, borderRadius: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingFooter() {
    final loaded = AppState.instance.playlistInfo?.entries.length ?? 0;
    final total = AppState.instance.playlistInfo?.entryCount ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.accent.withOpacity(0.5)),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Loading $loaded${total > 0 ? '/$total' : ''}…',
            style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(PlaylistInfo info) {
    final available = info.entries.where((e) => e.isAvailable).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceTransparent,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.accent.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Checkbox(
              value: _selectAll,
              onChanged: _toggleSelectAll,
              activeColor: AppColors.accent,
              side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          Text('Select All', style: AppTextStyles.outfit(fontSize: 12, color: AppColors.text)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentDim,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.accent.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_checkedEntries.length}/$available',
                  style: AppTextStyles.mono(fontSize: 10, color: AppColors.accent),
                ),
                if (_isStreamingEntries) ...[  
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation(AppColors.accent.withOpacity(0.6)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          Text(
            '${info.entryCount} videos',
            style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

}

// ─── VIDEO ROW ───────────────────────────────────────────────────────────
class _PlaylistVideoRow extends StatefulWidget {
  final PlaylistEntry entry;
  final bool isChecked;
  final ValueChanged<bool?> onToggle;
  final String? qualityOverride;
  final String globalQuality;
  final List<String> availableQualities;
  final ValueChanged<String> onQualityChanged;
  final VoidCallback onDownload;

  const _PlaylistVideoRow({
    required this.entry,
    required this.isChecked,
    required this.onToggle,
    this.qualityOverride,
    required this.globalQuality,
    required this.availableQualities,
    required this.onQualityChanged,
    required this.onDownload,
  });

  @override
  State<_PlaylistVideoRow> createState() => _PlaylistVideoRowState();
}

class _PlaylistVideoRowState extends State<_PlaylistVideoRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final unavailable = !entry.isAvailable;
    final quality = widget.qualityOverride ?? widget.globalQuality;

    return GestureDetector(
      onTap: unavailable ? null : () => widget.onToggle(!widget.isChecked),
      child: MouseRegion(
        cursor: unavailable ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 88,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _hovered && !unavailable
              ? AppColors.accent.withOpacity(0.04)
              : AppColors.surfaceTransparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _hovered && !unavailable
                ? AppColors.accent.withOpacity(0.25)
                : AppColors.border,
          ),
        ),
        child: Opacity(
          opacity: unavailable ? 0.35 : 1.0,
          child: Row(
            children: [
              // Checkbox
              SizedBox(
                width: 22,
                child: unavailable
                    ? const SizedBox.shrink()
                    : GestureDetector(
                        onTap: () {}, // absorb tap so outer GestureDetector doesn't double-fire
                        child: Checkbox(
                          value: widget.isChecked,
                          onChanged: widget.onToggle,
                          activeColor: AppColors.accent,
                          side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
              ),
              const SizedBox(width: 6),
              // Index
              SizedBox(
                width: 28,
                child: Text(
                  entry.index.toString().padLeft(2, '0'),
                  style: AppTextStyles.mono(fontSize: 11, color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 120,
                  height: 68,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (entry.thumbnail != null && !unavailable)
                        Image.network(
                          entry.thumbnail!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _greyBox(),
                        )
                      else
                        _greyBox(),
                      // Duration badge
                      if (entry.duration != null && !unavailable)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              entry.formattedDuration,
                              style: AppTextStyles.mono(fontSize: 9, color: AppColors.text),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Title + Channel
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      unavailable ? '[Unavailable]' : entry.title,
                      style: AppTextStyles.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: unavailable ? AppColors.muted : AppColors.text,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.channelName != null && !unavailable) ...[
                      const SizedBox(height: 3),
                      Text(
                        entry.channelName!,
                        style: AppTextStyles.outfit(fontSize: 10, color: AppColors.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Quality selector
              if (!unavailable) ...[
                _QualityChip(
                  quality: quality,
                  availableQualities: widget.availableQualities,
                  onChanged: widget.onQualityChanged,
                ),
                const SizedBox(width: 8),
                // Download button
                GestureDetector(
                  onTap: widget.onDownload,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _hovered ? AppColors.accent.withOpacity(0.15) : AppColors.surface2,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: _hovered ? AppColors.accent.withOpacity(0.4) : AppColors.border,
                        ),
                      ),
                      child: Icon(Icons.download_rounded, size: 15, color: AppColors.accent),
                    ),
                  ),
                ),
              ] else ...[
                Icon(Icons.block_rounded, size: 14, color: AppColors.muted),
                const SizedBox(width: 4),
                Text('Unavailable', style: AppTextStyles.outfit(fontSize: 10, color: AppColors.muted)),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _greyBox() {
    return Container(color: AppColors.surface2);
  }
}

// ─── QUALITY CHIP WITH POPUP ─────────────────────────────────────────────
class _QualityChip extends StatelessWidget {
  final String quality;
  final List<String> availableQualities;
  final ValueChanged<String> onChanged;

  const _QualityChip({
    required this.quality,
    required this.availableQualities,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      color: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      offset: const Offset(0, 32),
      itemBuilder: (_) => availableQualities
          .map((q) => PopupMenuItem<String>(
                value: q,
                height: 32,
                child: Text(q, style: AppTextStyles.mono(fontSize: 11, color: q == quality ? AppColors.accent : AppColors.text)),
              ))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(quality, style: AppTextStyles.mono(fontSize: 10, color: AppColors.accent)),
            const SizedBox(width: 4),
            Icon(Icons.expand_more_rounded, size: 12, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
