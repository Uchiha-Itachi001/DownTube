import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/download_item.dart';

class DownloadItemTile extends StatelessWidget {
  final DownloadItem item;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  const DownloadItemTile({
    super.key,
    required this.item,
    this.onCancel,
    this.onDelete,
  });

  bool get _isDownloading => item.status == DownloadStatus.downloading;
  bool get _isQueued => item.status == DownloadStatus.queued;
  bool get _isActive => _isDownloading || _isQueued;
  bool get _isDone => item.status == DownloadStatus.done;
  bool get _isError => item.status == DownloadStatus.error;

  Color get _borderColor {
    if (_isDownloading) return AppColors.accent.withOpacity(0.30);
    if (_isQueued) return AppColors.yellow.withOpacity(0.25);
    if (_isError) return AppColors.red.withOpacity(0.22);
    return AppColors.border;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(color: _borderColor, width: _isDownloading ? 1.5 : 1.0),
        borderRadius: BorderRadius.circular(12),
        boxShadow: _isDownloading
            ? [BoxShadow(color: AppColors.accent.withOpacity(0.07), blurRadius: 16)]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildThumbnail(),
                const SizedBox(width: 12),
                Expanded(child: _buildContent()),
                const SizedBox(width: 10),
                _buildTrailingActions(),
              ],
            ),
          ),
          if (_isDownloading) _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    final isAudio = item.resolution.endsWith('k');
    Widget img;
    if (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty) {
      img = Image.network(
        item.thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _iconThumb(isAudio),
      );
    } else {
      img = _iconThumb(isAudio);
    }
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(width: 60, height: 60, child: img),
        ),
        Positioned(
          bottom: 3,
          right: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.80),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              item.resolution,
              style: AppTextStyles.mono(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconThumb(bool isAudio) {
    final accent = _isError
        ? AppColors.red
        : _isQueued
            ? AppColors.yellow
            : AppColors.accent;
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.12), accent.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          isAudio ? Icons.music_note_rounded : Icons.movie_rounded,
          size: 22,
          color: accent.withOpacity(0.50),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final String? phaseLabel = _isDownloading
        ? switch (item.phase) {
            DownloadPhase.video => 'Downloading video\u2026',
            DownloadPhase.audio => 'Downloading audio\u2026',
            DownloadPhase.merging => 'Merging streams\u2026',
            DownloadPhase.complete => null,
          }
        : null;

    final String? speedEta = (_isDownloading &&
            (item.speed != null || item.eta != null))
        ? [
            if (item.speed != null) item.speed!,
            if (item.eta != null) 'ETA ${item.eta}',
          ].join('  \u00b7  ')
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.title,
          style: AppTextStyles.outfit(
              fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Text(
              '${item.resolution} \u00b7 ${item.format}',
              style: AppTextStyles.outfit(
                  fontSize: 11, color: AppColors.muted),
            ),
            if (_isQueued) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Queued',
                  style: AppTextStyles.outfit(
                      fontSize: 10, color: AppColors.yellow),
                ),
              ),
            ],
          ],
        ),
        if (phaseLabel != null) ...[
          const SizedBox(height: 3),
          Text(
            phaseLabel,
            style: AppTextStyles.outfit(
                fontSize: 10, color: AppColors.accent),
          ),
        ],
        if (speedEta != null) ...[
          const SizedBox(height: 2),
          Text(
            speedEta,
            style: AppTextStyles.outfit(
                fontSize: 10, color: AppColors.yellow),
          ),
        ],
        if (_isDone && item.outputPath.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.folder_outlined,
                  size: 10, color: AppColors.muted2),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  _shortPath(item.outputPath),
                  style: AppTextStyles.mono(
                      fontSize: 9, color: AppColors.muted2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        if (_isError && item.errorMessage != null) ...[
          const SizedBox(height: 3),
          Text(
            item.errorMessage!,
            style: AppTextStyles.outfit(
                fontSize: 10,
                color: AppColors.red.withOpacity(0.85)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildTrailingActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _StatusBadge(status: item.status),
        const SizedBox(height: 6),
        if (_isActive && onCancel != null)
          _ActionBtn(
            icon: Icons.close_rounded,
            color: AppColors.red,
            onTap: onCancel!,
          )
        else if (!_isActive && onDelete != null)
          _ActionBtn(
            icon: Icons.delete_outline_rounded,
            color: AppColors.muted2,
            onTap: onDelete!,
          ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final isMerging = item.phase == DownloadPhase.merging;
    final targetVal = isMerging ? 0.95 : item.progress.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      key: ValueKey('pb_${item.id}_${item.phase.index}'),
      tween: Tween<double>(begin: 0.0, end: targetVal),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (_, value, __) => Stack(
        children: [
          Container(height: 3, color: AppColors.surface3),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF16A34A),
                    Color(0xFF22C55E),
                    Color(0xFF4ADE80),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.45),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _shortPath(String path) {
    if (path.isEmpty) return '\u2014';
    final segs = path
        .split(RegExp(r'[/\\]'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (segs.length <= 2) return path;
    return '\u2026\\${segs.last}';
  }
}

// Status badge
class _StatusBadge extends StatelessWidget {
  final DownloadStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color bg, Color fg) = switch (status) {
      DownloadStatus.downloading => (
        Icons.downloading_rounded,
        'Downloading',
        AppColors.accent.withOpacity(0.10),
        AppColors.accent
      ),
      DownloadStatus.done => (
        Icons.check_circle_rounded,
        'Done',
        AppColors.accent.withOpacity(0.10),
        const Color(0xFF86EFAC)
      ),
      DownloadStatus.queued => (
        Icons.schedule_rounded,
        'Queued',
        AppColors.yellow.withOpacity(0.10),
        AppColors.yellow
      ),
      DownloadStatus.error => (
        Icons.error_rounded,
        'Error',
        AppColors.red.withOpacity(0.10),
        AppColors.red
      ),
      DownloadStatus.paused => (
        Icons.pause_circle_rounded,
        'Paused',
        AppColors.yellow.withOpacity(0.10),
        AppColors.yellow
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: AppTextStyles.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: fg)),
        ],
      ),
    );
  }
}

// Small action button
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Icon(icon, size: 13, color: color.withOpacity(0.80)),
      ),
    );
  }
}
