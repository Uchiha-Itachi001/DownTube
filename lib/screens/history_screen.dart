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
                (d.status == DownloadStatus.done ||
                 d.status == DownloadStatus.error) &&
                d.showInHistory)
            .toList();
        final done = history.where((d) => d.status == DownloadStatus.done).length;
        final failed = history.where((d) => d.status == DownloadStatus.error).length;

        return LayoutBuilder(builder: (context, constraints) {
          final narrow = constraints.maxWidth < 750;
          if (narrow) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeaderCard(context, history),
                  const SizedBox(height: AppColors.gap),
                  _buildHistoryList(context, history, shrinkWrap: true),
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
                    _buildHeaderCard(context, history),
                    const SizedBox(height: AppColors.gap),
                    Expanded(child: _buildHistoryList(context, history)),
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

  Widget _buildHeaderCard(BuildContext context, List<DownloadItem> history) {
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
              '${history.length} total',
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
          _ClearAllButton(hasHistory: history.isNotEmpty),
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

  Widget _buildHistoryList(BuildContext context, List<DownloadItem> history, {bool shrinkWrap = false}) {
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

// â”€â”€ Clear All button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ClearAllButton extends StatefulWidget {
  final bool hasHistory;
  const _ClearAllButton({required this.hasHistory});

  @override
  State<_ClearAllButton> createState() => _ClearAllButtonState();
}

class _ClearAllButtonState extends State<_ClearAllButton> {
  bool _hovered = false;

  Future<void> _onClearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, spreadRadius: 2)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.red.withOpacity(0.30)),
                    ),
                    child: const Icon(Icons.delete_sweep_rounded, size: 18, color: AppColors.red),
                  ),
                  const SizedBox(width: 12),
                  Text('Clear All History',
                      style: AppTextStyles.outfit(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Remove all completed and failed downloads from history?\n\nFiles on disk are NOT deleted.',
                style: AppTextStyles.outfit(fontSize: 13, color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancel',
                        style: AppTextStyles.outfit(fontSize: 13, color: AppColors.muted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('Clear All',
                        style: AppTextStyles.outfit(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await AppState.instance.clearHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.hasHistory ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.hasHistory ? _onClearAll : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.hasHistory && _hovered
                ? AppColors.red.withOpacity(0.12)
                : AppColors.surface2,
            border: Border.all(
              color: widget.hasHistory && _hovered
                  ? AppColors.red.withOpacity(0.4)
                  : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_sweep_rounded,
                size: 14,
                color: widget.hasHistory && _hovered ? AppColors.red : AppColors.muted,
              ),
              const SizedBox(width: 5),
              Text(
                'Clear All',
                style: AppTextStyles.outfit(
                  fontSize: 12,
                  color: widget.hasHistory && _hovered ? AppColors.red : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€ History tile â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _HistoryTile extends StatefulWidget {
  final DownloadItem item;
  final int index;

  const _HistoryTile({required this.item, required this.index});

  @override
  State<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends State<_HistoryTile> {
  bool _hovered = false;

  static String _relTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Remove from History',
                  style: AppTextStyles.outfit(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                'Remove "${widget.item.title}" from history?\nThe file on disk is not affected.',
                style: AppTextStyles.outfit(
                    fontSize: 13, color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancel',
                        style: AppTextStyles.outfit(
                            fontSize: 13, color: AppColors.muted)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('Remove',
                        style: AppTextStyles.outfit(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true && mounted) {
      await AppState.instance.removeDownload(widget.item.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final success = item.status == DownloadStatus.done;
    final subtitle = '${item.resolution} Â· ${item.format}';
    final time = _relTime(item.createdAt);
    final isAudio = item.resolution.endsWith('k');
    final accent = isAudio ? const Color(0xFF3B82F6) : AppColors.green;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surface2.withOpacity(0.4) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // â”€â”€ Index â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            SizedBox(
              width: 28,
              child: Text(
                widget.index.toString().padLeft(2, '0'),
                style: AppTextStyles.outfit(
                    fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted2),
              ),
            ),
            // â”€â”€ Thumbnail â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 72,
                height: 44,
                child: item.thumbnailUrl != null
                    ? Image.network(
                        item.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackThumb(accent, isAudio),
                      )
                    : _fallbackThumb(accent, isAudio),
              ),
            ),
            const SizedBox(width: 12),
            // â”€â”€ Title + meta â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                  Row(
                    children: [
                      Text(
                        subtitle,
                        style: AppTextStyles.outfit(fontSize: 11.5, color: AppColors.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!success && item.errorMessage != null) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.errorMessage!,
                            style: AppTextStyles.outfit(
                                fontSize: 10, color: const Color(0xFFEF4444)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
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
            // â”€â”€ Status pill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: success
                    ? AppColors.greenDim
                    : const Color(0xFFEF4444).withOpacity(0.12),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: success
                      ? AppColors.green.withOpacity(0.3)
                      : const Color(0xFFEF4444).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    success
                        ? (isAudio ? Icons.music_note_rounded : Icons.check_rounded)
                        : Icons.close_rounded,
                    size: 10,
                    color: success ? AppColors.green : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    success ? 'Done' : 'Failed',
                    style: AppTextStyles.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: success ? AppColors.green : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // â”€â”€ Delete action â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            AnimatedOpacity(
              opacity: _hovered ? 1.0 : 0.35,
              duration: const Duration(milliseconds: 150),
              child: _DeleteIconButton(onTap: _confirmDelete),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackThumb(Color accent, bool isAudio) {
    return Container(
      color: accent.withOpacity(0.1),
      child: Center(
        child: Icon(
          isAudio ? Icons.music_note_rounded : Icons.movie_rounded,
          size: 18,
          color: accent.withOpacity(0.6),
        ),
      ),
    );
  }
}

class _DeleteIconButton extends StatefulWidget {
  final VoidCallback onTap;
  const _DeleteIconButton({required this.onTap});

  @override
  State<_DeleteIconButton> createState() => _DeleteIconButtonState();
}

class _DeleteIconButtonState extends State<_DeleteIconButton> {
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
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFFEF4444).withOpacity(0.15)
                : AppColors.surface2,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFFEF4444).withOpacity(0.4)
                  : AppColors.border,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.delete_outline_rounded,
              size: 14,
              color: _hovered ? const Color(0xFFEF4444) : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

