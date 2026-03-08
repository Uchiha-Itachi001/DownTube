import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/download_item.dart';
import '../models/video_info.dart';
import '../providers/app_state.dart';
import '../widgets/app_notification.dart';
import '../widgets/shimmer_box.dart';

// ─── Quality option ───────────────────────────────────────────────────────────

class _QOption {
  final String res;
  final String name;
  final String? badge;
  const _QOption(this.res, this.name, {this.badge});
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class AnalyzedScreen extends StatefulWidget {
  final String? initialUrl;
  final VoidCallback? onDownload;
  const AnalyzedScreen({super.key, this.initialUrl, this.onDownload});

  @override
  State<AnalyzedScreen> createState() => _AnalyzedScreenState();
}

class _AnalyzedScreenState extends State<AnalyzedScreen> {
  int _selectedQuality = 0;
  int _selectedTab = 0; // 0 = Video, 1 = Audio
  String _selectedFormat = 'MP4';
  final Set<String> _checkOptions = {'Embed Subtitles', 'Save Thumbnail'};
  ValueNotifier<bool>? _loadingNotifDismiss;

  static const _videoFormats = ['MP4', 'MKV', 'WEBM'];
  static const _audioFormats = ['MP3', 'WAV', 'FLAC'];

  static const _audioQ = [
    _QOption('320k', 'HQ Audio'),
    _QOption('192k', 'Standard'),
    _QOption('128k', 'Normal'),
  ];

  List<String> get _formats =>
      _selectedTab == 0 ? _videoFormats : _audioFormats;

  List<_QOption> _videoQualityTiers(VideoInfo? info) {
    if (info == null) {
      return const [
        _QOption('Best', 'Auto', badge: 'AUTO'),
        _QOption('4K', 'Ultra HD', badge: 'HDR'),
        _QOption('1080p', 'Full HD'),
        _QOption('720p', 'HD'),
        _QOption('480p', 'SD'),
        _QOption('360p', 'Low'),
      ];
    }
    // Extract unique heights from actual yt-dlp formats.
    // Use height != null as the video-stream filter — more robust than hasVideo
    // because some combined/legacy YouTube formats may have null vcodec.
    final heightSet = info.formats
        .where((f) => f.height != null && f.height! >= 144)
        .map((f) => f.height!)
        .toSet();

    // Always include the top-level height reported by yt-dlp for its best
    // format selection.  When yt-dlp cannot resolve DASH adaptive streams
    // (e.g. no Node.js JS-challenge solver) the formats list only contains
    // low-resolution combined streams (360p/480p), but the top-level height
    // field still reflects the true best quality (e.g. 1080p/4K).
    // Without this the quality tiles would never show the real best quality.
    if (info.topLevelHeight != null && info.topLevelHeight! >= 144) {
      heightSet.add(info.topLevelHeight!);
    }

    final rawHeights = heightSet.toList()..sort((a, b) => b.compareTo(a));

    if (rawHeights.isEmpty) return [const _QOption('720p', 'HD')];

    // Map each height to a named quality tier, deduplicated
    final seen = <String>{};
    final result = <_QOption>[];
    for (final h in rawHeights) {
      final _QOption q;
      if (h >= 2160) {
        q = const _QOption('4K', 'Ultra HD', badge: 'HDR');
      } else if (h >= 1440) {
        q = const _QOption('1440p', '2K');
      } else if (h >= 1080) {
        q = const _QOption('1080p', 'Full HD');
      } else if (h >= 720) {
        q = const _QOption('720p', 'HD');
      } else if (h >= 480) {
        q = const _QOption('480p', 'SD');
      } else if (h >= 360) {
        q = const _QOption('360p', 'Low');
      } else if (h >= 240) {
        q = const _QOption('240p', 'Very Low');
      } else if (h >= 144) {
        // 144p and 180p both map to the same tier so they deduplicate cleanly.
        q = const _QOption('144p', 'Minimum');
      } else {
        q = _QOption('${h}p', 'Low');
      }
      if (seen.add(q.res)) result.add(q);
    }
    final tiers = result.isEmpty ? [const _QOption('720p', 'HD')] : result;
    // Always prepend the "Best" tile so yt-dlp picks the absolute best
    // quality automatically, matching the old DownTube behaviour.
    return [const _QOption('Best', 'Auto', badge: 'AUTO'), ...tiers];
  }

  List<_QOption> _qualities(VideoInfo? info) =>
      _selectedTab == 0 ? _videoQualityTiers(info) : _audioQ;

  String _summaryLabel(VideoInfo? info) {
    if (_selectedTab == 0) {
      final qs = _videoQualityTiers(info);
      final q = qs[_selectedQuality.clamp(0, qs.length - 1)];
      final size = info?.estimatedSize(q.res) ?? '~? MB';
      return '${q.res} · $size · $_selectedFormat';
    }
    // Audio
    final qs = _audioQ;
    final q = qs[_selectedQuality.clamp(0, qs.length - 1)];
    final size = info?.estimatedSize(q.res) ?? '~? MB';
    return '${q.res} · $size · $_selectedFormat';
  }

  // Show skeleton/loading UI whenever we don't yet have a successful fetch with
  // real video data.  This prevents fake placeholder quality tiles from appearing
  // in idle state (before fetch starts) or error state (after a failed fetch).
  bool get _showSkeleton =>
      AppState.instance.fetchState != FetchState.success ||
      AppState.instance.videoInfo == null;

  // Keep the old name as an alias so existing call-sites still compile.
  bool get _isLoading => _showSkeleton;

  VideoInfo? get _info => AppState.instance.videoInfo;

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onStateChange);
    if (widget.initialUrl != null &&
        widget.initialUrl!.isNotEmpty &&
        AppState.instance.fetchState == FetchState.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppState.instance.fetchVideo(widget.initialUrl!);
        final dismissNotifier = ValueNotifier<bool>(false);
        _loadingNotifDismiss = dismissNotifier;
        showAppNotification(
          context,
          type: NotificationType.loading,
          message: 'Fetching video info…',
          subtitle: widget.initialUrl,
          duration: const Duration(seconds: 30),
          dismissController: dismissNotifier,
        );
      });
    }
  }

  void _onStateChange() {
    if (!mounted) return;
    setState(() {
      if (AppState.instance.fetchState == FetchState.success) {
        _selectedQuality = 0;
        _selectedTab = 0;
        _selectedFormat = 'MP4';
      }
    });
    if (AppState.instance.fetchState == FetchState.success) {
      // Dismiss the loading notification immediately
      _loadingNotifDismiss?.value = true;
      _loadingNotifDismiss = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showAppNotification(
          context,
          type: NotificationType.success,
          message: 'Video ready!',
          subtitle: AppState.instance.videoInfo?.title,
          duration: const Duration(seconds: 3),
        );
      });
    } else if (AppState.instance.fetchState == FetchState.error) {
      _loadingNotifDismiss?.value = true;
      _loadingNotifDismiss = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showAppNotification(
          context,
          type: NotificationType.error,
          message: AppState.instance.fetchError ?? 'Failed to fetch video info',
          duration: const Duration(seconds: 6),
        );
      });
    }
  }

  @override
  void dispose() {
    _loadingNotifDismiss?.value = true;
    _loadingNotifDismiss = null;
    AppState.instance.removeListener(_onStateChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildVideoHeader(),
          const SizedBox(height: AppColors.gap),
          _buildConfigCard(),
          const SizedBox(height: AppColors.gap),
          _buildActionBar(),
        ],
      ),
    );
  }

  // ── VIDEO HEADER ───────────────────────────────────────────────────────────

  Widget _buildVideoHeader() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.green.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left column: thumbnail (fixed width)
            SizedBox(
              width: 400,
              child: _isLoading ? _buildThumbSkeleton() : _buildThumb(),
            ),
            // Right column: details panel
            Expanded(
              child: _isLoading ? _buildInfoPanelSkeleton() : _buildInfoPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumb() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _info?.thumbnail != null
            ? Image.network(
                _info!.thumbnail!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _thumbGradient(),
              )
            : _thumbGradient(),
        // Bottom scrim for overlay readability
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.75), Colors.transparent],
              ),
            ),
          ),
        ),
        // Quality badge — top left
        Positioned(
          top: 12, left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.72),
              border: Border.all(color: AppColors.green.withOpacity(0.55)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.high_quality_rounded, size: 11, color: AppColors.green),
                const SizedBox(width: 4),
                Text(
                  _info?.bestQualityLabel ?? '—',
                  style: AppTextStyles.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Duration — bottom left
        Positioned(
          bottom: 12, left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.80),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              _info?.formattedDuration ?? '--:--',
              style: AppTextStyles.mono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
        ),
        // Platform badge — bottom right
        Positioned(
          bottom: 12, right: 12,
          child: _PlatformBadge(extractor: _info?.extractor),
        ),
        // Right-edge blend so the thumbnail fades into the container bg
        Positioned(
          top: 0, bottom: 0, right: 0,
          child: Container(
            width: 48,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.transparent, Color(0xFF080C09)],
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _thumbGradient() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0E2312), Color(0xFF081A0B), Color(0xFF060F07)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        CustomPaint(painter: _GridPainter()),
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.7,
              colors: [AppColors.green.withOpacity(0.12), Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbSkeleton() {
    return Container(
      color: AppColors.surface2,
      child: const ShimmerBox(borderRadius: 0),
    );
  }

  Widget _buildInfoPanel() {
    final info = _info;
    final url = AppState.instance.currentUrl ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [_readyBadge()]),
          const SizedBox(height: 10),
          Text(
            info?.title ?? 'Unknown Title',
            style: AppTextStyles.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 11),
          if (info != null) _buildChannelRow(info),
          const SizedBox(height: 11),
          if (info != null) _buildMetaChips(info),
          const SizedBox(height: 11),
          _buildUrlBar(url),
        ],
      ),
    );
  }

  Widget _buildInfoPanelSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const ShimmerBox(width: 60, height: 20, borderRadius: 5),
          const SizedBox(height: 12),
          const ShimmerBox(height: 18),
          const SizedBox(height: 6),
          const ShimmerBox(width: 260, height: 18),
          const SizedBox(height: 14),
          Row(children: const [
            ShimmerBox(width: 26, height: 26, borderRadius: 13),
            SizedBox(width: 8),
            ShimmerBox(width: 120, height: 14),
          ]),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: List.generate(4, (_) => const ShimmerBox(width: 80, height: 22, borderRadius: 6)),
          ),
          const SizedBox(height: 12),
          const ShimmerBox(height: 32, borderRadius: 7),
        ],
      ),
    );
  }

  Widget _readyBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.greenDim,
        border: Border.all(color: AppColors.green.withOpacity(0.28)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 11, color: AppColors.green),
          const SizedBox(width: 4),
          Text('Ready', style: AppTextStyles.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.green)),
        ],
      ),
    );
  }

  Widget _buildChannelRow(VideoInfo info) {
    final initial = (info.channelName?.isNotEmpty == true)
        ? info.channelName![0].toUpperCase()
        : 'C';
    return Row(
      children: [
        Container(
          width: 26, height: 26,
          decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
          child: Center(child: Text(initial, style: AppTextStyles.syne(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black))),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(info.channelName ?? '', style: AppTextStyles.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.green)),
            if (info.subscriberCount != null)
              Text(info.formattedSubscribers, style: AppTextStyles.outfit(fontSize: 10, color: AppColors.muted)),
          ],
        ),
        const Spacer(),
        if (info.viewCount != null) _miniChip(Icons.visibility_outlined, info.formattedViews),
      ],
    );
  }

  Widget _miniChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.muted),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.outfit(fontSize: 10, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _buildMetaChips(VideoInfo info) {
    final items = <(IconData, String)>[
      if (info.formattedDate.isNotEmpty)
        (Icons.calendar_today_outlined, info.formattedDate),
      if (info.likeCount != null)
        (Icons.thumb_up_outlined, '${(info.likeCount! / 1000).toStringAsFixed(0)}K liked'),
      (Icons.high_quality_outlined, info.bestQualityLabel),
      (Icons.access_time_rounded, info.formattedDuration),
    ];
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: items.map((i) => _miniChip(i.$1, i.$2)).toList(),
    );
  }

  Widget _buildUrlBar(String url) {
    final display = url.replaceFirst('https://', '').replaceFirst('http://', '');
    return GestureDetector(
      onTap: () => Clipboard.setData(ClipboardData(text: url)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.link_rounded, size: 12, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(child: Text(display.isEmpty ? '—' : display, style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            const Icon(Icons.copy_rounded, size: 12, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  // ── CONFIG CARD ────────────────────────────────────────────────────────────

  Widget _buildConfigCard() {
    if (_isLoading) return _buildConfigCardSkeleton();
    final info = _info;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.green.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header
          Row(
            children: [
              Container(
                width: 3, height: 14,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: AppColors.green.withOpacity(0.6), blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 10),
              Text('CONFIGURE DOWNLOAD',
                style: AppTextStyles.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 1.1)),
              const Spacer(),
              _buildTabSwitch(),
            ],
          ),
          const SizedBox(height: 20),

          // ── Quality
          _sectionLabel('QUALITY'),
          const SizedBox(height: 10),
          _buildQualityRow(info),
          const SizedBox(height: 20),
          _gradientDivider(),
          const SizedBox(height: 20),

          // ── Format + Options side-by-side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Format column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _sectionLabel('FORMAT'),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _formats.indexed.map((e) => Padding(
                      padding: EdgeInsets.only(right: e.$1 < _formats.length - 1 ? 8 : 0),
                      child: _formatBtn(e.$2),
                    )).toList(),
                  ),
                ],
              ),
              const SizedBox(width: 28),
              Container(width: 1, height: 56, color: AppColors.border),
              const SizedBox(width: 28),
              // Options column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _sectionLabel('OPTIONS'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 18, runSpacing: 10,
                      children: (_selectedTab == 0
                          ? ['Embed Subtitles', 'Save Thumbnail', 'Add Chapters']
                          : ['Embed Cover Art', 'Album Tags'])
                          .map(_checkOption)
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitch() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tabBtn(Icons.videocam_rounded, 'Video', 0),
          _tabBtn(Icons.music_note_rounded, 'Audio', 1),
        ],
      ),
    );
  }

  Widget _tabBtn(IconData icon, String label, int index) {
    final active = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedTab = index;
        _selectedQuality = 0;
        _selectedFormat = index == 0 ? 'MP4' : 'MP3';
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? Colors.black : AppColors.muted),
            const SizedBox(width: 5),
            Text(label, style: AppTextStyles.outfit(fontSize: 12, fontWeight: FontWeight.w600,
                color: active ? Colors.black : AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityRow(VideoInfo? info) {
    final quals = _qualities(info);
    if (quals.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(quals.length, (i) {
        final sizeStr = info?.estimatedSize(quals[i].res) ?? '~? MB';
        return GestureDetector(
          onTap: () => setState(() => _selectedQuality = i),
          child: _QualityTile(
            res: quals[i].res,
            name: quals[i].name,
            size: sizeStr,
            badge: quals[i].badge,
            isSelected: _selectedQuality == i,
          ),
        );
      }),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
      style: AppTextStyles.outfit(fontSize: 10, fontWeight: FontWeight.w600,
          color: AppColors.muted, letterSpacing: 1.0));
  }

  Widget _gradientDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, AppColors.green.withOpacity(0.20), Colors.transparent],
        ),
      ),
    );
  }

  Widget _formatBtn(String format) {
    final sel = _selectedFormat == format;
    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = format),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.greenDim : AppColors.surface2,
          border: Border.all(
            color: sel ? AppColors.green.withOpacity(0.55) : AppColors.border,
            width: sel ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: sel ? [BoxShadow(color: AppColors.green.withOpacity(0.14), blurRadius: 12)] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(format, style: AppTextStyles.outfit(fontSize: 13, fontWeight: FontWeight.w600,
                color: sel ? AppColors.green : AppColors.muted)),
            if (sel) ...[const SizedBox(width: 5), const Icon(Icons.check_rounded, size: 13, color: AppColors.green)],
          ],
        ),
      ),
    );
  }

  Widget _checkOption(String label) {
    final on = _checkOptions.contains(label);
    return GestureDetector(
      onTap: () => setState(() => on ? _checkOptions.remove(label) : _checkOptions.add(label)),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 15, height: 15,
              decoration: BoxDecoration(
                color: on ? AppColors.green : Colors.transparent,
                border: Border.all(color: on ? AppColors.green : AppColors.muted.withOpacity(0.40)),
                borderRadius: BorderRadius.circular(4),
                boxShadow: on ? [BoxShadow(color: AppColors.green.withOpacity(0.4), blurRadius: 6)] : null,
              ),
              child: on ? const Center(child: Icon(Icons.check_rounded, size: 11, color: Colors.black)) : null,
            ),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.outfit(fontSize: 12,
                color: on ? AppColors.text.withOpacity(0.88) : AppColors.muted)),
          ],
        ),
      ),
    );
  }

  // ── ACTION BAR ─────────────────────────────────────────────────────────────

  Widget _buildConfigCardSkeleton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.green.withOpacity(0.12)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            ShimmerBox(width: 160, height: 12, borderRadius: 4),
            Spacer(),
            ShimmerBox(width: 110, height: 28, borderRadius: 9),
          ]),
          const SizedBox(height: 20),
          // Quality rows skeleton
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
                5, (_) => const ShimmerBox(width: 106, height: 94, borderRadius: 10)),
          ),
          const SizedBox(height: 20),
          const ShimmerBox(height: 1, borderRadius: 0),
          const SizedBox(height: 20),
          Row(children: const [
            ShimmerBox(width: 200, height: 36, borderRadius: 8),
            SizedBox(width: 28),
            Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
          ]),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    if (_showSkeleton) return _buildActionBarSkeleton();
    final info = _info;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.green.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_summaryLabel(info),
                  style: AppTextStyles.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 12, color: AppColors.green),
                    const SizedBox(width: 3),
                    Text('No DRM detected',
                      style: AppTextStyles.outfit(fontSize: 11, color: AppColors.green)),
                  ],
                ),
              ],
            ),
          ),
          _ghostBtn(Icons.queue_rounded, '+ Queue', info != null ? _onQueue : null),
          const SizedBox(width: 10),
          _primaryBtn(Icons.download_rounded, 'Download Now', info != null ? _onDownload : null),
        ],
      ),
    );
  }

  Widget _buildActionBarSkeleton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.green.withOpacity(0.12)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShimmerBox(width: 200, height: 13, borderRadius: 4),
                SizedBox(height: 6),
                ShimmerBox(width: 130, height: 11, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const ShimmerBox(width: 100, height: 38, borderRadius: 10),
          const SizedBox(width: 10),
          const ShimmerBox(width: 150, height: 38, borderRadius: 10),
        ],
      ),
    );
  }

  String get _selectedResolution {
    final qs = _qualities(_info);
    return qs[_selectedQuality.clamp(0, qs.length - 1)].res;
  }

  void _onQueue() {
    final info = _info;
    if (info == null) return;
    AppState.instance.enqueueDownload(DownloadItem(
      title: info.title,
      url: AppState.instance.currentUrl ?? '',
      resolution: _selectedResolution,
      format: _selectedFormat,
      outputPath: AppState.instance.downloadPath ?? '',
      thumbnailUrl: info.thumbnail,
      status: DownloadStatus.queued,
    ));
    widget.onDownload?.call();
  }

  void _onDownload() {
    final info = _info;
    if (info == null) return;
    AppState.instance.enqueueDownload(DownloadItem(
      title: info.title,
      url: AppState.instance.currentUrl ?? '',
      resolution: _selectedResolution,
      format: _selectedFormat,
      outputPath: AppState.instance.downloadPath ?? '',
      thumbnailUrl: info.thumbnail,
    ));
    widget.onDownload?.call();
  }

  Widget _ghostBtn(IconData icon, String label, VoidCallback? onTap) {
    return _HoverBtn(
      onTap: onTap,
      builder: (hov) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: hov ? AppColors.green.withOpacity(0.07) : Colors.transparent,
          border: Border.all(color: AppColors.green.withOpacity(0.40)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.green),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.green)),
          ],
        ),
      ),
    );
  }

  Widget _primaryBtn(IconData icon, String label, VoidCallback? onTap) {
    return _HoverBtn(
      onTap: onTap,
      builder: (hov) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.green,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.greenGlow.withOpacity(hov ? 0.55 : 0.32),
              blurRadius: hov ? 28 : 18,
              offset: Offset(0, hov ? 6 : 3),
            ),
          ],
        ),
        transform: hov ? (Matrix4.identity()..translate(0.0, -1.0)) : Matrix4.identity(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: Colors.black),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.syne(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black)),
          ],
        ),
      ),
    );
  }
}

// ── Quality tile ─────────────────────────────────────────────────────────────

class _QualityTile extends StatefulWidget {
  final String res;
  final String name;
  final String size;
  final String? badge;
  final bool isSelected;

  const _QualityTile({
    required this.res,
    required this.name,
    required this.size,
    this.badge,
    required this.isSelected,
  });

  @override
  State<_QualityTile> createState() => _QualityTileState();
}

class _QualityTileState extends State<_QualityTile> {
  bool _hov = false;

  static IconData _iconFor(String res) {
    switch (res) {
      case 'Best':  return Icons.auto_awesome_rounded;
      case '4K':
      case '1440p':  return Icons.hd_rounded;
      case '1080p':  return Icons.high_quality_rounded;
      case '720p':   return Icons.hd_outlined;
      case '480p':
      case '360p':   return Icons.sd_rounded;
      default:
        if (res.endsWith('k')) return Icons.music_note_rounded;
        return Icons.signal_cellular_4_bar_rounded;
    }
  }

  static Color _accentFor(String res) {
    switch (res) {
      case 'Best':   return AppColors.green;
      case '4K':     return const Color(0xFF8B5CF6);
      case '1440p':  return AppColors.blue;
      case '1080p':  return AppColors.green;
      case '720p':   return const Color(0xFF0EA5E9);
      case '480p':   return AppColors.yellow;
      case '360p':
      case '240p':   return const Color(0xFFF97316);
      case '144p':   return AppColors.red;
      default:
        if (res.endsWith('k')) return AppColors.blue;
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.isSelected;
    final accent = _accentFor(widget.res);
    final badgeColor = widget.badge == 'AUTO' ? accent : AppColors.yellow;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 106,
        decoration: BoxDecoration(
          color: sel
              ? accent.withValues(alpha: 0.09)
              : (_hov ? AppColors.surface3 : AppColors.surface2),
          border: Border.all(
            color: sel
                ? accent.withValues(alpha: 0.60)
                : (_hov
                    ? AppColors.green.withValues(alpha: 0.20)
                    : AppColors.border),
            width: sel ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: sel
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Accent bar at top
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 3,
              color: sel ? accent : Colors.transparent,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon row + badge/check
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: (sel ? accent : AppColors.muted)
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Center(
                          child: Icon(
                            _iconFor(widget.res),
                            size: 14,
                            color: sel ? accent : AppColors.muted,
                          ),
                        ),
                      ),
                      if (widget.badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            border: Border.all(
                                color: badgeColor.withValues(alpha: 0.38)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.badge!,
                            style: AppTextStyles.spaceGrotesk(
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              color: badgeColor,
                            ),
                          ),
                        )
                      else if (sel)
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.40),
                                blurRadius: 6,
                              )
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.check_rounded,
                                size: 10, color: Colors.black),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Resolution
                  Text(
                    widget.res,
                    style: AppTextStyles.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: sel ? accent : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 1),
                  // Quality name
                  Text(
                    widget.name,
                    style: AppTextStyles.outfit(
                      fontSize: 10,
                      color: sel
                          ? accent.withValues(alpha: 0.70)
                          : AppColors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  // File size
                  Text(
                    widget.size,
                    style: AppTextStyles.mono(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? accent.withValues(alpha: 0.50)
                          : AppColors.muted2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hover button helper ───────────────────────────────────────────────────────

class _HoverBtn extends StatefulWidget {
  final Widget Function(bool hovered) builder;
  final VoidCallback? onTap;
  const _HoverBtn({required this.builder, this.onTap});

  @override
  State<_HoverBtn> createState() => _HoverBtnState();
}

class _HoverBtnState extends State<_HoverBtn> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: GestureDetector(onTap: widget.onTap, child: widget.builder(_hov)),
    );
  }
}

// ── Grid painter ──────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const step = 24.0;
    final paint = Paint()
      ..color = const Color(0xFF22C55E).withOpacity(0.07)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

// ── Platform badge with per-platform colour ───────────────────────────────────

class _PlatformBadge extends StatelessWidget {
  final String? extractor;
  const _PlatformBadge({this.extractor});

  // Returns (label, icon, colour) for each platform.
  (String, IconData, Color) get _meta {
    final e = extractor?.toLowerCase() ?? '';
    if (e.contains('youtube')) {
      return ('YouTube', Icons.play_circle_fill_rounded, const Color(0xFFFF4444));
    }
    if (e.contains('instagram')) {
      return ('Instagram', Icons.camera_alt_rounded, const Color(0xFFE1306C));
    }
    if (e.contains('facebook')) {
      return ('Facebook', Icons.facebook_rounded, const Color(0xFF1877F2));
    }
    if (e.contains('twitch')) {
      return ('Twitch', Icons.stream_rounded, const Color(0xFF9146FF));
    }
    if (e.contains('tiktok')) {
      return ('TikTok', Icons.music_video_rounded, const Color(0xFF69C9D0));
    }
    if (e.contains('twitter') || e.contains('x.com')) {
      return ('Twitter/X', Icons.alternate_email_rounded, const Color(0xFF1DA1F2));
    }
    if (e.contains('vimeo')) {
      return ('Vimeo', Icons.play_circle_outline_rounded, const Color(0xFF1AB7EA));
    }
    return ('Video', Icons.videocam_rounded, const Color(0xFF94A3B8));
  }

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = _meta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        border: Border.all(color: color.withOpacity(0.60)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
