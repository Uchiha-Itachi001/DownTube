import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

enum NotificationType { error, success, info, loading }

/// Fused / conjoined card notification.
/// Left panel = accent icon badge, right panel = message body.
/// The two panels share a single border and background, giving the
/// "merged / welded container" look from the design reference.
class AppNotificationCard extends StatelessWidget {
  final NotificationType type;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  const AppNotificationCard({
    super.key,
    required this.type,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  // ── Colour palette per type ──────────────────────────────────────
  Color get _accent {
    switch (type) {
      case NotificationType.error:
        return AppColors.red;
      case NotificationType.success:
        return AppColors.green;
      case NotificationType.info:
        return AppColors.blue;
      case NotificationType.loading:
        return AppColors.green;
    }
  }

  IconData get _icon {
    switch (type) {
      case NotificationType.error:
        return Icons.error_rounded;
      case NotificationType.success:
        return Icons.check_circle_rounded;
      case NotificationType.info:
        return Icons.info_rounded;
      case NotificationType.loading:
        return Icons.hourglass_top_rounded;
    }
  }

  String get _typeLabel {
    switch (type) {
      case NotificationType.error:
        return 'ERROR';
      case NotificationType.success:
        return 'SUCCESS';
      case NotificationType.info:
        return 'INFO';
      case NotificationType.loading:
        return 'FETCHING';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Outer border — shared around both panels
      decoration: BoxDecoration(
        color: const Color(0xFF080C09),
        border: Border.all(color: _accent.withOpacity(0.35), width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: _accent.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── LEFT PANEL — icon badge ──────────────────────────
              Container(
                width: 56,
                color: _accent.withOpacity(0.08),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    type == NotificationType.loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(_accent),
                            ),
                          )
                        : Icon(_icon, color: _accent, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      _typeLabel,
                      style: AppTextStyles.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: _accent,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              // ── DIVIDER — the "weld" line between panels ─────────
              Container(width: 1, color: _accent.withOpacity(0.2)),

              // ── RIGHT PANEL — message + optional action ──────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          message,
                          style: AppTextStyles.outfit(
                            fontSize: 13,
                            color: AppColors.text.withOpacity(0.85),
                            height: 1.4,
                          ),
                        ),
                      ),
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(width: 10),
                        _ActionChip(label: actionLabel!, accent: _accent, onTap: onAction!),
                      ],
                      if (onDismiss != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onDismiss,
                          child: Icon(Icons.close_rounded, size: 16, color: AppColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatefulWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.accent, required this.onTap});
  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _hov ? widget.accent.withOpacity(0.18) : widget.accent.withOpacity(0.1),
            border: Border.all(color: widget.accent.withOpacity(0.35)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.label,
            style: AppTextStyles.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: widget.accent,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helper: show as a floating overlay (replaces SnackBar) ──────────────────

void showAppNotification(
  BuildContext context, {
  required NotificationType type,
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => _FloatingNotification(
      type: type,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      onDismiss: () => entry.remove(),
      duration: duration,
    ),
  );

  overlay.insert(entry);
}

class _FloatingNotification extends StatefulWidget {
  final NotificationType type;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;
  final Duration duration;

  const _FloatingNotification({
    required this.type,
    required this.message,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_FloatingNotification> createState() => _FloatingNotificationState();
}

class _FloatingNotificationState extends State<_FloatingNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();

    Future.delayed(widget.duration, _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _ctrl.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _slide,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Material(
                  color: Colors.transparent,
                  child: AppNotificationCard(
                    type: widget.type,
                    message: widget.message,
                    actionLabel: widget.actionLabel,
                    onAction: widget.onAction != null
                        ? () {
                            widget.onAction!();
                            _dismiss();
                          }
                        : null,
                    onDismiss: _dismiss,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Inline status bar variant (used inside the dashboard URL area) ───────────

class AppStatusBar extends StatelessWidget {
  final NotificationType type;
  final String message;

  const AppStatusBar({super.key, required this.type, required this.message});

  @override
  Widget build(BuildContext context) {
    return AppNotificationCard(
      type: type,
      message: message,
    );
  }
}
