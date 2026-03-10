import 'dart:ui';
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
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  const AppNotificationCard({
    super.key,
    required this.type,
    required this.message,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  // Colour palette per type
  Color get _accent {
    switch (type) {
      case NotificationType.error:
        return AppColors.red;
      case NotificationType.success:
        return AppColors.accent;
      case NotificationType.info:
        return AppColors.blue;
      case NotificationType.loading:
        return AppColors.accent;
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            // glass dark surface tinted with accent
            color: Color.lerp(
              const Color(0xFF080C09).withOpacity(0.82),
              _accent,
              0.04,
            ),
            border: Border.all(
              color: _accent.withOpacity(0.38),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _accent.withOpacity(0.22),
                blurRadius: 32,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 16,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // GLOWING LEFT BAR
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _accent.withOpacity(0.2),
                        _accent,
                        _accent.withOpacity(0.2),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withOpacity(0.7),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                // ICON ZONE
                Container(
                  width: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        _accent.withOpacity(0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Center(
                    child: type == NotificationType.loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(_accent),
                            ),
                          )
                        : Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _accent.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _accent.withOpacity(0.35),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _accent.withOpacity(0.3),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: Icon(_icon, color: _accent, size: 18),
                          ),
                  ),
                ),
                // BODY
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // pill label
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _accent.withOpacity(0.28),
                            ),
                          ),
                          child: Text(
                            _typeLabel,
                            style: AppTextStyles.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _accent,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          message,
                          style: AppTextStyles.outfit(
                            fontSize: 13,
                            color: AppColors.text.withOpacity(0.92),
                            height: 1.45,
                          ),
                        ),
                        if (subtitle != null) ...[  
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: AppTextStyles.outfit(
                              fontSize: 11,
                              color: AppColors.muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // ACTION + CLOSE
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (onDismiss != null)
                        GestureDetector(
                          onTap: onDismiss,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(height: 6),
                        _ActionChip(
                          label: actionLabel!,
                          accent: _accent,
                          onTap: onAction!,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
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

// Helper: show as a floating overlay (replaces SnackBar)
void showAppNotification(
  BuildContext context, {
  required NotificationType type,
  required String message,
  String? subtitle,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
  ValueNotifier<bool>? dismissController,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  bool _removed = false;

  entry = OverlayEntry(
    builder: (_) => _FloatingNotification(
      type: type,
      message: message,
      subtitle: subtitle,
      actionLabel: actionLabel,
      onAction: onAction,
      onDismiss: () {
        if (!_removed) {
          _removed = true;
          entry.remove();
        }
      },
      duration: duration,
      dismissController: dismissController,
    ),
  );

  overlay.insert(entry);
}

class _FloatingNotification extends StatefulWidget {
  final NotificationType type;
  final String message;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;
  final Duration duration;
  final ValueNotifier<bool>? dismissController;

  const _FloatingNotification({
    required this.type,
    required this.message,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
    required this.duration,
    this.dismissController,
  });

  @override
  State<_FloatingNotification> createState() => _FloatingNotificationState();
}

class _FloatingNotificationState extends State<_FloatingNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  late Animation<double> _slideY;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    // Fade in
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    // Slight scale from 0.90 → 1.0
    _scale = Tween<double>(begin: 0.90, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    // Translate from -16px to 0
    _slideY = Tween<double>(begin: -16.0, end: 0.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();
    widget.dismissController?.addListener(_onDismissController);
    Future.delayed(widget.duration, _dismiss);
  }

  void _onDismissController() {
    if (widget.dismissController?.value == true) _dismiss();
  }

  void _dismiss() {
    if (!mounted || _dismissed) return;
    _dismissed = true;
    _ctrl.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    widget.dismissController?.removeListener(_onDismissController);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 24,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => Opacity(
            opacity: _opacity.value,
            child: Transform(
              alignment: Alignment.topCenter,
              transform: Matrix4.identity()
                ..translate(0.0, _slideY.value)
                ..scale(_scale.value),
              child: child,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Material(
                  color: Colors.transparent,
                  child: AppNotificationCard(
                    type: widget.type,
                    message: widget.message,
                    subtitle: widget.subtitle,
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
    );
  }
}

// Inline status bar variant (used inside the dashboard URL area)
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
