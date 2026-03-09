import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
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
  final VoidCallback? onQueue;
  const AnalyzedScreen({super.key, this.initialUrl, this.onDownload, this.onQueue});

  @override
  State<AnalyzedScreen> createState() => _AnalyzedScreenState();
}

class _AnalyzedScreenState extends State<AnalyzedScreen> {
  int _selectedQuality = 0;
  int _selectedTab = 0; // 0 = Video, 1 = Audio
  String _selectedFormat = 'MP4';
  final Set<String> _checkOptions = {'Save Thumbnail', 'Add Chapters'};
  bool _showDetails = false;
  String? _outputPath; // per-session output folder (overrides saved default)
  ValueNotifier<bool>? _loadingNotifDismiss;
  final ScrollController _qualityScrollCtrl = ScrollController();
  bool _qCanScrollLeft = false;
  bool _qCanScrollRight = false;
  // Track last-notified fetch state to avoid duplicate notifications on every
  // notifyListeners() call while the state remains unchanged (e.g. download
  // progress updates keep firing when this screen stays mounted).
  FetchState _lastNotifiedFetchState = FetchState.idle;

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
    // Always show all quality tiers — yt-dlp will pick the closest match
    return const [
      _QOption('Best', 'Auto', badge: 'AUTO'),
      _QOption('4K', 'Ultra HD', badge: 'HDR'),
      _QOption('1440p', '2K'),
      _QOption('1080p', 'Full HD'),
      _QOption('720p', 'HD'),
      _QOption('480p', 'SD'),
      _QOption('360p', 'Low'),
    ];
  }

  List<_QOption> _qualities(VideoInfo? info) =>
      _selectedTab == 0 ? _videoQualityTiers(info) : _audioQ;

  String _summaryLabel(VideoInfo? info) {
    if (_selectedTab == 0) {
      final qs = _videoQualityTiers(info);
      final q = qs[_selectedQuality.clamp(0, qs.length - 1)];
      final maxH = info?.maxVideoHeight ?? 0;
      final tierMin = _ScrollableQualityRowState._minHeightFor(q.res);
      final String size;
      if (info == null) {
        size = '~? MB';
      } else if (tierMin > maxH && q.res != 'Best') {
        size = 'N/A';
      } else {
        size = info.estimatedSize(q.res);
      }
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

  /// Whether to use vertical layout — works even during loading by checking URL.
  bool get _isLikelyVertical {
    final info = _info;
    if (info != null) return info.isVertical;
    final url = widget.initialUrl ?? AppState.instance.currentUrl ?? '';
    return url.contains('/shorts/') || url.contains('/reel/');
  }

  @override
  void initState() {
    super.initState();
    _outputPath = AppState.instance.downloadPath;
    // Initialise with current state so we don't fire a spurious
    // "Video ready!" notification when the screen opens while
    // fetchState is already success from a previous fetch.
    _lastNotifiedFetchState = AppState.instance.fetchState;
    AppState.instance.addListener(_onStateChange);
    _qualityScrollCtrl.addListener(_updateQualityScroll);
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
    final state = AppState.instance.fetchState;
    // Only reset quality/tab/format when state *transitions* to success —
    // not on every notifyListeners() call (e.g. download progress updates).
    if (state == FetchState.success &&
        _lastNotifiedFetchState != FetchState.success) {
      setState(() {
        _selectedQuality = 0;
        _selectedTab = 0;
        _selectedFormat = 'MP4';
      });
    } else {
      setState(() {});
    }
    // Only fire a notification when the state *transitions* — not on every
    // notifyListeners() call that happens while state is unchanged.
    if (state == FetchState.success &&
        _lastNotifiedFetchState != FetchState.success) {
      _lastNotifiedFetchState = FetchState.success;
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
    } else if (state == FetchState.error &&
        _lastNotifiedFetchState != FetchState.error) {
      _lastNotifiedFetchState = FetchState.error;
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
    } else if (state == FetchState.loading || state == FetchState.idle) {
      // Reset so the next success/error will fire again.
      _lastNotifiedFetchState = state;
    }
  }

  @override
  void dispose() {
    _loadingNotifDismiss?.value = true;
    _loadingNotifDismiss = null;
    _qualityScrollCtrl.dispose();
    AppState.instance.removeListener(_onStateChange);
    super.dispose();
  }

  void _updateQualityScroll() {
    if (!_qualityScrollCtrl.hasClients) return;
    final pos = _qualityScrollCtrl.position;
    final maxExt = pos.maxScrollExtent;
    // If all tiles fit (nothing to scroll), reset offset and disable both arrows
    if (maxExt <= 0) {
      if (_qualityScrollCtrl.offset != 0) {
        _qualityScrollCtrl.jumpTo(0);
      }
      if (_qCanScrollLeft || _qCanScrollRight) {
        setState(() {
          _qCanScrollLeft = false;
          _qCanScrollRight = false;
        });
      }
      return;
    }
    final canL = _qualityScrollCtrl.offset > 1;
    final canR = _qualityScrollCtrl.offset < maxExt - 1;
    if (canL != _qCanScrollLeft || canR != _qCanScrollRight) {
      setState(() {
        _qCanScrollLeft = canL;
        _qCanScrollRight = canR;
      });
    }
  }

  void _scrollQuality(double delta) {
    _qualityScrollCtrl.animateTo(
      (_qualityScrollCtrl.offset + delta).clamp(
        0.0,
        _qualityScrollCtrl.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLikelyVertical) {
      return _buildVerticalLayout();
    }
    return _buildHorizontalLayout();
  }

  Widget _buildHorizontalLayout() {
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

  Widget _buildVerticalLayout() {
    if (_showSkeleton) return _buildVerticalSkeleton();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column (Thumbnail + Details)
        SizedBox(
          width: 350,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface1,
              border: Border.all(color: AppColors.green.withOpacity(0.58)),
              borderRadius: BorderRadius.circular(AppColors.radius),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child:
                      _isLoading
                          ? _buildThumbSkeleton()
                          : _buildThumb(isVertical: true),
                ),
                _isLoading ? _buildInfoPanelSkeleton() : _buildInfoPanel(),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppColors.gap),
        // Right Column (Config + Action Bar)
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: SingleChildScrollView(child: _buildConfigCard())),
              const SizedBox(height: AppColors.gap),
              _buildActionBar(),
            ],
          ),
        ),
      ],
    );
  }

  // ── VIDEO HEADER ───────────────────────────────────────────────────────────

  Widget _buildVerticalSkeleton() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column skeleton
        SizedBox(
          width: 350,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface1,
              border: Border.all(color: AppColors.green.withOpacity(0.12)),
              borderRadius: BorderRadius.circular(AppColors.radius),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(child: ShimmerBox(borderRadius: 0)),
                _buildInfoPanelSkeleton(),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppColors.gap),
        // Right Column skeleton
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: _buildConfigCardSkeleton(),
                ),
              ),
              const SizedBox(height: AppColors.gap),
              _buildActionBarSkeleton(),
            ],
          ),
        ),
      ],
    );
  }

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

  Widget _buildThumb({bool isVertical = false}) {
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
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.75), Colors.transparent],
              ),
            ),
          ),
        ),
        // Quality badge — top left
        Positioned(
          top: 12,
          left: 12,
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
                const Icon(
                  Icons.high_quality_rounded,
                  size: 11,
                  color: AppColors.green,
                ),
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
          bottom: 12,
          left: 12,
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
          bottom: 12,
          right: 12,
          child: _PlatformBadge(extractor: _info?.extractor),
        ),
        // Right-edge blend so the thumbnail fades into the container bg (only needed for horizontal stacked)
        if (!isVertical)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
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
            style: AppTextStyles.spaceGrotesk(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 11),
          if (info != null) _buildChannelRow(info),
          const SizedBox(height: 11),
          if (info != null) _buildMetaChips(info),
          const SizedBox(height: 11),
          _buildUrlAndPathRow(url),
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
          Row(
            children: const [
              ShimmerBox(width: 26, height: 26, borderRadius: 13),
              SizedBox(width: 8),
              ShimmerBox(width: 120, height: 14),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(
              4,
              (_) => const ShimmerBox(width: 80, height: 22, borderRadius: 6),
            ),
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
          const Icon(
            Icons.check_circle_rounded,
            size: 11,
            color: AppColors.green,
          ),
          const SizedBox(width: 4),
          Text(
            'Ready',
            style: AppTextStyles.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelRow(VideoInfo info) {
    final initial =
        (info.channelName?.isNotEmpty == true)
            ? info.channelName![0].toUpperCase()
            : 'C';
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: AppColors.green,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              initial,
              style: AppTextStyles.syne(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              info.channelName ?? '',
              style: AppTextStyles.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.green,
              ),
            ),
            if (info.subscriberCount != null)
              Text(
                info.formattedSubscribers,
                style: AppTextStyles.outfit(
                  fontSize: 10,
                  color: AppColors.muted,
                ),
              ),
          ],
        ),
        const Spacer(),
        if (info.viewCount != null)
          _miniChip(Icons.visibility_outlined, info.formattedViews),
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
          Text(
            label,
            style: AppTextStyles.outfit(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChips(VideoInfo info) {
    final items = <(IconData, String)>[
      if (info.formattedDate.isNotEmpty)
        (Icons.calendar_today_outlined, info.formattedDate),
      if (info.likeCount != null)
        (
          Icons.thumb_up_outlined,
          '${(info.likeCount! / 1000).toStringAsFixed(0)}K liked',
        ),
      (Icons.high_quality_outlined, info.bestQualityLabel),
      (Icons.access_time_rounded, info.formattedDuration),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.map((i) => _miniChip(i.$1, i.$2)).toList(),
    );
  }

  Widget _buildUrlBar(String url) {
    final display = url
        .replaceFirst('https://', '')
        .replaceFirst('http://', '');
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
            Expanded(
              child: Text(
                display.isEmpty ? '—' : display,
                style: AppTextStyles.outfit(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.copy_rounded, size: 12, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlAndPathRow(String url) {
    final display = url
        .replaceFirst('https://', '')
        .replaceFirst('http://', '');
    final path = _outputPath ?? AppState.instance.downloadPath ?? '';
    final displayPath = path.isEmpty ? 'Default folder' : path;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        // URL copy bar
        GestureDetector(
          onTap: () => Clipboard.setData(ClipboardData(text: url)),
          child: Container(
            constraints: const BoxConstraints(minWidth: 160),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.link_rounded,
                  size: 12,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    display.isEmpty ? '—' : display,
                    style: AppTextStyles.outfit(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.copy_rounded,
                  size: 12,
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
        ),
        // Folder picker
        GestureDetector(
          onTap: _pickOutputFolder,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              constraints: const BoxConstraints(minWidth: 120),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.folder_outlined,
                    size: 12,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      displayPath,
                      style: AppTextStyles.mono(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.green.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: AppColors.green.withOpacity(0.35),
                      ),
                    ),
                    child: Text(
                      'Browse',
                      style: AppTextStyles.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.green.withOpacity(0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'CONFIGURE DOWNLOAD',
                style: AppTextStyles.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              _buildTabSwitch(),
            ],
          ),
          const SizedBox(height: 20),

          // ── Quality
          Row(
            children: [
              _sectionLabel('QUALITY'),
              const Spacer(),
              _smallArrow(Icons.chevron_left_rounded, _qCanScrollLeft, () => _scrollQuality(-120)),
              const SizedBox(width: 4),
              _smallArrow(Icons.chevron_right_rounded, _qCanScrollRight, () => _scrollQuality(120)),
            ],
          ),
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
                    children:
                        _formats.indexed
                            .map(
                              (e) => Padding(
                                padding: EdgeInsets.only(
                                  right: e.$1 < _formats.length - 1 ? 8 : 0,
                                ),
                                child: _formatBtn(e.$2),
                              ),
                            )
                            .toList(),
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
                      spacing: 18,
                      runSpacing: 10,
                      children: [
                        // Save Thumbnail — always enabled, non-toggleable
                        _lockedOption('Save Thumbnail'),
                        ...(_selectedTab == 0
                                ? ['Add Chapters', 'Embed Metadata']
                                : ['Embed Cover Art', 'Embed Metadata'])
                            .map(_checkOption),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _gradientDivider(),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildFolderRow() {
    final path = _outputPath ?? AppState.instance.downloadPath ?? '';
    final displayPath = path.isEmpty ? 'Default folder' : path;
    return GestureDetector(
      onTap: _pickOutputFolder,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.folder_outlined,
                size: 13,
                color: AppColors.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  displayPath,
                  style: AppTextStyles.mono(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppColors.green.withOpacity(0.35)),
                ),
                child: Text(
                  'Browse',
                  style: AppTextStyles.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green,
                  ),
                ),
              ),
            ],
          ),
        ),
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
      onTap:
          () => setState(() {
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
            Icon(
              icon,
              size: 13,
              color: active ? Colors.black : AppColors.muted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.black : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityRow(VideoInfo? info) {
    final quals = _qualities(info);
    if (quals.isEmpty) return const SizedBox.shrink();
    return _ScrollableQualityRow(
      quals: quals,
      info: info,
      selectedQuality: _selectedQuality,
      onQualitySelected: (i) => setState(() => _selectedQuality = i),
      scrollController: _qualityScrollCtrl,
      onLayoutChanged: _updateQualityScroll,
    );
  }

  Widget _smallArrow(IconData icon, bool enabled, VoidCallback onTap) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: enabled ? AppColors.surface2 : AppColors.surface1,
            border: Border.all(
              color: enabled
                  ? AppColors.green.withOpacity(0.40)
                  : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 14,
              color: enabled ? AppColors.green : AppColors.muted.withOpacity(0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.outfit(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _gradientDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.green.withOpacity(0.20),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _formatBtn(String format) {
    final sel = _selectedFormat == format;
    final icon = _formatIcon(format);
    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = format),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppColors.green : Colors.transparent,
          border: Border.all(
            color: sel ? AppColors.green : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: sel ? Colors.black : AppColors.muted),
            const SizedBox(width: 5),
            Text(
              format,
              style: AppTextStyles.mono(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.black : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _formatIcon(String format) {
    switch (format) {
      case 'MP4': return Icons.videocam_rounded;
      case 'MKV': return Icons.movie_rounded;
      case 'WEBM': return Icons.web_rounded;
      case 'MP3': return Icons.music_note_rounded;
      case 'WAV': return Icons.graphic_eq_rounded;
      case 'FLAC': return Icons.album_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Widget _checkOption(String label) {
    final on = _checkOptions.contains(label);
    return GestureDetector(
      onTap:
          () => setState(
            () => on ? _checkOptions.remove(label) : _checkOptions.add(label),
          ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: on ? AppColors.green : Colors.transparent,
                border: Border.all(
                  color:
                      on ? AppColors.green : AppColors.muted.withOpacity(0.40),
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow:
                    on
                        ? [
                          BoxShadow(
                            color: AppColors.green.withOpacity(0.4),
                            blurRadius: 6,
                          ),
                        ]
                        : null,
              ),
              child:
                  on
                      ? const Center(
                        child: Icon(
                          Icons.check_rounded,
                          size: 11,
                          color: Colors.black,
                        ),
                      )
                      : null,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.outfit(
                fontSize: 12,
                color: on ? AppColors.text.withOpacity(0.88) : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Always-on option (non-toggleable, shown as checked).
  Widget _lockedOption(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: AppColors.green,
            border: Border.all(color: AppColors.green),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: AppColors.green.withOpacity(0.4),
                blurRadius: 6,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.check_rounded, size: 11, color: Colors.black),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.outfit(
            fontSize: 12,
            color: AppColors.text.withOpacity(0.88),
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.lock_rounded, size: 10, color: AppColors.green.withOpacity(0.5)),
      ],
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
          Row(
            children: const [
              ShimmerBox(width: 160, height: 12, borderRadius: 4),
              Spacer(),
              ShimmerBox(width: 110, height: 28, borderRadius: 9),
            ],
          ),
          const SizedBox(height: 20),
          // Quality rows skeleton
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              5,
              (_) => const ShimmerBox(width: 106, height: 94, borderRadius: 10),
            ),
          ),
          const SizedBox(height: 20),
          const ShimmerBox(height: 1, borderRadius: 0),
          const SizedBox(height: 20),
          Row(
            children: const [
              ShimmerBox(width: 200, height: 36, borderRadius: 8),
              SizedBox(width: 28),
              Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    if (_showSkeleton) return _buildActionBarSkeleton();
    final info = _info;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;
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
                    Text(
                      _summaryLabel(info),
                      style: AppTextStyles.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 12,
                          color: AppColors.green,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'No DRM detected',
                          style: AppTextStyles.outfit(
                            fontSize: 11,
                            color: AppColors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _ghostBtn(
                Icons.queue_rounded,
                '+ Queue',
                info != null ? () => _onQueue() : null,
                compact: compact,
              ),
              const SizedBox(width: 10),
              _primaryBtn(
                Icons.download_rounded,
                'Download Now',
                info != null ? () => _onDownload() : null,
                compact: compact,
              ),
            ],
          ),
        );
      },
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

  /// Returns the download index (0 = first, N = re-download) based on how
  /// many times this URL already appears in the downloads list.
  int _downloadIndex(String url) =>
      AppState.instance.downloads.where((d) => d.url == url).length;

  /// Checks if this URL has a completed download. If so, shows a dialog.
  /// Returns `true` if the user wants to proceed, `false` to cancel.
  Future<bool> _checkRedownload(String url) async {
    final existing =
        AppState.instance.downloads
            .where((d) => d.url == url && d.status == DownloadStatus.done)
            .toList();
    if (existing.isEmpty) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _RedownloadDialog(
            videoTitle: existing.first.title,
            existingResolution: existing.first.resolution,
            existingFormat: existing.first.format,
            newResolution: _selectedResolution,
            newFormat: _selectedFormat,
          ),
    );
    return confirmed == true;
  }

  // ── Output folder picker ───────────────────────────────────────────────────
  Future<void> _pickOutputFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      initialDirectory: _outputPath,
      dialogTitle: 'Choose output folder',
    );
    if (result != null && mounted) {
      setState(() => _outputPath = result);
    }
  }

  Future<void> _onQueue() async {
    final info = _info;
    if (info == null) return;
    final url = AppState.instance.currentUrl ?? '';
    if (!await _checkRedownload(url)) return;
    AppState.instance.enqueueDownload(
      DownloadItem(
        title: info.title,
        url: url,
        resolution: _selectedResolution,
        format: _selectedFormat,
        outputPath: _outputPath ?? AppState.instance.downloadPath ?? '',
        thumbnailUrl: info.thumbnail,
        extractor: info.extractor,
        status: DownloadStatus.queued,
        downloadIndex: _downloadIndex(url),
        videoDuration: info.duration,
      ),
    );
    widget.onQueue?.call();
  }

  Future<void> _onDownload() async {
    final info = _info;
    if (info == null) return;
    final url = AppState.instance.currentUrl ?? '';
    if (!await _checkRedownload(url)) return;
    AppState.instance.enqueueDownload(
      DownloadItem(
        title: info.title,
        url: url,
        resolution: _selectedResolution,
        format: _selectedFormat,
        outputPath: _outputPath ?? AppState.instance.downloadPath ?? '',
        thumbnailUrl: info.thumbnail,
        extractor: info.extractor,
        downloadIndex: _downloadIndex(url),
        videoDuration: info.duration,
      ),
    );
    widget.onDownload?.call();
  }

  Widget _ghostBtn(IconData icon, String label, VoidCallback? onTap, {bool compact = false}) {
    return _HoverBtn(
      onTap: onTap,
      builder:
          (hov) => Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: 9),
            decoration: BoxDecoration(
              color:
                  hov ? AppColors.green.withOpacity(0.07) : Colors.transparent,
              border: Border.all(color: AppColors.green.withOpacity(0.40)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: AppColors.green),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTextStyles.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.green,
                    ),
                  ),
                ],
              ],
            ),
          ),
    );
  }

  Widget _primaryBtn(IconData icon, String label, VoidCallback? onTap, {bool compact = false}) {
    return _HoverBtn(
      onTap: onTap,
      builder:
          (hov) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 22, vertical: 10),
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
            transform:
                hov
                    ? (Matrix4.identity()..translate(0.0, -1.0))
                    : Matrix4.identity(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: Colors.black),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTextStyles.syne(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ],
              ],
            ),
          ),
    );
  }

  // ── DETAILS TOGGLE ─────────────────────────────────────────────────────────

  Widget _buildDetailsToggle() {
    if (_info == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => setState(() => _showDetails = !_showDetails),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            border: Border.all(color: AppColors.green.withOpacity(0.18)),
            borderRadius: BorderRadius.circular(AppColors.radius),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: AppColors.muted,
              ),
              const SizedBox(width: 8),
              Text(
                'Video Details',
                style: AppTextStyles.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: _showDetails ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── DETAILS PANEL ──────────────────────────────────────────────────────────

  Widget _buildDetailsPanel(VideoInfo info) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.green.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Stats row ──────────────────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (info.viewCount != null)
                _detailChip(
                  Icons.visibility_outlined,
                  '${_formatNumber(info.viewCount!)} views',
                ),
              if (info.likeCount != null)
                _detailChip(
                  Icons.thumb_up_outlined,
                  '${_formatNumber(info.likeCount!)} likes',
                ),
              if (info.formattedDate.isNotEmpty)
                _detailChip(Icons.calendar_today_outlined, info.formattedDate),
              _detailChip(Icons.high_quality_outlined, info.bestQualityLabel),
              _detailChip(Icons.access_time_rounded, info.formattedDuration),
              if (info.extractor != null && info.extractor!.isNotEmpty)
                _detailChip(Icons.source_rounded, info.extractor!),
              _detailChip(
                Icons.movie_filter_rounded,
                '${info.formats.length} formats available',
              ),
            ],
          ),

          // ── Description ────────────────────────────────────────────────────
          if (info.description != null && info.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _detailSectionLabel('DESCRIPTION'),
            const SizedBox(height: 8),
            _ExpandableText(text: info.description!),
          ],
        ],
      ),
    );
  }

  Widget _detailSectionLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.outfit(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _detailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.green),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }
}

// ── Expandable description text ───────────────────────────────────────────────

class _ExpandableText extends StatefulWidget {
  final String text;
  const _ExpandableText({required this.text});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: Text(
            widget.text,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: AppTextStyles.outfit(
              fontSize: 12,
              color: AppColors.muted,
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Text(
              _expanded ? 'Show less' : 'Show more',
              style: AppTextStyles.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.green,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Scrollable quality row with arrow buttons ────────────────────────────────

class _ScrollableQualityRow extends StatefulWidget {
  final List<_QOption> quals;
  final VideoInfo? info;
  final int selectedQuality;
  final ValueChanged<int> onQualitySelected;
  final ScrollController scrollController;
  final VoidCallback? onLayoutChanged;

  const _ScrollableQualityRow({
    required this.quals,
    required this.info,
    required this.selectedQuality,
    required this.onQualitySelected,
    required this.scrollController,
    this.onLayoutChanged,
  });

  @override
  State<_ScrollableQualityRow> createState() => _ScrollableQualityRowState();
}

class _ScrollableQualityRowState extends State<_ScrollableQualityRow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onLayoutChanged?.call();
    });
  }

  /// Map resolution label to the minimum height it requires.
  static int _minHeightFor(String res) {
    switch (res) {
      case '4K':   return 2160;
      case '1440p': return 1440;
      case '1080p': return 1080;
      case '720p':  return 720;
      case '480p':  return 480;
      case '360p':  return 360;
      case '240p':  return 240;
      case '144p':  return 144;
      default:      return 0; // 'Best' and audio tiers always have a size
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = widget.info?.maxVideoHeight ?? 0;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        // Layout changed (window resize) — re-evaluate arrow state
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onLayoutChanged?.call();
        });
        return false;
      },
      child: SizedBox(
        height: 120,
        child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              final ctrl = widget.scrollController;
              ctrl.animateTo(
                (ctrl.offset + event.scrollDelta.dy).clamp(
                  0.0,
                  ctrl.position.maxScrollExtent,
                ),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
              );
            }
          },
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
            ),
            child: ListView.separated(
              controller: widget.scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: widget.quals.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final q = widget.quals[i];
                final tierMin = _minHeightFor(q.res);
                // Show 'N/A' for tiers above the video's actual best quality
                final String sizeStr;
                if (widget.info == null) {
                  sizeStr = '~? MB';
                } else if (tierMin > maxH && q.res != 'Best') {
                  sizeStr = 'N/A';
                } else {
                  sizeStr = widget.info!.estimatedSize(q.res);
                }
                return GestureDetector(
                  onTap: () => widget.onQualitySelected(i),
                  child: _QualityTile(
                    res: q.res,
                    name: q.name,
                    size: sizeStr,
                    badge: q.badge,
                    isSelected: widget.selectedQuality == i,
                  ),
                );
            },
            ),
          ),
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
      case 'Best':
        return Icons.auto_awesome_rounded;
      case '4K':
      case '1440p':
        return Icons.hd_rounded;
      case '1080p':
        return Icons.high_quality_rounded;
      case '720p':
        return Icons.hd_outlined;
      case '480p':
      case '360p':
        return Icons.sd_rounded;
      default:
        if (res.endsWith('k')) return Icons.music_note_rounded;
        return Icons.signal_cellular_4_bar_rounded;
    }
  }

  static Color _accentFor(String res) {
    switch (res) {
      case 'Best':
        return AppColors.green;
      case '4K':
        return const Color(0xFF8B5CF6);
      case '1440p':
        return AppColors.blue;
      case '1080p':
        return AppColors.green;
      case '720p':
        return const Color(0xFF0EA5E9);
      case '480p':
        return AppColors.yellow;
      case '360p':
      case '240p':
        return const Color(0xFFF97316);
      case '144p':
        return AppColors.red;
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
        height: 120,
        decoration: BoxDecoration(
          color:
              sel
                  ? accent.withValues(alpha: 0.09)
                  : (_hov ? AppColors.surface3 : AppColors.surface2),
          border: Border.all(
            color:
                sel
                    ? accent.withValues(alpha: 0.60)
                    : (_hov
                        ? AppColors.green.withValues(alpha: 0.20)
                        : AppColors.border),
            width: sel ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow:
              sel
                  ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
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
                          color: (sel ? accent : AppColors.muted).withValues(
                            alpha: 0.10,
                          ),
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
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            border: Border.all(
                              color: badgeColor.withValues(alpha: 0.38),
                            ),
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
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.check_rounded,
                              size: 10,
                              color: Colors.black,
                            ),
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
                      color:
                          sel
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
                      color:
                          sel
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
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(onTap: widget.onTap, child: widget.builder(_hov)),
    );
  }
}

// ── Grid painter ──────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const step = 24.0;
    final paint =
        Paint()
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
      return (
        'YouTube',
        Icons.play_circle_fill_rounded,
        const Color(0xFFFF4444),
      );
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
      return (
        'Twitter/X',
        Icons.alternate_email_rounded,
        const Color(0xFF1DA1F2),
      );
    }
    if (e.contains('vimeo')) {
      return (
        'Vimeo',
        Icons.play_circle_outline_rounded,
        const Color(0xFF1AB7EA),
      );
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

// ── Re-download confirmation dialog ───────────────────────────────────────────

class _RedownloadDialog extends StatelessWidget {
  final String videoTitle;
  final String existingResolution;
  final String existingFormat;
  final String newResolution;
  final String newFormat;

  const _RedownloadDialog({
    required this.videoTitle,
    required this.existingResolution,
    required this.existingFormat,
    required this.newResolution,
    required this.newFormat,
  });

  @override
  Widget build(BuildContext context) {
    final sameQuality =
        existingResolution == newResolution && existingFormat == newFormat;
    return Dialog(
      backgroundColor: AppColors.surface1,
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.yellow.withOpacity(0.28)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.yellow.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.yellow,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Already Downloaded',
                      style: AppTextStyles.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Video title
              Text(
                videoTitle,
                style: AppTextStyles.outfit(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // Comparison row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    // Existing
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current',
                            style: AppTextStyles.outfit(
                              fontSize: 10,
                              color: AppColors.muted2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$existingResolution · $existingFormat',
                            style: AppTextStyles.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppColors.muted2,
                    ),
                    // New
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'New',
                            style: AppTextStyles.outfit(
                              fontSize: 10,
                              color: AppColors.muted2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$newResolution · $newFormat',
                            style: AppTextStyles.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                sameQuality
                    ? 'The new file will be saved with a numbered suffix (e.g. "title (1)") to avoid overwriting the existing one.'
                    : 'Both files will be saved — a numbered suffix will be added to the new file.',
                style: AppTextStyles.outfit(
                  fontSize: 11,
                  color: AppColors.muted2,
                ),
              ),
              const SizedBox(height: 20),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Download Again',
                          style: AppTextStyles.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
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
  }
}
