import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Animated shimmer placeholder that adapts to the app's current accent color.
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 6,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
          ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final accent = AppColors.accent;
        final base = Color.lerp(const Color(0xFF0E0E0E), accent, 0.06)!;
        final mid = Color.lerp(const Color(0xFF0E0E0E), accent, 0.14)!;
        final highlight = Color.lerp(const Color(0xFF0E0E0E), accent, 0.25)!;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-2.0 + t * 4.0, 0),
              end: Alignment(-1.0 + t * 4.0, 0),
              colors: [base, mid, highlight, mid, base],
              stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
            ),
          ),
        );
      },
    );
  }
}
