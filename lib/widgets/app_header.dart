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
  final VoidCallback? onOpenDrawer;

  const AppHeader({
    super.key,
    this.isRefreshing = false,
    this.refreshSpinCtrl,
    this.onRefresh,
    this.onOpenDrawer,
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
          if (widget.onOpenDrawer != null) ...[
            _buildIconButton(Icons.menu_rounded, widget.onOpenDrawer),
            const SizedBox(width: 12),
          ],
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
    final sub =
        ready
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
    return _HamburgerButton(icon: icon, onTap: onTap);
  }

  Widget _buildRefreshButton() {
    final ctrl = widget.refreshSpinCtrl;
    return _HoverContainer(
      onTap: widget.isRefreshing ? null : widget.onRefresh,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color:
              widget.isRefreshing
                  ? AppColors.green.withOpacity(0.12)
                  : AppColors.surface2,
          border: Border.all(
            color:
                widget.isRefreshing
                    ? AppColors.green.withOpacity(0.4)
                    : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Center(
          child:
              ctrl != null
                  ? AnimatedBuilder(
                    animation: ctrl,
                    builder:
                        (_, __) => Transform.rotate(
                          angle: ctrl.value * 2 * math.pi,
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color:
                                widget.isRefreshing
                                    ? AppColors.green
                                    : AppColors.muted,
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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

class _HamburgerButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _HamburgerButton({required this.icon, this.onTap});

  @override
  State<_HamburgerButton> createState() => _HamburgerButtonState();
}

class _HamburgerButtonState extends State<_HamburgerButton> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _hov
                ? AppColors.green.withOpacity(0.15)
                : AppColors.green.withOpacity(0.08),
            border: Border.all(
              color: _hov
                  ? AppColors.green.withOpacity(0.60)
                  : AppColors.green.withOpacity(0.30),
            ),
            borderRadius: BorderRadius.circular(9),
            boxShadow: _hov
                ? [
                    BoxShadow(
                      color: AppColors.green.withOpacity(0.25),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.icon,
            size: 16,
            color: _hov
                ? AppColors.green
                : AppColors.green.withOpacity(0.75),
          ),
        ),
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
    _animation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
                boxShadow: [BoxShadow(color: widget.color, blurRadius: 8)],
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
// Dropdown uses OverlayEntry + CompositedTransformFollower so it is always
// rendered above ALL widgets on screen regardless of parent clip bounds.
// The Align(topRight) wrapper inside the follower is critical — without it,
// CompositedTransformFollower gives its child tight full-screen constraints,
// causing the panel to expand to the whole screen.

class _DownloadHeaderBtn extends StatefulWidget {
  const _DownloadHeaderBtn();

  @override
  State<_DownloadHeaderBtn> createState() => _DownloadHeaderBtnState();
}

class _DownloadHeaderBtnState extends State<_DownloadHeaderBtn> {
  bool _cursorOnButton = false;
  bool _cursorOnDropdown = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  bool get _hovered => _cursorOnButton || _cursorOnDropdown;

  void _onButtonEnter() {
    _cursorOnButton = true;
    if (_overlayEntry == null) _showOverlay();
    setState(() {});
  }

  void _onButtonExit() {
    _cursorOnButton = false;
    _scheduleHide();
  }

  void _onDropdownEnter() {
    if (!_cursorOnDropdown) {
      _cursorOnDropdown = true;
      setState(() {});
    }
  }

  void _onDropdownExit() {
    _cursorOnDropdown = false;
    _scheduleHide();
  }

  void _scheduleHide() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      if (!_hovered) {
        _removeOverlay();
        setState(() {});
      }
    });
  }

  void _showOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (_) => _DownloadDropdownOverlay(
        link: _layerLink,
        onEnter: _onDropdownEnter,
        onExit: _onDropdownExit,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (_, __) {
        final downloads = AppState.instance.downloads;

        DownloadItem? current;
        for (final d in downloads) {
          if (d.status == DownloadStatus.downloading) {
            current = d;
            break;
          }
        }
        current ??=
            downloads.where((d) => d.status == DownloadStatus.queued).firstOrNull;

        final isActive = current != null;
        final pct =
            isActive ? (current!.progress * 100).clamp(0, 100).toInt() : 0;
        final queuedCount = downloads
            .where((d) =>
                d.status == DownloadStatus.downloading ||
                d.status == DownloadStatus.queued)
            .length;
        final bool currentIsAudio =
            isActive && current!.resolution.endsWith('k');
        final Color mainAccent =
            currentIsAudio ? const Color(0xFF3B82F6) : AppColors.green;

        return CompositedTransformTarget(
          link: _layerLink,
          child: MouseRegion(
            onEnter: (_) => _onButtonEnter(),
            onExit: (_) => _onButtonExit(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: 36,
              width: isActive ? 230 : 38,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                border: Border.all(
                  color: isActive
                      ? mainAccent.withOpacity(0.40)
                      : AppColors.border,
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  // Icon + badge
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
                            color: isActive ? mainAccent : AppColors.muted,
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
                                color: mainAccent,
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
                  // Progress section
                  Expanded(
                    child: isActive
                        ? Row(
                            children: [
                              Container(
                                  width: 1,
                                  height: 20,
                                  color: AppColors.border),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
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
                                              color: mainAccent,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      TweenAnimationBuilder<double>(
                                        tween: Tween(
                                            begin: 0,
                                            end: current!.progress),
                                        duration: const Duration(
                                            milliseconds: 400),
                                        curve: Curves.easeOut,
                                        builder: (_, v, __) => ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(2),
                                          child: LinearProgressIndicator(
                                            value: v,
                                            backgroundColor: AppColors
                                                .surface2
                                                .withOpacity(0.6),
                                            valueColor:
                                                AlwaysStoppedAnimation(
                                                    mainAccent),
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
            ),
          ),
        );
      },
    );
  }
}

// ── Overlay wrapper ───────────────────────────────────────────────────────────
// Align(topRight) lets the child measure its own intrinsic size. Without it,
// CompositedTransformFollower passes tight full-screen constraints down and the
// panel renders as a full-screen-sized box.

class _DownloadDropdownOverlay extends StatelessWidget {
  final LayerLink link;
  final VoidCallback onEnter;
  final VoidCallback onExit;

  const _DownloadDropdownOverlay({
    required this.link,
    required this.onEnter,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return CompositedTransformFollower(
      link: link,
      targetAnchor: Alignment.bottomRight,
      followerAnchor: Alignment.topRight,
      offset: const Offset(0, 6),
      showWhenUnlinked: false,
      child: Align(
        alignment: Alignment.topRight,
        child: MouseRegion(
          onEnter: (_) => onEnter(),
          onExit: (_) => onExit(),
          child: const _DownloadDropdownContent(),
        ),
      ),
    );
  }
}

// ── Demo dropdown panel ───────────────────────────────────────────────────────

class _DownloadDropdownContent extends StatelessWidget {
  const _DownloadDropdownContent();

  static const _demos = [
    (title: 'Blinding Lights – The Weeknd', progress: 0.72, audio: false),
    (title: 'Big Dawgs – Hanumankind [4K]', progress: 0.45, audio: false),
    (title: 'Puthu Mazha – Audio', progress: 0.88, audio: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 224,
        constraints: const BoxConstraints(maxHeight: 152),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          border: Border.all(color: AppColors.green.withOpacity(0.22)),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.42),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _demos.map((item) {
                final accent =
                    item.audio ? const Color(0xFF3B82F6) : AppColors.green;
                final pct = (item.progress * 100).toInt();
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            item.audio
                                ? Icons.audiotrack_rounded
                                : Icons.download_rounded,
                            size: 11,
                            color: accent,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$pct%',
                            style: AppTextStyles.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: item.progress,
                          backgroundColor:
                              AppColors.surface2.withOpacity(0.5),
                          valueColor: AlwaysStoppedAnimation(accent),
                          minHeight: 2,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}





