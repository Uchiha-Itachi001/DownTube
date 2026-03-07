import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../widgets/section_card.dart';
import '../widgets/stat_tile.dart';
import '../widgets/sparkline_chart.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const _historyItems = <_HistoryEntry>[
    _HistoryEntry('Full Stack App with Next.js 14', '@Fireship · 1080p · MP4', '245 MB', '2 hours ago', true),
    _HistoryEntry('Advanced TypeScript Patterns', '@ThePrimeagen · 4K · MKV', '1.2 GB', '4 hours ago', true),
    _HistoryEntry('Lofi Hip Hop Study Beats', '@ChilledCow · Audio · MP3', '48 MB', 'Today, 2:30 PM', true),
    _HistoryEntry('System Design Interview Guide', '@TechLead · 720p · MP4', '890 MB', 'Yesterday', true),
    _HistoryEntry('Docker in 100 Seconds', '@Fireship · 720p · MP4', '32 MB', 'Yesterday', true),
    _HistoryEntry('Failed: Private Video', '@Unknown · N/A', '0 MB', 'Yesterday', false),
    _HistoryEntry('How Git Works Under the Hood', '@Fireship · 1080p · MP4', '189 MB', '2 days ago', true),
    _HistoryEntry('React 19 Complete Guide', '@Academind · 1080p · MP4', '1.8 GB', '3 days ago', true),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 750;
      if (narrow) {
        return SingleChildScrollView(
          child: Column(
            children: [
              _buildHeaderCard(),
              const SizedBox(height: AppColors.gap),
              _buildHistoryList(shrinkWrap: true),
              const SizedBox(height: AppColors.gap),
              _buildAllTimeStats(),
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
                _buildHeaderCard(),
                const SizedBox(height: AppColors.gap),
                Expanded(child: _buildHistoryList()),
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
                  _buildAllTimeStats(),
                  const SizedBox(height: AppColors.gap),
                  _buildWeeklyChart(),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildHeaderCard() {
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
              '${_historyItems.length} total',
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

  Widget _buildHistoryList({bool shrinkWrap = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: ListView.separated(
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.all(6),
        itemCount: _historyItems.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          color: AppColors.border,
          indent: 12,
          endIndent: 12,
        ),
        itemBuilder: (context, i) {
          final item = _historyItems[i];
          return _HistoryTile(entry: item, index: i + 1);
        },
      ),
    );
  }

  Widget _buildAllTimeStats() {
    return SectionCard(
      title: 'ALL TIME SUMMARY',
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(
                  child: StatTile(value: '847', label: 'Total Downloads', unit: '')),
              SizedBox(width: 8),
              Expanded(
                  child: StatTile(value: '124.6', label: 'Data Downloaded', unit: 'GB')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Expanded(
                  child: StatTile(value: '98.2', label: 'Success Rate', unit: '%')),
              SizedBox(width: 8),
              Expanded(
                  child: StatTile(value: '12.8', label: 'Avg Speed', unit: 'MB/s')),
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
          SparklineChart(
            values: const [4, 7, 3, 8, 5, 12, 6],
            height: 70,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((d) => Text(
                      d,
                      style: AppTextStyles.outfit(
                          fontSize: 10, color: AppColors.muted2),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final _HistoryEntry entry;
  final int index;

  const _HistoryTile({required this.entry, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Number
          SizedBox(
            width: 28,
            child: Text(
              index.toString().padLeft(2, '0'),
              style: AppTextStyles.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted2,
              ),
            ),
          ),
          // Status icon
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: entry.success
                  ? AppColors.greenDim
                  : const Color(0xFFEF4444).withOpacity(0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Icon(
                entry.success ? Icons.check_rounded : Icons.close_rounded,
                size: 14,
                color: entry.success
                    ? AppColors.green
                    : const Color(0xFFEF4444),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title & subtitle & time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: AppTextStyles.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: entry.success ? AppColors.text : AppColors.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  entry.subtitle,
                  style:
                      AppTextStyles.outfit(fontSize: 11.5, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  entry.time,
                  style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Size
          Text(
            entry.size,
            style: AppTextStyles.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(width: 12),
          // Actions
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
                child: Icon(Icons.download_rounded,
                    size: 14, color: AppColors.muted),
              ),
            ),
          ),
          const SizedBox(width: 6),
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
                child: Icon(Icons.delete_outline_rounded,
                    size: 14, color: AppColors.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEntry {
  final String title;
  final String subtitle;
  final String size;
  final String time;
  final bool success;
  const _HistoryEntry(this.title, this.subtitle, this.size, this.time, this.success);
}
