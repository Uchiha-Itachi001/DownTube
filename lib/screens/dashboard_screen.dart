import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../widgets/url_input_bar.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback? onAnalyze;

  const DashboardScreen({super.key, this.onAnalyze});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Top glow
          Positioned(
            top: -100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 600,
                height: 300,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppColors.green.withOpacity(0.07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Top accent line
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.4,
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
          ),
          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPoweredPill(),
                  const SizedBox(height: 24),
                  _buildHeroTitle(),
                  const SizedBox(height: 12),
                  _buildDescription(),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 580,
                    child: UrlInputBar(onAnalyze: onAnalyze),
                  ),
                  const SizedBox(height: 16),
                  _buildFeaturePills(),
                ],
              ),
            ),
          ),
          // Platform row at bottom
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: _buildPlatformRow(),
          ),
        ],
      ),
    );
  }

  Widget _buildPoweredPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.greenDim,
        border: Border.all(color: AppColors.green.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.green, blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'POWERED BY YT-DLP · OPEN SOURCE',
            style: AppTextStyles.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.green,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroTitle() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: AppTextStyles.heroTitle,
        children: [
          const TextSpan(text: 'Download '),
          TextSpan(
            text: 'Anything',
            style: AppTextStyles.heroTitle.copyWith(color: AppColors.green),
          ),
          const TextSpan(text: '\nfrom the Internet'),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return SizedBox(
      width: 460,
      child: Text(
        'Paste any video or audio URL to start.\nSupports YouTube, Twitch, Vimeo, TikTok and 1000+ more sites.',
        textAlign: TextAlign.center,
        style: AppTextStyles.outfit(
          fontSize: 14,
          color: AppColors.muted,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildFeaturePills() {
    final features = [
      (Icons.movie_rounded, 'Up to 8K', true),
      (Icons.music_note_rounded, 'MP3 / WAV', false),
      (Icons.insert_drive_file_rounded, 'MP4 / MKV', false),
      (Icons.playlist_add_rounded, 'Batch Mode', false),
      (Icons.bolt_rounded, 'Ultra Fast', false),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: features.map((f) {
        return _FeaturePill(icon: f.$1, label: f.$2, isSelected: f.$3);
      }).toList(),
    );
  }

  Widget _buildPlatformRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface2.withOpacity(0.7),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            'Works with',
            style: AppTextStyles.outfit(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(width: 14),
          // YouTube
          _platformFaIcon(FontAwesomeIcons.youtube, const Color(0xFFFF0000)),
          // Facebook
          _platformFaIcon(FontAwesomeIcons.facebook, const Color(0xFF1877F2)),
          // Instagram
          _platformFaIcon(
            FontAwesomeIcons.instagram,const  Color(0xFFE1306C) 
          ),


          const Spacer(),
          Text(
            '1000+ platforms',
            style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _platformFaIcon(IconData icon, Color? bgColor, {Gradient? gradient}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: 40,
        height: 30,
        decoration: BoxDecoration(
          // color: gradient == null ? (bgColor ?? AppColors.surface3) : null,
          // color: bgColor ?? AppColors.surface3,
          color: bgColor != null ? bgColor.withOpacity(0.1) : AppColors.border,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: bgColor != null ? bgColor.withOpacity(0.5) : AppColors.border,
            width: 1,
          ),
        ),
        child: Center(
          child: FaIcon(icon, size: 15, color: bgColor ?? AppColors.muted),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;

  const _FeaturePill({
    required this.icon,
    required this.label,
    this.isSelected = false,
  });

  @override
  State<_FeaturePill> createState() => _FeaturePillState();
}

class _FeaturePillState extends State<_FeaturePill> {
  late bool _selected;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.isSelected;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => setState(() => _selected = !_selected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: _selected ? AppColors.greenDim : AppColors.surface2,
            border: Border.all(
              color: _selected
                  ? AppColors.green.withOpacity(0.35)
                  : (_hovered
                      ? AppColors.green.withOpacity(0.25)
                      : AppColors.border),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: _selected || _hovered ? AppColors.green : AppColors.muted),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: AppTextStyles.outfit(
                  fontSize: 12,
                  color: _selected || _hovered
                      ? AppColors.green
                      : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
