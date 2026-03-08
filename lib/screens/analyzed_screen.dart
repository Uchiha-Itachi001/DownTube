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
        _QOption('4K', 'Ultra HD', badge: 'HDR'),
        _QOption('1080p', 'Full HD'),
        _QOption('720p', 'HD'),
        _QOption('480p', 'SD'),
        _QOption('360p', 'Low'),
      ];
    }
    // Extract unique heights from actual yt-dlp formats, sorted descending
    final rawHeights = info.formats
        .where((f) => f.hasVideo && f.height != null && f.height! >= 144)
        .map((f) => f.height!)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

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
      } else {
        q = _QOption('${h}p', 'Low');
      }
      if (seen.add(q.res)) result.add(q);
    }
    return result.isEmpty ? [const _QOption('720p', 'HD')] : result;
  }

  List<_QOption> _qualities(VideoInfo? info) =>
      _selectedTab == 0 ? _videoQualityTiers(info) : _audioQ;

  String _summaryLabel(VideoInfo? info) {
    final qs = _qualities(info);
    if (qs.isEmpty) return '$_selectedFormat';
    final q = qs[_selectedQuality.clamp(0, qs.length - 1)];
    final size = info?.estimatedSize(q.res) ?? '~? MB';
    return '${q.res} · $size · $_selectedFormat';
  }

  bool get _isLoading => AppState.instance.fetchState == FetchState.loading;
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
        showAppNotification(
          context,
          type: NotificationType.loading,
          message: 'Fetching video info…',
          subtitle: widget.initialUrl,
          duration: const Duration(seconds: 30),
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
    if (AppState.instance.fetchState == FetchState.error) {
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
              width: 290,
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
        // Play button
        Center(
          child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
              boxShadow: [
                BoxShadow(color: AppColors.green.withOpacity(0.40), blurRadius: 32, spreadRadius: 2),
              ],
            ),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.play_arrow_rounded, size: 34, color: Colors.white),
              ),
            ),
          ),
        ),
        // Quality badge — top left
        Positioned(
          top: 12, left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.16),
              border: Border.all(color: AppColors.green.withOpacity(0.50)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              _info?.bestQualityLabel ?? '—',
              style: AppTextStyles.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.green,
              ),
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.18),
              border: Border.all(color: Colors.red.withOpacity(0.30)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_circle_fill_rounded, size: 12, color: Color(0xFFF87171)),
                const SizedBox(width: 4),
                Text(
                  _extractorLabel,
                  style: AppTextStyles.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF87171),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String get _extractorLabel {
    final e = _info?.extractor?.toLowerCase() ?? 'youtube';
    if (e.contains('youtube')) return 'YouTube';
    if (e.contains('vimeo')) return 'Vimeo';
    if (e.contains('twitch')) return 'Twitch';
    if (e.contains('tiktok')) return 'TikTok';
    return _info?.extractor ?? 'Video';
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
    return Row(
      children: List.generate(quals.length, (i) {
        final sizeStr = info?.estimatedSize(quals[i].res) ?? '~? MB';
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < quals.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedQuality = i),
              child: _QualityTile(
                res: quals[i].res,
                name: quals[i].name,
                size: sizeStr,
                badge: quals[i].badge,
                isSelected: _selectedQuality == i,
              ),
            ),
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
          const ShimmerBox(width: 60, height: 10, borderRadius: 4),
          const SizedBox(height: 10),
          Row(children: List.generate(5, (i) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < 4 ? 8 : 0),
              child: const ShimmerBox(height: 78, borderRadius: 12),
            ),
          ))),
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

  void _onQueue() {
    final info = _info;
    if (info == null) return;
    final qs = _qualities(info);
    final q = qs[_selectedQuality.clamp(0, qs.length - 1)];
    AppState.instance.enqueueDownload(DownloadItem(
      title: info.title,
      url: AppState.instance.currentUrl ?? '',
      resolution: q.res,
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
    final qs = _qualities(info);
    final q = qs[_selectedQuality.clamp(0, qs.length - 1)];
    AppState.instance.enqueueDownload(DownloadItem(
      title: info.title,
      url: AppState.instance.currentUrl ?? '',
      resolution: q.res,
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

  @override
  Widget build(BuildContext context) {
    final sel = widget.isSelected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit:  (_) => setState(() => _hov = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.green.withOpacity(0.09)
              : (_hov ? AppColors.surface3 : AppColors.surface2),
          border: Border.all(
            color: sel
                ? AppColors.green
                : (_hov ? AppColors.green.withOpacity(0.28) : AppColors.border),
            width: sel ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: sel
              ? [
                  BoxShadow(color: AppColors.green.withOpacity(0.18), blurRadius: 20, offset: const Offset(0, 4)),
                  BoxShadow(color: AppColors.green.withOpacity(0.06), blurRadius: 40, spreadRadius: 2),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Resolution — Space Grotesk for that technical number feel
                Text(
                  widget.res,
                  style: AppTextStyles.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: sel ? AppColors.green : AppColors.text,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                // Quality name — Outfit, subdued label
                Text(
                  widget.name,
                  style: AppTextStyles.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // File size — JetBrains Mono for data value aesthetic
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.green.withOpacity(0.14)
                        : AppColors.bg.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(5),
                    border: sel
                        ? Border.all(color: AppColors.green.withOpacity(0.35))
                        : Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    widget.size,
                    style: AppTextStyles.mono(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: sel ? AppColors.green : AppColors.muted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            if (widget.badge != null)
              Positioned(
                top: -10, right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: const BoxDecoration(
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(10),
                      bottomLeft: Radius.circular(6),
                    ),
                  ),
                  child: Text(
                    widget.badge!,
                    style: AppTextStyles.spaceGrotesk(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
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
