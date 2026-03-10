import 'dart:io';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/download_item.dart';
import '../providers/app_state.dart';
import '../widgets/section_card.dart';
import '../widgets/sparkline_chart.dart';
import '../widgets/stat_tile.dart';
import '../widgets/url_input_bar.dart';

class DownloadsScreen extends StatefulWidget {
  final Function(String url)? onAnalyze;
  const DownloadsScreen({super.key, this.onAnalyze});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  String _completedFilter = 'all';



  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final all = AppState.instance.downloads;
        final active =
            all
                .where(
                  (d) =>
                      d.status == DownloadStatus.downloading ||
                      d.status == DownloadStatus.queued,
                )
                .toList();
        final completed =
            all
                .where(
                  (d) =>
                      (d.status == DownloadStatus.done ||
                          d.status == DownloadStatus.error) &&
                      d.showInHistory,
                )
                .toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 750;
            if (narrow) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildActiveSection(active),
                    const SizedBox(height: AppColors.gap),
                    _buildCompletedSection(completed),
                    const SizedBox(height: AppColors.gap),
                    _buildSessionStats(all),
                    const SizedBox(height: AppColors.gap),
                    _buildSpeedPanel(active),
                    const SizedBox(height: AppColors.gap),
                    _buildQuickAdd(),
                  ],
                ),
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(right: AppColors.gap),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildActiveSection(active),
                        const SizedBox(height: AppColors.gap),
                        _buildCompletedSection(completed),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildSessionStats(all),
                        const SizedBox(height: AppColors.gap),
                        _buildSpeedPanel(active),
                        const SizedBox(height: AppColors.gap),
                        _buildQuickAdd(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildActiveSection(List<DownloadItem> active) {
    final inner =
        active.isEmpty
            ? _emptyState(
              'No active downloads',
              Icons.download_outlined,
              subtitle: 'Analyze a video and start a download to see it here',
            )
            : Wrap(
              spacing: 12,
              runSpacing: 12,
              children:
                  active
                      .map(
                        (item) => SizedBox(
                          width: 260,
                          child: _DownloadGridCard(
                            item: item,
                            onCancel:
                                () => AppState.instance.cancelDownload(item.id),
                          ),
                        ),
                      )
                      .toList(),
            );
    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 250),
      child: inner,
    );
    return SectionCard(
      title: 'ACTIVE DOWNLOADS',
      count: '${active.length}',
      actions:
          active.isNotEmpty
              ? [
                SectionAction(
                  label: 'Clear Done',
                  icon: Icons.clear_all_rounded,
                  onTap: () {},
                ),
              ]
              : null,
      child: body,
    );
  }

  Widget _buildCompletedSection(List<DownloadItem> completed) {
    final doneCount =
        completed.where((d) => d.status == DownloadStatus.done).length;
    final errorCount =
        completed.where((d) => d.status == DownloadStatus.error).length;
    final filtered =
        (switch (_completedFilter) {
          'done' =>
            completed.where((d) => d.status == DownloadStatus.done).toList(),
          'error' =>
            completed.where((d) => d.status == DownloadStatus.error).toList(),
          _ => completed,
        }).take(10).toList(); // cap at 10 most recent
    final inner =
        filtered.isEmpty
            ? _emptyState(
              'No completed downloads',
              Icons.check_circle_outline_rounded,
              subtitle: 'Finished downloads will appear here',
            )
            : Wrap(
              spacing: 12,
              runSpacing: 12,
              children:
                  filtered
                      .map(
                        (item) => SizedBox(
                          width: 200,
                          child: _DownloadGridCard(item: item),
                        ),
                      )
                      .toList(),
            );
    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 250),
      child: inner,
    );
    return SectionCard(
      title: 'COMPLETED',
      count: '${completed.length}',
      actions: [
        _FilterTab(
          label: 'All',
          selected: _completedFilter == 'all',
          count: completed.length,
          onTap: () => setState(() => _completedFilter = 'all'),
        ),
        const SizedBox(width: 4),
        _FilterTab(
          label: 'Done',
          selected: _completedFilter == 'done',
          count: doneCount,
          onTap: () => setState(() => _completedFilter = 'done'),
        ),
        const SizedBox(width: 4),
        _FilterTab(
          label: 'Error',
          selected: _completedFilter == 'error',
          count: errorCount,
          onTap: () => setState(() => _completedFilter = 'error'),
        ),
      ],
      child: body,
    );
  }

  Widget _emptyState(String label, IconData icon, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentDim,
                border: Border.all(color: AppColors.accent.withOpacity(0.30), width: 1),
              ),
              child: Icon(icon, size: 24, color: AppColors.accent.withOpacity(0.70)),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: AppTextStyles.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.outfit(
                  fontSize: 11,
                  color: AppColors.muted2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSessionStats(List<DownloadItem> all) {
    final done = all.where((d) => d.status == DownloadStatus.done).length;
    final active =
        all.where((d) => d.status == DownloadStatus.downloading).length;
    return SectionCard(
      title: 'SESSION STATS',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(value: '$active', label: 'Active', unit: ''),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(value: '$done', label: 'Done Today', unit: ''),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedPanel(List<DownloadItem> active) {
    final rawSpeed = active.isNotEmpty ? (active.first.speed ?? '') : '';
    // Parse "369.91KiB/s" or "12.4 MiB/s" → (num, unit)
    String speedNum = '—';
    String speedUnit = '';
    if (rawSpeed.isNotEmpty) {
      final parts = rawSpeed.trim().split(' ');
      if (parts.length >= 2) {
        speedNum = parts[0];
        speedUnit = parts.sublist(1).join(' ');
      } else {
        // No space separator (e.g. "369.91KiB/s")
        final m = RegExp(r'^([\d.]+)(.+)$').firstMatch(rawSpeed.trim());
        speedNum = m?.group(1) ?? rawSpeed;
        speedUnit = m?.group(2)?.trim() ?? '';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceTransparent,
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE SPEED',
                style: AppTextStyles.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    speedNum,
                    style: AppTextStyles.syne(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (speedUnit.isNotEmpty) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Text(
                    speedUnit,
                    style: AppTextStyles.outfit(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SparklineChart(
            values:
                active.isNotEmpty && active.first.speedHistory.isNotEmpty
                    ? List.of(active.first.speedHistory)
                    : const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            height: 50,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAdd() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceTransparent,
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK ADD',
            style: AppTextStyles.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          UrlInputBar(compact: true, onAnalyze: (url) => widget.onAnalyze?.call(url)),
        ],
      ),
    );
  }
}

// Download grid card (LibraryCard-styled)
class _DownloadGridCard extends StatefulWidget {
  final DownloadItem item;
  final VoidCallback? onCancel;

  const _DownloadGridCard({required this.item, this.onCancel});

  @override
  State<_DownloadGridCard> createState() => _DownloadGridCardState();
}

class _DownloadGridCardState extends State<_DownloadGridCard> {
  bool _hovered = false;

  bool get _isAudio {
    final f = widget.item.format.toLowerCase();
    return f == 'mp3' || f == 'wav' || f == 'flac' || f == 'aac' || f == 'm4a';
  }

  Color get _accent => _isAudio ? const Color(0xFF3B82F6) : AppColors.accent;

  bool get _isActive =>
      widget.item.status == DownloadStatus.downloading ||
      widget.item.status == DownloadStatus.queued;

  // Phase helpers
  (String, IconData, Color) get _phaseInfo {
    final item = widget.item;
    if (item.status == DownloadStatus.queued) {
      return ('Queued', Icons.hourglass_top_rounded, const Color(0xFFEAB308));
    }
    if (item.status == DownloadStatus.error) {
      return ('Error', Icons.error_outline_rounded, AppColors.red);
    }
    if (item.status == DownloadStatus.done) {
      return ('Complete', Icons.check_circle_rounded, AppColors.accent);
    }
    return switch (item.phase) {
      DownloadPhase.video => (
        'Downloading Video',
        Icons.movie_rounded,
        AppColors.accent,
      ),
      DownloadPhase.audio => (
        'Downloading Audio',
        Icons.music_note_rounded,
        const Color(0xFF3B82F6),
      ),
      DownloadPhase.merging => (
        'Merging',
        Icons.merge_rounded,
        const Color(0xFFF59E0B),
      ),
      DownloadPhase.complete => (
        'Complete',
        Icons.check_circle_rounded,
        AppColors.accent,
      ),
    };
  }

  Future<void> _confirmCancel() async {
    final ok = await _showConfirmDialog(
      context,
      title: 'Cancel Download',
      body: 'Stop downloading "${widget.item.title}"?',
      confirmLabel: 'Cancel Download',
      confirmColor: AppColors.red,
      icon: Icons.close_rounded,
    );
    if (ok && mounted) widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final accent = _accent;
    final (phaseLabel, phaseIcon, phaseColor) = _phaseInfo;
    final pct = (item.progress * 100).clamp(0, 100).toInt();

    final isDone = item.status == DownloadStatus.done;

    return GestureDetector(
      onDoubleTap: isDone ? () => _openFile(item) : null,
      child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform:
            _hovered
                ? (Matrix4.identity()..translate(0.0, -4.0))
                : Matrix4.identity(),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(AppColors.radius),
          border: Border.all(
            color: _hovered ? accent.withOpacity(0.45) : AppColors.border,
          ),
          boxShadow:
              _hovered
                  ? [
                    BoxShadow(
                      color: accent.withOpacity(0.18),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                  : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail
            SizedBox(
              height: 108,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppColors.radius - 1),
                ),
                child: _buildThumbnail(item, accent),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  SizedBox(
                    height: 32,
                    child: Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Phase row + percentage
                  Row(
                    children: [
                      Icon(phaseIcon, size: 12, color: phaseColor),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          phaseLabel,
                          style: AppTextStyles.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: phaseColor,
                          ),
                        ),
                      ),
                      if (_isActive) ...[
                        Text(
                          '$pct%',
                          style: AppTextStyles.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: phaseColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Progress bar (smooth, inside info section)
                  if (_isActive) ...[
                    const SizedBox(height: 6),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: item.progress),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      builder:
                          (_, v, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: v,
                              backgroundColor: AppColors.surface2,
                              valueColor: AlwaysStoppedAnimation(phaseColor),
                              minHeight: 4,
                            ),
                          ),
                    ),
                  ],
                  if (_isActive && item.speed != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.speed_rounded,
                          size: 10,
                          color: AppColors.muted2,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.speed!,
                          style: AppTextStyles.outfit(
                            fontSize: 10,
                            color: AppColors.muted2,
                          ),
                        ),
                        
                        if (item.eta != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.timer_outlined,
                            size: 10,
                            color: AppColors.muted2,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.eta!,
                            style: AppTextStyles.outfit(
                              fontSize: 10,
                              color: AppColors.muted2,
                            ),
                          ),
                          if (item.fileSize != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.data_usage_rounded,
                            size: 10,
                            color: AppColors.muted2,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            item.fileSize!,
                            style: AppTextStyles.outfit(
                              fontSize: 10,
                              color: AppColors.muted2,
                            ),
                          ),
                        ],
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Quality + action buttons row
                  Row(
                    children: [
                      _QualityBadge(
                        resolution: item.resolution,
                        format: item.format,
                      ),
                      const Spacer(),
                      if (widget.onCancel != null)
                        _ActionButton(
                          icon: Icons.close_rounded,
                          label: 'Cancel',
                          color: AppColors.red,
                          onTap: _confirmCancel,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _openFile(DownloadItem item) {
    final path = item.filePath.isNotEmpty ? item.filePath : item.outputPath;
    if (path.isEmpty || !File(path).existsSync()) return;
    Process.run('cmd', ['/c', 'start', '', path]);
  }

  Widget _buildThumbnail(DownloadItem item, Color accent) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (item.thumbnailUrl != null)
          Image.network(
            item.thumbnailUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _gradientBg(accent),
          )
        else
          _gradientBg(accent),
        // Bottom vignette
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.45, 1.0],
                colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
              ),
            ),
          ),
        ),
        // Type badge (top-left)
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.72),
              border: Border.all(color: accent.withOpacity(0.55)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isAudio ? Icons.music_note_rounded : Icons.movie_rounded,
                  size: 10,
                  color: accent,
                ),
                const SizedBox(width: 4),
                Text(
                  _isAudio ? 'AUDIO' : 'VIDEO',
                  style: AppTextStyles.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Status indicator (top-right) — pulsing dot for active
        if (_isActive)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _gradientBg(Color accent) => Container(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        colors: [
          accent.withOpacity(0.28),
          _isAudio ? const Color(0xFF080C18) : const Color(0xFF07110A),
        ],
        center: Alignment.center,
        radius: 1.1,
      ),
    ),
  );
}

// Quality badge
class _QualityBadge extends StatelessWidget {
  final String resolution;
  final String format;
  const _QualityBadge({required this.resolution, required this.format});

  @override
  Widget build(BuildContext context) {
    final isAudio = resolution.endsWith('k');
    final color = isAudio ? const Color(0xFF3B82F6) : AppColors.accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Text(
            resolution,
            style: AppTextStyles.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            format.toUpperCase(),
            style: AppTextStyles.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

// Action button with hover effect
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color:
                _hovered
                    ? widget.color.withOpacity(0.22)
                    : widget.color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color:
                  _hovered
                      ? widget.color.withOpacity(0.6)
                      : widget.color.withOpacity(0.28),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 12, color: widget.color),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: AppTextStyles.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Confirmation dialog helper
Future<bool> _showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required Color confirmColor,
  required IconData icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.6),
    builder:
        (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: confirmColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: confirmColor.withOpacity(0.30),
                        ),
                      ),
                      child: Icon(icon, size: 18, color: confirmColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  body,
                  style: AppTextStyles.outfit(
                    fontSize: 12,
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DialogBtn(
                      label: 'Keep',
                      onTap: () => Navigator.of(ctx).pop(false),
                      primary: false,
                    ),
                    const SizedBox(width: 10),
                    _DialogBtn(
                      label: confirmLabel,
                      color: confirmColor,
                      onTap: () => Navigator.of(ctx).pop(true),
                      primary: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
  );
  return result ?? false;
}

class _DialogBtn extends StatefulWidget {
  final String label;
  final Color? color;
  final VoidCallback onTap;
  final bool primary;
  const _DialogBtn({
    required this.label,
    this.color,
    required this.onTap,
    required this.primary,
  });

  @override
  State<_DialogBtn> createState() => _DialogBtnState();
}

class _DialogBtnState extends State<_DialogBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? AppColors.muted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color:
                widget.primary
                    ? (_hovered ? c.withOpacity(0.25) : c.withOpacity(0.14))
                    : (_hovered ? AppColors.surface2 : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  widget.primary
                      ? (_hovered ? c.withOpacity(0.7) : c.withOpacity(0.40))
                      : AppColors.border,
            ),
          ),
          child: Text(
            widget.label,
            style: AppTextStyles.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: widget.primary ? c : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

// Completed-section filter tab
class _FilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.accent.withOpacity(0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? AppColors.accent.withOpacity(0.40) : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.outfit(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.accent : AppColors.muted,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: AppTextStyles.outfit(
                  fontSize: 9,
                  color:
                      selected
                          ? AppColors.accent.withOpacity(0.75)
                          : AppColors.muted2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

