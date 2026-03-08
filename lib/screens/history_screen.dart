import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/download_item.dart';
import '../providers/app_state.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_tile.dart';
import '../widgets/sparkline_chart.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final history = AppState.instance.downloads
            .where((d) =>
                d.status == DownloadStatus.done ||
                d.status == DownloadStatus.error)
            .toList();
        final done = history.where((d) => d.status == DownloadStatus.done).length;
        final failed = history.where((d) => d.status == DownloadStatus.error).length;

        return LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 750;
          if (narrow) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeaderCard(history.length),
                  const SizedBox(height: AppColors.gap),
                  _buildHistoryList(history, shrinkWrap: true),
                  const SizedBox(height: AppColors.gap),
                  _buildAllTimeStats(done, failed),
                  const SizedBox(height: AppColors.gap),
                  _buildWeeklyChart(),
                ],
              ),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main area
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildHeaderCard(history.length),
                    const SizedBox(height: AppColors.gap),
                    Expanded(child: _buildHistoryList(history)),
                  ],
                ),
              ),
              const SizedBox(width: AppColors.gap),
              // Side panel
              SizedBox(
                width: 260,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildAllTimeStats(done, failed),
                      const SizedBox(height: AppColors.gap),
                      _buildWeeklyChart(),
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

  Widget _buildHeaderCard(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Row(
        children: [
          Text(
            'Download History',
            style: AppTextStyles.syne(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.greenDim,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$total total',
              style: AppTextStyles.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.green,
              ),
            ),
          ),
          const Spacer(),
          _headerAction('Export'),
          const SizedBox(width: 8),
          _headerAction('Clear All'),
        ],
      ),
    );
  }

  Widget _headerAction(String label) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: AppTextStyles.outfit(fontSize: 12, color: AppColors.muted),
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<DownloadItem> history, {bool shrinkWrap = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: history.isEmpty
          ? _buildEmptyHistory()
          : ListView.separated(
              shrinkWrap: shrinkWrap,
              physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
              padding: const EdgeInsets.all(6),
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                color: AppColors.border,
                indent: 12,
                endIndent: 12,
              ),
              itemBuilder: (context, i) =>
                  _HistoryTile(item: history[i], index: i + 1),
            ),
    );
  }

  Widget _buildEmptyHistory() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Icon(Icons.history_rounded, size: 26, color: AppColors.muted2),
              ),
            ),
            const SizedBox(height: 14),
            Text('No history yet',
                style: AppTextStyles.outfit(
                    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.muted)),
            const SizedBox(height: 5),
            Text('Completed downloads will appear here',
                style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted2),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildAllTimeStats(int done, int failed) {
    final total = done + failed;
    final rate = total == 0 ? 0.0 : (done / total * 100);
    return SectionCard(
      title: 'SESSION SUMMARY',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: StatTile(value: '$total', label: 'Total Downloads', unit: '')),
              const SizedBox(width: 8),
              Expanded(child: StatTile(value: '$done', label: 'Successful', unit: '')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: StatTile(value: '$failed', label: 'Failed', unit: '')),
              const SizedBox(width: 8),
              Expanded(
                  child: StatTile(
                      value: rate.toStringAsFixed(0), label: 'Success Rate', unit: '%')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
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
            'THIS WEEK',
            style: AppTextStyles.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          const SparklineChart(
            values: [4, 7, 3, 8, 5, 12, 6],
            height: 70,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((d) => Text(d,
                    style: AppTextStyles.outfit(fontSize: 10, color: AppColors.muted2)))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ History tile â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _HistoryTile extends StatelessWidget {
  final DownloadItem item;
  final int index;

  const _HistoryTile({required this.item, required this.index});

  static String _relTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final success = item.status == DownloadStatus.done;
    final subtitle = '${item.resolution} Â· ${item.format}';
    final time = _relTime(item.createdAt);
    final isAudio = item.resolution.endsWith('k');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Index number
          SizedBox(
            width: 28,
            child: Text(
              index.toString().padLeft(2, '0'),
              style: AppTextStyles.outfit(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted2),
            ),
          ),
          // Status icon
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: success
                  ? AppColors.greenDim
                  : const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                success
                    ? (isAudio ? Icons.music_note_rounded : Icons.movie_rounded)
                    : Icons.close_rounded,
                size: 14,
                color: success ? AppColors.green : const Color(0xFFEF4444),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTextStyles.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: success ? AppColors.text : AppColors.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.outfit(fontSize: 11.5, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!success && item.errorMessage != null)
                  Text(
                    item.errorMessage!,
                    style: AppTextStyles.outfit(
                        fontSize: 10, color: const Color(0xFFEF4444)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 1),
                Text(
                  time,
                  style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Delete action
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
