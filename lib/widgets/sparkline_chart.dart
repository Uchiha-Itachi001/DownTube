import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Animated equalizer-style bar chart with exactly [barCount] bars.
/// Bars animate smoothly like a music spectrum analyser whenever [values] changes.
class SparklineChart extends StatefulWidget {
  /// Raw KB/s samples. Will be normalised internally.
  final List<double> values;
  final double height;
  final int barCount;

  const SparklineChart({
    super.key,
    required this.values,
    this.height = 52,
    this.barCount = 8,
  });

  @override
  State<SparklineChart> createState() => _SparklineChartState();
}

class _SparklineChartState extends State<SparklineChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<double> _from;
  late List<double> _to;

  @override
  void initState() {
    super.initState();
    _to   = _buildBars(widget.values);
    _from = List.of(_to);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(SparklineChart old) {
    super.didUpdateWidget(old);
    if (old.values != widget.values) {
      final t = _ctrl.value;
      _from = List.generate(
        widget.barCount,
        (i) => _lerp(
          i < _from.length ? _from[i] : 0.08,
          i < _to.length   ? _to[i]   : 0.08,
          t,
        ),
      );
      _to = _buildBars(widget.values);
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Map raw speed samples -> exactly [barCount] normalised heights [0.08..1.0]
  /// Uses a music-waveform pattern: middle bars taller than edges.
  List<double> _buildBars(List<double> raw) {
    final n = widget.barCount;
    if (raw.isEmpty || raw.every((v) => v == 0)) {
      // Idle: low bumps in music-waveform shape
      return List.generate(n, (i) {
        final center = (n - 1) / 2.0;
        final dist   = (i - center).abs() / center;
        return 0.08 + (1 - dist) * 0.12; // 0.08 .. 0.20
      });
    }

    final maxV = raw.reduce((a, b) => a > b ? a : b);
    // Resample raw samples to exactly n bars by averaging buckets
    final norm = List.generate(n, (i) {
      final start = (i * raw.length / n).floor();
      final end   = ((i + 1) * raw.length / n).ceil().clamp(start + 1, raw.length);
      final bucket = raw.sublist(start, end);
      final avg = bucket.reduce((a, b) => a + b) / bucket.length;
      return (avg / maxV).clamp(0.08, 1.0);
    });

    // Apply a mild bell-curve envelope so centre bars are emphasised
    final center = (n - 1) / 2.0;
    return List.generate(n, (i) {
      final dist    = (i - center).abs() / center; // 0 at centre, 1 at edges
      final envMult = 0.70 + 0.30 * (1 - dist);   // 0.70 .. 1.00
      return (norm[i] * envMult).clamp(0.08, 1.0);
    });
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    final t = _ctrl.value;
    return SizedBox(
      height: widget.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.barCount, (i) {
          final from = i < _from.length ? _from[i] : 0.08;
          final to   = i < _to.length   ? _to[i]   : 0.08;
          final v    = _lerp(from, to, t);
          final barH = math.max(3.0, widget.height * v);
          final bright = v >= 0.65;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Container(
                height: barH,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  gradient: bright
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.accent, Color(0x3322C55E)],
                        )
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.accent.withOpacity((0.30 + v * 0.55).clamp(0.20, 0.85)),
                            AppColors.accent.withOpacity(0.08),
                          ],
                        ),
                  boxShadow: bright
                      ? [BoxShadow(color: AppColors.accentGlow, blurRadius: 8)]
                      : null,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
