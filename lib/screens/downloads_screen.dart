import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/download_item.dart';
import '../providers/app_state.dart';
import '../widgets/download_item_tile.dart';
import '../widgets/section_card.dart';
import '../widgets/sparkline_chart.dart';
import '../widgets/stat_tile.dart';
import '../widgets/url_input_bar.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final all = AppState.instance.downloads;
        final active = all
            .where((d) =>
                d.status == DownloadStatus.downloading ||
                d.status == DownloadStatus.queued)
            .toList();
        final completed = all
            .where((d) =>
                d.status == DownloadStatus.done ||
                d.status == DownloadStatus.error)
            .toList();

        return LayoutBuilder(builder: (context, constraints) {
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppColors.gap),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildActiveSection(active, expand: true),
                      const SizedBox(height: AppColors.gap),
                      _buildCompletedSection(completed, expand: true),
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
        });
      },
    );
  }

  Widget _buildActiveSection(List<DownloadItem> active, {bool expand = false}) {
    Widget body;
    if (active.isEmpty) {
      body = _emptyState('No active downloads', Icons.download_outlined,
          subtitle: 'Analyze a video and start a download to see it here');
    } else if (expand) {
      body = ListView(
        shrinkWrap: false,
        padding: EdgeInsets.zero,
        children: active
            .map((item) => DownloadItemTile(
                  title: item.title,
                  icon: item.resolution.endsWith('k')
                      ? Icons.music_note_rounded
                      : Icons.movie_rounded,
                  progress: item.progress,
                  status: item.status,
                  speed: item.speed,
                  eta: item.eta,
                  meta: '${item.resolution} · ${item.format}',
                ))
            .toList(),
      );
    } else {
      body = Column(
        children: active
            .map((item) => DownloadItemTile(
                  title: item.title,
                  icon: item.resolution.endsWith('k')
                      ? Icons.music_note_rounded
                      : Icons.movie_rounded,
                  progress: item.progress,
                  status: item.status,
                  speed: item.speed,
                  eta: item.eta,
                  meta: '${item.resolution} · ${item.format}',
                ))
            .toList(),
      );
    }
    return SectionCard(
      title: 'ACTIVE DOWNLOADS',
      count: '${active.length}',
      expand: expand,
      actions: active.isNotEmpty
          ? [SectionAction(label: 'Clear Done', icon: Icons.clear_all_rounded, onTap: () {})]
          : null,
      child: body,
    );
  }

  Widget _buildCompletedSection(List<DownloadItem> completed, {bool expand = false}) {
    Widget body;
    if (completed.isEmpty) {
      body = _emptyState('No completed downloads', Icons.check_circle_outline_rounded,
          subtitle: 'Finished downloads will appear here');
    } else if (expand) {
      body = ListView(
        shrinkWrap: false,
        padding: EdgeInsets.zero,
        children: completed
            .map((item) => DownloadItemTile(
                  title: item.title,
                  icon: item.resolution.endsWith('k')
                      ? Icons.music_note_rounded
                      : Icons.movie_rounded,
                  progress: item.progress,
                  status: item.status,
                  meta: item.status == DownloadStatus.error
                      ? 'Error: ${item.errorMessage ?? "unknown"}'
                      : '${item.resolution} · ${item.format}',
                ))
            .toList(),
      );
    } else {
      body = Column(
        children: completed
            .map((item) => DownloadItemTile(
                  title: item.title,
                  icon: item.resolution.endsWith('k')
                      ? Icons.music_note_rounded
                      : Icons.movie_rounded,
                  progress: item.progress,
                  status: item.status,
                  meta: item.status == DownloadStatus.error
                      ? 'Error: ${item.errorMessage ?? "unknown"}'
                      : '${item.resolution} · ${item.format}',
                ))
            .toList(),
      );
    }
    return SectionCard(
      title: 'COMPLETED',
      count: '${completed.length}',
      expand: expand,
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
                color: AppColors.surface2,
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Icon(icon, size: 24, color: AppColors.muted2),
            ),
            const SizedBox(height: 14),
            Text(label,
                style: AppTextStyles.outfit(
                    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.muted)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted2)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSessionStats(List<DownloadItem> all) {
    final done = all.where((d) => d.status == DownloadStatus.done).length;
    final active = all.where((d) => d.status == DownloadStatus.downloading).length;
    return SectionCard(
      title: 'SESSION STATS',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: StatTile(value: '$active', label: 'Active', unit: '')),
              const SizedBox(width: 8),
              Expanded(child: StatTile(value: '$done', label: 'Done Today', unit: '')),
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
        color: AppColors.surface1,
        border: Border.all(color: AppColors.border),
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
                decoration: const BoxDecoration(
                  color: AppColors.green,
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
          const SparklineChart(
            values: [3, 5, 7, 4, 8, 12, 9, 11, 14, 10, 8, 12, 15, 11, 13],
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
        color: AppColors.surface1,
        border: Border.all(color: AppColors.border),
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
          UrlInputBar(compact: true, onAnalyze: (_) {}),
        ],
      ),
    );
  }
}
