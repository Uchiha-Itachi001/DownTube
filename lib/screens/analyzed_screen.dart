import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../widgets/quality_card.dart';

class AnalyzedScreen extends StatefulWidget {
  final VoidCallback? onDownload;

  const AnalyzedScreen({super.key, this.onDownload});

  @override
  State<AnalyzedScreen> createState() => _AnalyzedScreenState();
}

class _AnalyzedScreenState extends State<AnalyzedScreen> {
  int _selectedQuality = 1; // 1080p by default
  int _selectedTab = 0; // 0 = Video, 1 = Audio
  final Set<String> _selectedFormats = {'MP4'};
  final Set<String> _checkOptions = {'Embed Subtitles', 'Save Thumbnail'};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildVideoInfoCard(),
        const SizedBox(height: AppColors.gap),
        _buildFormatCard(),
        const Spacer(),
        _buildActionBar(),
      ],
    );
  }

  Widget _buildVideoInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Top accent line
          Positioned(
            top: -18,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.green.withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              Container(
                width: 160,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A2E1A), Color(0xFF0D1F0D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.green.withOpacity(0.15),
                            Colors.black.withOpacity(0.4),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4), width: 2),
                        ),
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.only(left: 2),
                            child: Icon(Icons.play_arrow_rounded,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text('14:32',
                            style: AppTextStyles.outfit(
                                fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Platform badges
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.12),
                            border: Border.all(
                                color: Colors.red.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 12, color: const Color(0xFFF87171)),
                              const SizedBox(width: 3),
                              Text(
                            'YouTube',
                            style: AppTextStyles.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF87171),
                            ),
                          ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.greenDim,
                            border: Border.all(
                                color: AppColors.green.withOpacity(0.25)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 12, color: AppColors.green),
                              const SizedBox(width: 4),
                              Text(
                            'Video Ready to Download',
                            style: AppTextStyles.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.green,
                            ),
                          ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Building a Full Stack App with Next.js 14 & Supabase — Complete Course',
                      style: AppTextStyles.syne(fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '@Fireship  ·  2.1M subscribers',
                      style: AppTextStyles.outfit(
                          fontSize: 12.5, color: AppColors.green),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 14,
                      children: [
                        _metaItem(Icons.visibility_outlined, '4.2M views'),
                        _metaItem(Icons.calendar_today_outlined, 'Dec 2024'),
                        _metaItem(Icons.thumb_up_outlined, '98% liked'),
                        _metaItem(Icons.high_quality_outlined, '4K available'),
                      ],
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

  Widget _metaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(text,
            style: AppTextStyles.outfit(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }

  Widget _buildFormatCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with tabs
          Row(
            children: [
              Text(
                'CHOOSE FORMAT',
                style: AppTextStyles.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 12),
              _buildTabSwitch(),
            ],
          ),
          const SizedBox(height: 16),
          // Quality cards
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              QualityCard(
                resolution: '4K',
                name: 'Ultra HD',
                size: '~2.1 GB',
                badge: 'HDR',
                isSelected: _selectedQuality == 0,
                onTap: () => setState(() => _selectedQuality = 0),
              ),
              QualityCard(
                resolution: '1080p',
                name: 'Full HD',
                size: '~450 MB',
                isSelected: _selectedQuality == 1,
                onTap: () => setState(() => _selectedQuality = 1),
              ),
              QualityCard(
                resolution: '720p',
                name: 'HD',
                size: '~180 MB',
                isSelected: _selectedQuality == 2,
                onTap: () => setState(() => _selectedQuality = 2),
              ),
              QualityCard(
                resolution: '480p',
                name: 'SD',
                size: '~90 MB',
                isSelected: _selectedQuality == 3,
                onTap: () => setState(() => _selectedQuality = 3),
              ),
              QualityCard(
                resolution: '360p',
                name: 'Low',
                size: '~48 MB',
                isSelected: _selectedQuality == 4,
                onTap: () => setState(() => _selectedQuality = 4),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Format buttons and options
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _formatBtn('MP4'),
              _formatBtn('MKV'),
              _formatBtn('WEBM'),
              Container(
                  width: 1,
                  height: 24,
                  color: AppColors.border,
                  margin: const EdgeInsets.symmetric(horizontal: 4)),
              _checkOption('Embed Subtitles'),
              _checkOption('Save Thumbnail'),
              _checkOption('Add Chapters'),
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
          _tabBtn(Icons.music_note_rounded, 'Audio Only', 1),
        ],
      ),
    );
  }

  Widget _tabBtn(IconData icon, String label, int index) {
    final isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? Colors.black : AppColors.muted),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.black : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formatBtn(String format) {
    final isSelected = _selectedFormats.contains(format);
    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) {
          _selectedFormats.remove(format);
        } else {
          _selectedFormats.add(format);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.greenDim : AppColors.surface2,
          border: Border.all(
            color: isSelected
                ? AppColors.green.withOpacity(0.3)
                : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              format,
              style: AppTextStyles.outfit(
                fontSize: 12,
                color: isSelected ? AppColors.green : AppColors.muted,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_rounded, size: 13, color: AppColors.green),
            ],
          ],
        ),
      ),
    );
  }

  Widget _checkOption(String label) {
    final isChecked = _checkOptions.contains(label);
    return GestureDetector(
      onTap: () => setState(() {
        if (isChecked) {
          _checkOptions.remove(label);
        } else {
          _checkOptions.add(label);
        }
      }),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isChecked ? AppColors.green : AppColors.surface3,
                border: Border.all(
                    color: isChecked ? AppColors.green : AppColors.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: isChecked
                  ? const Center(
                      child: Icon(Icons.check_rounded,
                          size: 11,
                          color: Colors.black))
                  : null,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style:
                  AppTextStyles.outfit(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1080p · MP4 · ~450 MB',
                  style: AppTextStyles.outfit(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Estimated time: ~2 min  ·  ',
                      style: AppTextStyles.outfit(
                          fontSize: 11, color: AppColors.muted),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outlined, size: 12, color: AppColors.green),
                        const SizedBox(width: 3),
                        Text(
                      'No DRM detected',
                      style: AppTextStyles.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.green,
                      ),
                    ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Queue button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onDownload,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: AppColors.green.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+ Add to Queue',
                  style: AppTextStyles.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Download now button
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onDownload,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.greenGlow,
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.download_rounded,
                        size: 18,
                        color: Colors.black),
                    const SizedBox(width: 6),
                    Text(
                      'Download Now',
                      style: AppTextStyles.syne(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
