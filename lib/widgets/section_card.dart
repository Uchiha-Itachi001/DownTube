import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final String? count;
  final List<Widget>? actions;
  final Widget child;
  final bool expand;

  const SectionCard({
    super.key,
    required this.title,
    this.count,
    this.actions,
    required this.child,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceTransparent,
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Text(title, style: AppTextStyles.sectionTitle),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentDim,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    count!,
                    style: AppTextStyles.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
          // Actions row (wrapping)
          if (actions != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: actions!,
            ),
          ],
          const SizedBox(height: 16),
          if (expand) Expanded(child: child) else child,
        ],
      ),
    );

    return expand ? Expanded(child: content) : content;
  }
}

class SectionAction extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  const SectionAction({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.onTap,
  });

  @override
  State<SectionAction> createState() => _SectionActionState();
}

class _SectionActionState extends State<SectionAction> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered
                ? (widget.color ?? AppColors.accent).withOpacity(0.10)
                : Colors.transparent,
            border: Border.all(
              color: _hovered
                  ? (widget.color ?? AppColors.accent).withOpacity(0.40)
                  : AppColors.accent.withOpacity(0.25),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 13,
                    color: _hovered
                        ? (widget.color ?? AppColors.text)
                        : (widget.color ?? AppColors.muted)),
                const SizedBox(width: 5),
              ],
              Text(
                widget.label,
                style: AppTextStyles.outfit(
                  fontSize: 11,
                  color: _hovered
                      ? (widget.color ?? AppColors.text)
                      : (widget.color ?? AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
