import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import 'app_notification.dart';

class AppHeader extends StatefulWidget {
  const AppHeader({super.key});

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  bool _notifRunning = false;

  /// Shows each notification type, one at a time, 1.2 s apart.
  Future<void> _runNotifDemo() async {
    if (_notifRunning) return;
    _notifRunning = true;

    final items = [
      (NotificationType.success, 'Download completed — video saved to library!'),
      (NotificationType.info,    'New version of yt-dlp available (v2026.04.01)'),
      (NotificationType.error,   'Failed to fetch URL — check your internet connection.'),
      (NotificationType.loading, 'Fetching video metadata, please wait…'),
    ];

    for (final item in items) {
      if (!mounted) break;
      showAppNotification(
        context,
        type: item.$1,
        message: item.$2,
        duration: const Duration(seconds: 3),
      );
      await Future.delayed(const Duration(milliseconds: 1200));
    }

    _notifRunning = false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.green.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Row(
        children: [
          _buildEnginePill(),
          const Spacer(),
          _buildIconButton(Icons.refresh_rounded, null),
          const SizedBox(width: 8),
          _buildIconButton(Icons.notifications_outlined, _runNotifDemo),
          const SizedBox(width: 8),
          _buildUserPill(),
        ],
      ),
    );
  }

  Widget _buildEnginePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.greenDim,
        border: Border.all(color: AppColors.green.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Engine Ready',
                style: AppTextStyles.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.green,
                ),
              ),
              Text(
                'yt-dlp v2026.03.03',
                style: AppTextStyles.outfit(
                  fontSize: 10,
                  color: AppColors.green.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback? onTap) {
    return _HoverContainer(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 16, color: AppColors.muted),
      ),
    );
  }

  Widget _buildUserPill() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text(
                'D',
                style: AppTextStyles.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DownTube',
                style: AppTextStyles.outfit(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                'PREMIUM',
                style: AppTextStyles.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.85 + (_animation.value - 0.6) * 0.375,
          child: Opacity(
            opacity: _animation.value,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AppColors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.green,
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HoverContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _HoverContainer({required this.child, this.onTap});

  @override
  State<_HoverContainer> createState() => _HoverContainerState();
}

class _HoverContainerState extends State<_HoverContainer> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _hovered ? 1.0 : 0.7,
          child: widget.child,
        ),
      ),
    );
  }
}
