import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/download_item.dart';

class DownloadItemTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final double progress;
  final DownloadStatus status;
  final String? speed;
  final String? meta;
  final String? eta;

  const DownloadItemTile({
    super.key,
    required this.title,
    this.icon = Icons.movie_rounded,
    required this.progress,
    required this.status,
    this.speed,
    this.meta,
    this.eta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(
          color: status == DownloadStatus.downloading
              ? AppColors.green.withOpacity(0.15)
              : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Row(
            children: [
              // Thumbnail with icon
              Container(
                width: 52,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: [
                      _accentColor.withOpacity(0.15),
                      _accentColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: _accentColor.withOpacity(0.12),
                  ),
                ),
                child: Center(
                  child: Icon(icon, size: 20, color: _accentColor.withOpacity(0.8)),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.outfit(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Progress bar - redesigned
                    _buildProgressBar(),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          meta ?? '',
                          style: AppTextStyles.outfit(
                              fontSize: 11, color: AppColors.muted),
                        ),
                        if (status == DownloadStatus.downloading)
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: AppTextStyles.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.green,
                            ),
                          )
                        else
                          Text(
                            eta ?? '',
                            style: AppTextStyles.outfit(
                                fontSize: 11, color: AppColors.muted),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right side
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: status),
                  if (speed != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.speed_rounded, size: 12, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text(
                          speed!,
                          style: AppTextStyles.outfit(
                              fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
          // Bottom accent line for downloading state
          if (status == DownloadStatus.downloading)
            Positioned(
              left: -14,
              right: -14,
              bottom: -12,
              child: SizedBox(
                height: 2,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.green,
                          AppColors.green.withOpacity(0.4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            // Background
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            // Progress
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  gradient: LinearGradient(
                    colors: _progressGradient,
                  ),
                  boxShadow: status == DownloadStatus.downloading
                      ? [
                          BoxShadow(
                            color: _accentColor.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _accentColor {
    switch (status) {
      case DownloadStatus.error:
        return AppColors.red;
      case DownloadStatus.paused:
      case DownloadStatus.queued:
        return AppColors.yellow;
      default:
        return AppColors.green;
    }
  }

  List<Color> get _progressGradient {
    switch (status) {
      case DownloadStatus.error:
        return [AppColors.red, AppColors.red.withOpacity(0.7)];
      case DownloadStatus.paused:
      case DownloadStatus.queued:
        return [AppColors.yellow, AppColors.yellow.withOpacity(0.7)];
      case DownloadStatus.done:
        return [AppColors.green, const Color(0xFF86EFAC)];
      default:
        return [const Color(0xFF16A34A), AppColors.green, const Color(0xFF4ADE80)];
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final DownloadStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (IconData statusIcon, String label, Color bgColor, Color textColor) = switch (status) {
      DownloadStatus.downloading => (
          Icons.downloading_rounded,
          'Downloading',
          AppColors.green.withOpacity(0.1),
          AppColors.green
        ),
      DownloadStatus.done => (
          Icons.check_circle_rounded,
          'Done',
          AppColors.green.withOpacity(0.1),
          const Color(0xFF86EFAC)
        ),
      DownloadStatus.queued => (
          Icons.schedule_rounded,
          'Queued',
          AppColors.yellow.withOpacity(0.1),
          AppColors.yellow
        ),
      DownloadStatus.error => (
          Icons.error_rounded,
          'Error',
          AppColors.red.withOpacity(0.1),
          AppColors.red
        ),
      DownloadStatus.paused => (
          Icons.pause_circle_rounded,
          'Paused',
          AppColors.yellow.withOpacity(0.1),
          AppColors.yellow
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
