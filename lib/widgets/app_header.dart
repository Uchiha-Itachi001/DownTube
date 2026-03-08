import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../providers/app_state.dart';
import '../models/download_item.dart';

class AppHeader extends StatefulWidget {
  final bool isRefreshing;
  final AnimationController? refreshSpinCtrl;
  final VoidCallback? onRefresh;

  const AppHeader({
    super.key,
    this.isRefreshing = false,
    this.refreshSpinCtrl,
    this.onRefresh,
  });

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_onEngineChange);
  }

  void _onEngineChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onEngineChange);
    super.dispose();
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
          _buildRefreshButton(),
          const SizedBox(width: 8),
          const _DownloadHeaderBtn(),
          const SizedBox(width: 8),
          _buildUserPill(),
        ],
      ),
    );
  }

  Widget _buildEnginePill() {
    final ready = AppState.instance.ytDlpReady;
    final version = AppState.instance.ytDlpVersion;
    final label = ready ? 'Engine Ready' : 'Engine Offline';
    final sub = ready
        ? (version != null ? 'yt-dlp $version' : 'yt-dlp ready')
        : 'yt-dlp not found';
    final color = ready ? AppColors.green : AppColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: ready ? AppColors.greenDim : AppColors.red.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTextStyles.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                sub,
                style: AppTextStyles.outfit(
                  fontSize: 10,
                  color: color.withOpacity(0.6),
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

  Widget _buildRefreshButton() {
    final ctrl = widget.refreshSpinCtrl;
    return _HoverContainer(
      onTap: widget.isRefreshing ? null : widget.onRefresh,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: widget.isRefreshing
              ? AppColors.green.withOpacity(0.12)
              : AppColors.surface2,
          border: Border.all(
            color: widget.isRefreshing
                ? AppColors.green.withOpacity(0.4)
                : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Center(
          child: ctrl != null
              ? AnimatedBuilder(
                  animation: ctrl,
                  builder: (_, __) => Transform.rotate(
                    angle: ctrl.value * 2 * math.pi,
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: widget.isRefreshing ? AppColors.green : AppColors.muted,
                    ),
                  ),
                )
              : Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: AppColors.muted,
                ),
        ),
      ),
    );
  }

  Widget _buildUserPill() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
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
  final Color color;
  const _PulsingDot({this.color = AppColors.green});
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
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color,
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

// ── Download header button ────────────────────────────────────────────────────

class _DownloadHeaderBtn extends StatelessWidget {
  const _DownloadHeaderBtn();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (_, __) {
        final downloads = AppState.instance.downloads;

        // Pick the actively downloading item first, then first queued
        DownloadItem? current;
        for (final d in downloads) {
          if (d.status == DownloadStatus.downloading) { current = d; break; }
        }
        current ??= downloads.where((d) => d.status == DownloadStatus.queued).firstOrNull;

        final isActive = current != null;
        final pct = isActive ? (current!.progress * 100).clamp(0, 100).toInt() : 0;
        final queuedCount = downloads
            .where((d) =>
                d.status == DownloadStatus.downloading ||
                d.status == DownloadStatus.queued)
            .length;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: 36,
          width: isActive ? 230 : 38,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            border: Border.all(
              color: isActive
                  ? AppColors.green.withOpacity(0.40)
                  : AppColors.border,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              // ── Icon section (always 34 px wide) ─────────────────────────
              SizedBox(
                width: 36,
                height: 36,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Icon(
                        Icons.download_rounded,
                        size: 16,
                        color: isActive ? AppColors.green : AppColors.muted,
                      ),
                    ),
                    if (queuedCount > 0)
                      Positioned(
                        top: 5,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 3, vertical: 1),
                          constraints: const BoxConstraints(
                              minWidth: 14, minHeight: 14),
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: AppColors.surface2, width: 1.5),
                          ),
                          child: Text(
                            '$queuedCount',
                            style: AppTextStyles.outfit(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // ── Expanded section (always in layout so Row never overflows)
              Expanded(
                child: isActive
                    ? Row(
                        children: [
                          Container(width: 1, height: 20, color: AppColors.border),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title + percentage
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          current!.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$pct%',
                                        style: AppTextStyles.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.green,
                                        ),
                                      ),
                                      if (queuedCount > 1) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: AppColors.green.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '+${queuedCount - 1}',
                                            style: AppTextStyles.outfit(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  // Smooth progress bar
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: current!.progress),
                                    duration: const Duration(milliseconds: 400),
                                    curve: Curves.easeOut,
                                    builder: (_, v, __) => ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: v,
                                        backgroundColor:
                                            AppColors.surface2.withOpacity(0.6),
                                        valueColor: const AlwaysStoppedAnimation(
                                            AppColors.green),
                                        minHeight: 3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}
