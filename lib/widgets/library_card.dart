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
  final String? thumbnailUrl;
  final String outputPath;
  final VoidCallback? onDoubleTap;

  const LibraryCard({
    super.key,
    required this.title,
    required this.meta,
    required this.size,
    required this.duration,
    this.isAudio = false,
    this.gradientColor,
    this.thumbnailUrl,
    this.outputPath = '',
    this.onDoubleTap,
  });

  @override
  State<LibraryCard> createState() => _LibraryCardState();
}

class _LibraryCardState extends State<LibraryCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accentColor =
        widget.gradientColor ??
        (widget.isAudio ? const Color(0xFF3B82F6) : AppColors.accent);

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: GestureDetector(
        onDoubleTap: widget.onDoubleTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform:
              _hovered
                  ? (Matrix4.identity()..translate(0.0, -2.0))
                  : Matrix4.identity(),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            border: Border.all(
              color:
                  _hovered
                      ? accentColor.withOpacity(0.4)
                      : AppColors.accent.withOpacity(0.2),
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow:
                _hovered
                    ? [
                      BoxShadow(
                        color: accentColor.withOpacity(0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                    : [],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 108,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppColors.radius - 1),
                  ),
                  child: _buildThumbnail(accentColor),
                ),
              ),
              _buildInfo(accentColor),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildThumbnail(Color accentColor) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.thumbnailUrl != null)
          Image.network(
            widget.thumbnailUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _gradientBg(accentColor),
          )
        else
          _gradientBg(accentColor),
        // Bottom vignette
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.45, 1.0],
                colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
              ),
            ),
          ),
        ),
        // Type badge — top-left
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.72),
              border: Border.all(color: accentColor.withOpacity(0.55)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isAudio
                      ? Icons.music_note_rounded
                      : Icons.movie_rounded,
                  size: 8,
                  color: accentColor,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.isAudio ? 'AUDIO' : 'VIDEO',
                  style: AppTextStyles.outfit(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Duration — bottom-right
        Positioned(
          bottom: 10,
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
      ],
    );
  }

  Widget _gradientBg(Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentColor.withOpacity(0.20), AppColors.surface2],
        ),
      ),
      child: Center(
        child: Icon(
          widget.isAudio ? Icons.music_note_rounded : Icons.movie_rounded,
          size: 32,
          color: accentColor.withOpacity(0.30),
        ),
      ),
    );
  }

  Widget _buildInfo(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          SizedBox(
            height: 32,
            child: Text(
              widget.title,
              style: AppTextStyles.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),
          // Meta + size badge row
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.meta,
                  style: AppTextStyles.outfit(
                    fontSize: 10.5,
                    color: AppColors.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.14),
                  border: Border.all(color: accentColor.withOpacity(0.45)),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  widget.size,
                  style: AppTextStyles.outfit(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // File path row
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 9, color: AppColors.muted2),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  _shortPath(widget.outputPath),
                  style: AppTextStyles.mono(
                    fontSize: 8.5,
                    color: AppColors.muted2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Show only the last 2 path segments with a leading …
  static String _shortPath(String path) {
    if (path.isEmpty) return '—';
    final segments =
        path.split(RegExp(r'[\\/]')).where((s) => s.isNotEmpty).toList();
    if (segments.length <= 2) return path;
    return '…\\${segments.sublist(segments.length - 2).join('\\')}';
  }
}
