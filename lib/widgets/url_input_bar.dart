import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import 'app_notification.dart';

class UrlInputBar extends StatelessWidget {
  final String placeholder;
  final VoidCallback? onAnalyze;
  final VoidCallback? onPaste;
  final bool compact;
  /// Optional inline status shown below the bar (error / success / fetching)
  final String? statusMessage;
  final NotificationType statusType;

  const UrlInputBar({
    super.key,
    this.placeholder = 'Paste video URL from YouTube, Vimeo, Twitch...',
    this.onAnalyze,
    this.onPaste,
    this.compact = false,
    this.statusMessage,
    this.statusType = NotificationType.info,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(16, compact ? 4 : 6, compact ? 4 : 6, compact ? 4 : 6),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            border: Border.all(color: AppColors.green.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.link, size: 16, color: AppColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  style: AppTextStyles.outfit(fontSize: compact ? 12 : 13.5),
                  decoration: InputDecoration(
                    hintText: placeholder,
                    hintStyle: AppTextStyles.outfit(
                        fontSize: compact ? 12 : 13.5, color: AppColors.muted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (!compact) ...[
                _PasteButton(onTap: onPaste),
                const SizedBox(width: 6),
              ],
              _AnalyzeButton(
                onTap: onAnalyze,
                compact: compact,
              ),
            ],
          ),
        ),
        // ── Inline fused status card ──────────────────────────────
        if (statusMessage != null && statusMessage!.isNotEmpty) ...[
          const SizedBox(height: 10),
          AppNotificationCard(
            type: statusType,
            message: statusMessage!,
          ),
        ],
      ],
    );
  }
}

class _PasteButton extends StatefulWidget {
  final VoidCallback? onTap;
  const _PasteButton({this.onTap});

  @override
  State<_PasteButton> createState() => _PasteButtonState();
}

class _PasteButtonState extends State<_PasteButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface3,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            'Paste',
            style: AppTextStyles.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _hovered ? AppColors.text : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalyzeButton extends StatefulWidget {
  final VoidCallback? onTap;
  final bool compact;
  const _AnalyzeButton({this.onTap, this.compact = false});

  @override
  State<_AnalyzeButton> createState() => _AnalyzeButtonState();
}

class _AnalyzeButtonState extends State<_AnalyzeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 12 : 20,
            vertical: widget.compact ? 7 : 9,
          ),
          decoration: BoxDecoration(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.greenGlow,
                blurRadius: _hovered ? 28 : 20,
                offset: Offset(0, _hovered ? 6 : 4),
              ),
            ],
          ),
          transform: _hovered
              ? (Matrix4.identity()..translate(0.0, -1.0))
              : Matrix4.identity(),
          child: widget.compact
              ? const Icon(Icons.add, size: 16, color: Colors.black)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: Colors.black,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ANALYZE',
                      style: AppTextStyles.syne(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
