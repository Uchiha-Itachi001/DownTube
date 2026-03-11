import 'dart:async';
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
  Timer? _idleTimer;
  final _rand = math.Random();

  bool get _isIdle =>
      widget.values.isEmpty || widget.values.every((v) => v == 0);

  @override
  void initState() {
    super.initState();
    _to   = _buildBars(widget.values);
    _from = List.of(_to);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..addListener(() => setState(() {}));
    if (_isIdle) _startIdleCycle();
  }

  void _startIdleCycle() {
    _idleTimer?.cancel();
    _idleTimer = Timer.periodic(const Duration(milliseconds: 560), (_) {
      if (!mounted) return;
      if (!_isIdle) return; // stop if active download arrived
      setState(() {
        final t = _ctrl.value;
        _from = List.generate(
          widget.barCount,
          (i) => _lerp(
            i < _from.length ? _from[i] : 0.08,
            i < _to.length   ? _to[i]   : 0.08,
            t,
          ),
        );
        _to = _randomIdleBars();
      });
      _ctrl.forward(from: 0);
    });
  }

  List<double> _randomIdleBars() {
    final n = widget.barCount;
    // Gentle random breathe: low bars with slight waveform centre bias
    return List.generate(n, (i) {
      final centre = (n - 1) / 2.0;
      final dist  = (i - centre).abs() / centre;
      final base  = 0.08 + (1 - dist) * 0.14; // 0.08 .. 0.22
      return (base + (_rand.nextDouble() - 0.5) * 0.10).clamp(0.05, 0.35);
    });
  }

  @override
  void didUpdateWidget(SparklineChart old) {
    super.didUpdateWidget(old);
    final nowIdle = _isIdle;

    if (nowIdle) {
      // Start idle breathing cycle if not already running
      if (_idleTimer == null || !_idleTimer!.isActive) _startIdleCycle();
      return;
    }

    // Active download — stop idle cycle, animate to real data
    _idleTimer?.cancel();
    _idleTimer = null;

    final t = _ctrl.value;
    setState(() {
      _from = List.generate(
        widget.barCount,
        (i) => _lerp(
          i < _from.length ? _from[i] : 0.10,
          i < _to.length   ? _to[i]   : 0.10,
          t,
        ),
      );
      _to = _buildBars(widget.values);
    });
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  /// Map raw speed samples → [barCount] normalised heights [0.08..1.0].
  /// Uses range-based normalization to amplify even small speed fluctuations.
  List<double> _buildBars(List<double> raw) {
    final n = widget.barCount;
    if (raw.isEmpty || raw.every((v) => v == 0)) return _randomIdleBars();

    final maxV = raw.reduce((a, b) => a > b ? a : b);
    final minV = raw.reduce((a, b) => a < b ? a : b);

    // Floor the effective range at 18% of max so tiny fluctuations still look alive
    final rawRange      = maxV - minV;
    final effectiveRange = math.max(rawRange, maxV * 0.18);
    final effectiveMin  = math.max(0.0, maxV - effectiveRange);

    // Resample raw samples into exactly n bars by bucket-averaging
    final norm = List.generate(n, (i) {
      final start  = (i * raw.length / n).floor();
      final end    = ((i + 1) * raw.length / n).ceil().clamp(start + 1, raw.length);
      final bucket = raw.sublist(start, end);
      final avg    = bucket.reduce((a, b) => a + b) / bucket.length;

      final absNorm   = (avg / maxV).clamp(0.0, 1.0);
      final rangeNorm = ((avg - effectiveMin) / effectiveRange).clamp(0.0, 1.0);
      final blended   = absNorm * 0.35 + rangeNorm * 0.65;

      // Per-bar jitter so neighbouring bars diverge slightly
      final jitter = (_rand.nextDouble() - 0.5) * 0.09;
      return (0.10 + blended * 0.85 + jitter).clamp(0.08, 1.0);
    });

    return norm;
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
