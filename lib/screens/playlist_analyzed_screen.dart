import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/download_item.dart';
import '../models/playlist_entry.dart';
import '../models/playlist_info.dart';
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
  String? _outputPath;
  final Set<String> _checkedEntries = {};
  final Set<String> _userUncheckedEntries = {};
  final Map<String, String> _rowQualityOverrides = {};
  bool _selectAll = true;
  PlaylistFetchState _lastState = PlaylistFetchState.idle;

  static const _qualities = ['Best', '4K', '1440p', '1080p', '720p', '480p', '360p'];
  static const _formats = ['MP4', 'MKV', 'WEBM'];

  @override
  void initState() {
    super.initState();
    _outputPath = AppState.instance.downloadPath;
    _lastState = AppState.instance.playlistFetchState;
    AppState.instance.addListener(_onStateChange);
    // If playlist already loaded, initialize checked entries
    _initChecked();
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

    _lastState = state;
    setState(() {});
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onStateChange);
    super.dispose();
  }

  /// Show full skeleton only before we have ANY playlist metadata.
  bool get _isLoading {
    final state = AppState.instance.playlistFetchState;
    return state == PlaylistFetchState.idle;
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
        // User deselected all — track them as unchecked
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

  void _onDownloadAll() {
    final info = _info;
    if (info == null) return;
    final selected = info.entries.where((e) => _checkedEntries.contains(e.id) && e.isAvailable);
    // Collect URLs already enqueued to avoid duplicate downloads
    final existingUrls = AppState.instance.downloads.map((d) => d.url).toSet();
    for (final entry in selected) {
      if (existingUrls.contains(entry.url)) continue; // skip already-enqueued
      final resolution = _rowQualityOverrides[entry.id] ?? _globalQuality;
      final item = DownloadItem(
        title: entry.title,
        url: entry.url,
        resolution: resolution,
        format: _globalFormat,
        outputPath: _outputPath ?? AppState.instance.downloadPath ?? '',
        thumbnailUrl: entry.thumbnail,
        extractor: 'youtube',
        videoDuration: entry.duration,
        playlistId: info.id,
        playlistTitle: info.title,
      );
      AppState.instance.enqueueDownload(item);
      existingUrls.add(entry.url); // prevent dups within same batch
    }
    widget.onDownloadAll?.call();
  }

  void _onQueueAll() {
    _onDownloadAll(); // same queuing logic — already navigates via onDownloadAll
    widget.onQueueAll?.call();
  }

  void _onDownloadOne(PlaylistEntry entry) {
    // Skip if already enqueued
    if (AppState.instance.downloads.any((d) => d.url == entry.url)) return;
    final resolution = _rowQualityOverrides[entry.id] ?? _globalQuality;
    final info = _info;
    final item = DownloadItem(
      title: entry.title,
      url: entry.url,
      resolution: resolution,
      format: _globalFormat,
      outputPath: _outputPath ?? AppState.instance.downloadPath ?? '',
      thumbnailUrl: entry.thumbnail,
      extractor: 'youtube',
      videoDuration: entry.duration,
      playlistId: info?.id,
      playlistTitle: info?.title,
    );
    AppState.instance.enqueueDownload(item);
    widget.onDownloadOne?.call();
  }

  Future<void> _pickOutputFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) setState(() => _outputPath = result);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();
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
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                  _settingsRow('QUALITY', _globalQuality, _qualities, (v) {
                    setState(() => _globalQuality = v);
                  }),
                  const SizedBox(height: 8),
                  _settingsRow('FORMAT', _globalFormat, _formats, (v) {
                    setState(() => _globalFormat = v);
                  }),
                  const SizedBox(height: 8),
                  _outputFolderRow(),
                  const Spacer(),
                  _divider(),
                  const SizedBox(height: 12),
                  // ACTION BUTTONS
                  _downloadAllBtn(),
                  const SizedBox(height: 8),
                  _queueAllBtn(),
                  const SizedBox(height: 12),
                  _copyUrlChip(),
                ],
              ),
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
                      onQualityChanged: (q) {
                        setState(() => _rowQualityOverrides[entry.id] = q);
                      },
                      onDownload: () => _onDownloadOne(entry),
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

  // ─── SKELETON ────────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 300,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceTransparent,
              border: Border.all(color: AppColors.accent.withOpacity(0.12)),
              borderRadius: BorderRadius.circular(AppColors.radius),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AspectRatio(aspectRatio: 16 / 9, child: ShimmerBox(borderRadius: 10)),
                const SizedBox(height: 14),
                const ShimmerBox(height: 18),
                const SizedBox(height: 8),
                const ShimmerBox(width: 140, height: 14),
                const SizedBox(height: 6),
                const ShimmerBox(width: 100, height: 12),
                const Spacer(),
                const ShimmerBox(height: 40, borderRadius: 9),
                const SizedBox(height: 8),
                const ShimmerBox(height: 36, borderRadius: 9),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(width: 1, color: AppColors.border),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ShimmerBox(height: 40, borderRadius: 9),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: 6,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceTransparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          const ShimmerBox(width: 18, height: 18, borderRadius: 4),
                          const SizedBox(width: 8),
                          const ShimmerBox(width: 24, height: 14),
                          const SizedBox(width: 10),
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
                ),
              ),
            ],
          ),
        ),
      ],
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
  final ValueChanged<String> onQualityChanged;
  final VoidCallback onDownload;

  const _PlaylistVideoRow({
    required this.entry,
    required this.isChecked,
    required this.onToggle,
    this.qualityOverride,
    required this.globalQuality,
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
  final ValueChanged<String> onChanged;

  const _QualityChip({required this.quality, required this.onChanged});

  static const _qualities = ['Best', '4K', '1440p', '1080p', '720p', '480p', '360p'];

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
      itemBuilder: (_) => _qualities
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
