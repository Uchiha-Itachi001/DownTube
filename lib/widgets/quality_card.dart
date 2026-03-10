import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

class QualityCard extends StatefulWidget {
  final String resolution;
  final String name;
  final String size;
  final bool isSelected;
  final String? badge;
  final VoidCallback? onTap;

  const QualityCard({
    super.key,
    required this.resolution,
    required this.name,
    required this.size,
    this.isSelected = false,
    this.badge,
    this.onTap,
  });

  @override
  State<QualityCard> createState() => _QualityCardState();
}

class _QualityCardState extends State<QualityCard> {
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
          constraints: const BoxConstraints(minWidth: 80),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.accent.withOpacity(0.08)
                : AppColors.surface2,
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.accent
                  : (_hovered
                      ? AppColors.accent.withOpacity(0.3)
                      : AppColors.border),
            ),
            borderRadius: BorderRadius.circular(11),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.1),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  Text(
                    widget.resolution,
                    style: AppTextStyles.syne(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.name,
                    style: AppTextStyles.outfit(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.size,
                    style: AppTextStyles.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              if (widget.badge != null)
                Positioned(
                  top: -11,
                  right: -15,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: const BoxDecoration(
                      color: AppColors.yellow,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(10),
                        bottomLeft: Radius.circular(6),
                      ),
                    ),
                    child: Text(
                      widget.badge!,
                      style: AppTextStyles.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
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
