// REDESIGNED — radial gradient thumbnails, waveform for audio,
// play-button hover overlay, glow shadow, thin scrollbar via theme.
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

class LibraryCard extends StatefulWidget {
  final String title;
  final String meta;
  final String size;
  final String duration;
  final bool isAudio;
  final Color? gradientColor;

  const LibraryCard({
    super.key,
    required this.title,
    required this.meta,
    required this.size,
    required this.duration,
    this.isAudio = false,
    this.gradientColor,
  });

  @override
  State<LibraryCard> createState() => _LibraryCardState();
}

class _LibraryCardState extends State<LibraryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.gradientColor ??
        (widget.isAudio ? const Color(0xFF3B82F6) : AppColors.green);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: _hovered
            ? (Matrix4.identity()..translate(0.0, -4.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          border: Border.all(
            color: _hovered
                ? accentColor.withOpacity(0.4)
                : AppColors.green.withOpacity(0.2),
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                ]
              : [],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 128,
              child: _buildThumbnail(accentColor),
            ),
            Expanded(
              child: _buildInfo(accentColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(Color accentColor) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Radial gradient background
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                accentColor.withOpacity(0.28),
                widget.isAudio
                    ? const Color(0xFF080C18)
                    : const Color(0xFF07110A),
              ],
              center: Alignment.center,
              radius: 1.1,
            ),
          ),
        ),

        // Bottom vignette
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.45, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.5),
                ],
              ),
            ),
          ),
        ),

        // Audio waveform / video accent dots
        if (widget.isAudio)
          _buildWaveform(accentColor)
        else
          _buildVideoDots(accentColor),

        // Center icon (fades out on hover)
        Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _hovered ? 0.0 : 1.0,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor.withOpacity(0.3)),
              ),
              child: Center(
                child: Icon(
                  widget.isAudio
                      ? Icons.music_note_rounded
                      : Icons.movie_rounded,
                  size: 24,
                  color: accentColor.withOpacity(0.85),
                ),
              ),
            ),
          ),
        ),

        // Play button overlay (shows on hover)
        Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _hovered ? 1.0 : 0.0,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.5),
                    blurRadius: 18,
                  )
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 24,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),

        // Duration badge
        Positioned(
          bottom: 7,
          right: 7,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Text(
              widget.duration,
              style: AppTextStyles.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),

        // Type badge
        Positioned(
          top: 7,
          left: 7,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.18),
              border: Border.all(color: accentColor.withOpacity(0.35)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              widget.isAudio ? 'AUDIO' : 'VIDEO',
              style: AppTextStyles.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: accentColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Simulated equalizer bars for audio cards
  Widget _buildWaveform(Color accentColor) {
    const heights = [0.25, 0.55, 0.85, 0.45, 0.9, 0.35, 0.7,
        0.5, 0.95, 0.3, 0.6, 0.8, 0.4, 0.75, 0.2];
    return Positioned(
      left: 14,
      right: 14,
      bottom: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: heights
            .map((h) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Container(
                    width: 3,
                    height: 26 * h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          accentColor.withOpacity(0.55),
                          accentColor.withOpacity(0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  // Faint dot grid accent for video cards
  Widget _buildVideoDots(Color accentColor) {
    return Positioned(
      right: 14,
      bottom: 26,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          2,
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (col) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.title,
            style: AppTextStyles.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.meta,
                style: AppTextStyles.outfit(
                    fontSize: 11, color: AppColors.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.inventory_2_rounded,
                      size: 11, color: accentColor),
                  const SizedBox(width: 4),
                  Text(
                    widget.size,
                    style: AppTextStyles.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
