import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../widgets/download_item_tile.dart';
import '../widgets/section_card.dart';
import '../widgets/sparkline_chart.dart';
import '../widgets/stat_tile.dart';
import '../widgets/url_input_bar.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 750;
      if (narrow) {
        return SingleChildScrollView(
          child: Column(
            children: [
              _buildActiveSection(),
              const SizedBox(height: AppColors.gap),
              _buildCompletedSection(),
              const SizedBox(height: AppColors.gap),
              _buildSessionStats(),
              const SizedBox(height: AppColors.gap),
              _buildSpeedPanel(),
              const SizedBox(height: AppColors.gap),
              _buildQuickAdd(),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: AppColors.gap),
              child: Column(
                children: [
                  _buildActiveSection(),
                  const SizedBox(height: AppColors.gap),
                  _buildCompletedSection(),
                ],
              ),
            ),
          ),
          // Side panel
          SizedBox(
            width: 260,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSessionStats(),
                  const SizedBox(height: AppColors.gap),
                  _buildSpeedPanel(),
                  const SizedBox(height: AppColors.gap),
                  _buildQuickAdd(),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildActiveSection() {
    return SectionCard(
      title: 'ACTIVE DOWNLOADS',
      count: '3',
      actions: [
        SectionAction(label: 'Pause All', icon: Icons.pause_rounded, onTap: () {}),
        SectionAction(label: 'Clear Done', icon: Icons.clear_all_rounded, onTap: () {}),
      ],
      child: Column(
        children: [
          DownloadItemTile(
            title: 'Building a Full Stack App with Next.js 14',
            meta: '@Fireship · 1080p · MP4',
            progress: 0.67,
            status: DownloadStatus.downloading,
            speed: '12.4 MB/s',
            eta: '2:34',
          ),
          const SizedBox(height: 6),
          DownloadItemTile(
            title: 'Advanced TypeScript Patterns for React',
            meta: '@ThePrimeagen · 4K · MKV',
            progress: 0.34,
            status: DownloadStatus.downloading,
            speed: '8.7 MB/s',
            eta: '5:12',
          ),
          const SizedBox(height: 6),
          DownloadItemTile(
            title: 'System Design Interview Complete Guide',
            meta: '@TechLead · 720p · MP4',
            progress: 0.0,
            status: DownloadStatus.queued,
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedSection() {
    return SectionCard(
      title: 'COMPLETED',
      count: '12',
      child: Column(
        children: [
          DownloadItemTile(
            title: 'How Git Works Under the Hood',
            meta: '@Fireship · 1080p · MP4 · 245 MB',
            progress: 1.0,
            status: DownloadStatus.done,
          ),
          const SizedBox(height: 6),
          DownloadItemTile(
            title: 'Docker in 100 Seconds',
            meta: '@Fireship · 720p · MP4 · 32 MB',
            progress: 1.0,
            status: DownloadStatus.done,
          ),
          const SizedBox(height: 6),
          DownloadItemTile(
            title: 'Why Rust is Taking Over',
            meta: '@NoBoilerplate · 1080p · MP4 · 189 MB',
            progress: 1.0,
            status: DownloadStatus.done,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionStats() {
    return SectionCard(
      title: 'SESSION STATS',
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(child: StatTile(value: '3', label: 'Active', unit: '')),
              SizedBox(width: 8),
              Expanded(child: StatTile(value: '12', label: 'Done Today', unit: '')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Expanded(child: StatTile(value: '2.4', label: 'Downloaded', unit: 'GB')),
              SizedBox(width: 8),
              Expanded(child: StatTile(value: '14.2', label: 'Avg Speed', unit: 'MB/s')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedPanel() {
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
              Text(
                '12.4',
                style: AppTextStyles.syne(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  'MB/s',
                  style: AppTextStyles.outfit(
                    fontSize: 14,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SparklineChart(
            values: const [3, 5, 7, 4, 8, 12, 9, 11, 14, 10, 8, 12, 15, 11, 13],
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
          UrlInputBar(compact: true, onAnalyze: () {}),
        ],
      ),
    );
  }
}
