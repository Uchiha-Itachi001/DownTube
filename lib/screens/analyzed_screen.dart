import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

// ─── Data model ─────────────────────────────────────────────────────────────

class _QOption {
  final String res;
  final String name;
  final String size;
  final String? badge;
  const _QOption(this.res, this.name, this.size, {this.badge});
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class AnalyzedScreen extends StatefulWidget {
  final VoidCallback? onDownload;
  const AnalyzedScreen({super.key, this.onDownload});

  @override
  State<AnalyzedScreen> createState() => _AnalyzedScreenState();
}

class _AnalyzedScreenState extends State<AnalyzedScreen> {
  int _selectedQuality = 1;
  int _selectedTab = 0; // 0 = Video, 1 = Audio
  String _selectedFormat = 'MP4';
  final Set<String> _checkOptions = {'Embed Subtitles', 'Save Thumbnail'};

  static const _videoFormats = ['MP4', 'MKV', 'WEBM'];
  static const _audioFormats = ['MP3', 'WAV', 'FLAC'];

  static const _videoQ = [
    _QOption('4K',    'Ultra HD', '~2.1 GB', badge: 'HDR'),
    _QOption('1080p', 'Full HD',  '~450 MB'),
    _QOption('720p',  'HD',       '~180 MB'),
    _QOption('480p',  'SD',       '~90 MB'),
    _QOption('360p',  'Low',      '~48 MB'),
  ];
  static const _audioQ = [
    _QOption('320k', 'HQ Audio', '~42 MB'),
    _QOption('192k', 'Standard', '~25 MB'),
    _QOption('128k', 'Normal',   '~17 MB'),
  ];

  List<_QOption> get _qualities => _selectedTab == 0 ? _videoQ : _audioQ;
  List<String>   get _formats   => _selectedTab == 0 ? _videoFormats : _audioFormats;

  String get _summaryLabel {
    final q = _qualities[_selectedQuality.clamp(0, _qualities.length - 1)];
    return '${q.res} · ${q.size} · $_selectedFormat';
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
            SizedBox(width: 210, child: _buildThumb()),
            Expanded(child: _buildInfoPanel()),
          ],
        ),
      ),
    );
  }

  Widget _buildThumb() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A2E1A), Color(0xFF0D1F0D), Color(0xFF091509)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        CustomPaint(painter: _GridPainter()),
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 0.85,
              colors: [AppColors.green.withOpacity(0.10), Colors.transparent],
            ),
          ),
        ),
        // Play button
        Center(
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.60),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.30), width: 1.5),
              boxShadow: [BoxShadow(color: AppColors.green.withOpacity(0.35), blurRadius: 22)],
            ),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.only(left: 3),
                child: Icon(Icons.play_arrow_rounded, size: 24, color: Colors.white),
              ),
            ),
          ),
        ),
        // 4K badge
        Positioned(
          top: 8, left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.14),
              border: Border.all(color: AppColors.green.withOpacity(0.45)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('4K', style: AppTextStyles.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.green)),
          ),
        ),
        // Duration
        Positioned(
          bottom: 8, right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.82), borderRadius: BorderRadius.circular(4)),
            child: Text('14:32', style: AppTextStyles.outfit(fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        ),
        // Bottom scrim
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.35), Colors.transparent],
              ),
            ),
          ),
        ),
        // Vertical right-edge fade into card bg
        Positioned(
          right: 0, top: 0, bottom: 0,
          child: Container(
            width: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight, end: Alignment.centerLeft,
                colors: [AppColors.surface1, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [_platformBadge(), const SizedBox(width: 7), _readyBadge()]),
          const SizedBox(height: 10),
          Text(
            'Building a Full Stack App with Next.js 14 & Supabase — Complete Course',
            style: AppTextStyles.syne(fontSize: 14, fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 11),
          _buildChannelRow(),
          const SizedBox(height: 11),
          _buildMetaChips(),
          const SizedBox(height: 11),
          _buildUrlBar(),
        ],
      ),
    );
  }

  Widget _platformBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.10),
        border: Border.all(color: Colors.red.withOpacity(0.22)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_circle_fill_rounded, size: 11, color: Color(0xFFF87171)),
          const SizedBox(width: 4),
          Text('YouTube', style: AppTextStyles.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFF87171))),
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

  Widget _buildChannelRow() {
    return Row(
      children: [
        Container(
          width: 26, height: 26,
          decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
          child: Center(child: Text('F', style: AppTextStyles.syne(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black))),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('@Fireship', style: AppTextStyles.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.green)),
            Text('2.1M subscribers', style: AppTextStyles.outfit(fontSize: 10, color: AppColors.muted)),
          ],
        ),
        const Spacer(),
        _miniChip(Icons.visibility_outlined, '4.2M views'),
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

  Widget _buildMetaChips() {
    final items = [
      (Icons.calendar_today_outlined, 'Dec 2024'),
      (Icons.thumb_up_outlined, '98% liked'),
      (Icons.high_quality_outlined, '4K · HDR'),
      (Icons.access_time_rounded, '14:32'),
    ];
    return Wrap(
      spacing: 6, runSpacing: 6,
      children: items.map((i) => _miniChip(i.$1, i.$2)).toList(),
    );
  }

  Widget _buildUrlBar() {
    const url = 'youtube.com/watch?v=dQw4w9WgXcQ';
    return GestureDetector(
      onTap: () => Clipboard.setData(const ClipboardData(text: 'https://$url')),
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
            Expanded(child: Text(url, style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            const Icon(Icons.copy_rounded, size: 12, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  // ── CONFIG CARD ────────────────────────────────────────────────────────────

  Widget _buildConfigCard() {
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
          _buildQualityRow(),
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

  Widget _buildQualityRow() {
    final quals = _qualities;
    return Row(
      children: List.generate(quals.length, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < quals.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedQuality = i),
              child: _QualityTile(
                res: quals[i].res,
                name: quals[i].name,
                size: quals[i].size,
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

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 13, 18, 13),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.green.withOpacity(0.18)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Row(
        children: [
          // Summary info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_summaryLabel,
                  style: AppTextStyles.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text('Est. ~2 min  ·  ',
                      style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted)),
                    const Icon(Icons.check_circle_outline_rounded, size: 12, color: AppColors.green),
                    const SizedBox(width: 3),
                    Text('No DRM detected',
                      style: AppTextStyles.outfit(fontSize: 11, color: AppColors.green)),
                  ],
                ),
              ],
            ),
          ),
          _ghostBtn(Icons.queue_rounded, '+ Queue', widget.onDownload),
          const SizedBox(width: 10),
          _primaryBtn(Icons.download_rounded, 'Download Now', widget.onDownload),
        ],
      ),
    );
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: sel
              ? AppColors.green.withOpacity(0.08)
              : (_hov ? AppColors.surface3 : AppColors.surface2),
          border: Border.all(
            color: sel
                ? AppColors.green
                : (_hov ? AppColors.green.withOpacity(0.28) : AppColors.border),
            width: sel ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: sel
              ? [BoxShadow(color: AppColors.green.withOpacity(0.16), blurRadius: 18, offset: const Offset(0, 4))]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.res,
                  style: AppTextStyles.syne(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: sel ? AppColors.green : AppColors.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 3),
                Text(
                  widget.name,
                  style: AppTextStyles.outfit(fontSize: 10, color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.green.withOpacity(0.14) : AppColors.bg.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                    border: sel ? Border.all(color: AppColors.green.withOpacity(0.35)) : null,
                  ),
                  child: Text(
                    widget.size,
                    style: AppTextStyles.outfit(
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
                top: -8, right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: const BoxDecoration(
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomLeft: Radius.circular(5),
                    ),
                  ),
                  child: Text(widget.badge!,
                    style: AppTextStyles.outfit(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.black)),
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
