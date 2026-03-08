import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../shell/app_shell.dart';
import 'startup_controller.dart';
import 'location_setup_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ringCtrl;
  late StartupController _startup;

  @override
  void initState() {
    super.initState();
    _ringCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
          ..repeat();

    _startup = StartupController();
    _startup.addListener(_onStartupChange);
    _startup.run();
  }

  void _onStartupChange() {
    if (!mounted) return;
    setState(() {});

    if (_startup.stage == StartupStage.ready) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AppShell(),
            transitionDuration: const Duration(milliseconds: 450),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _startup.removeListener(_onStartupChange);
    _startup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background glow ──────────────────────────────────────────────
          Center(
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.green.withOpacity(0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Center logo + ring ───────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ring + logo
                SizedBox(
                  width: 90,
                  height: 90,
                  child: Stack(
                    children: [
                      // Animated ring
                      AnimatedBuilder(
                        animation: _ringCtrl,
                        builder: (_, __) => CustomPaint(
                          size: const Size(90, 90),
                          painter: _RingPainter(_ringCtrl.value),
                        ),
                      ),
                      // Center icon
                      Center(
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.greenGlow.withOpacity(0.6),
                                  blurRadius: 24),
                            ],
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.black, size: 26),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  'DownTube',
                  style: AppTextStyles.syne(
                      fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),

                // Status message
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _startup.statusMessage,
                    key: ValueKey(_startup.statusMessage),
                    style: AppTextStyles.outfit(
                        fontSize: 13, color: AppColors.muted),
                  ),
                ),

                const SizedBox(height: 20),

                // Status indicator dot
                _StatusDot(stage: _startup.stage),
              ],
            ),
          ),

          // ── yt-dlp missing overlay ───────────────────────────────────────
          if (_startup.stage == StartupStage.ytDlpMissing)
            _YtDlpMissingPanel(
              onPathSelected: (path) => _startup.retryAfterYtDlpSet(path),
            ),

          // ── Location needed overlay ──────────────────────────────────────
          if (_startup.stage == StartupStage.locationNeeded)
            LocationSetupDialog(
              onLocationSet: (path) => _startup.markLocationSet(path),
            ),
        ],
      ),
    );
  }
}

// ── Ring painter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double value;
  _RingPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.green.withOpacity(0.15),
    );

    // Sweeping arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + value * 2 * math.pi,
      math.pi * 0.55,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = AppColors.green,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}

// ── Status dot ────────────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final StartupStage stage;
  const _StatusDot({required this.stage});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    switch (stage) {
      case StartupStage.checking:
        color = AppColors.yellow;
        label = 'Checking';
      case StartupStage.ytDlpMissing:
        color = AppColors.red;
        label = 'Engine Missing';
      case StartupStage.locationNeeded:
        color = AppColors.yellow;
        label = 'Setup Required';
      case StartupStage.ready:
        color = AppColors.green;
        label = 'Ready';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.30)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color, blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: AppTextStyles.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

// ── yt-dlp missing panel ──────────────────────────────────────────────────────

class _YtDlpMissingPanel extends StatefulWidget {
  final void Function(String path) onPathSelected;
  const _YtDlpMissingPanel({required this.onPathSelected});

  @override
  State<_YtDlpMissingPanel> createState() => _YtDlpMissingPanelState();
}

class _YtDlpMissingPanelState extends State<_YtDlpMissingPanel> {
  String? _selectedPath;
  bool _picking = false;

  Future<void> _pickFile() async {
    setState(() => _picking = true);
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Locate yt-dlp.exe',
      type: FileType.custom,
      allowedExtensions: ['exe'],
    );
    setState(() {
      _picking = false;
      if (result?.files.single.path != null) {
        _selectedPath = result!.files.single.path!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.75),
      child: Center(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            border: Border.all(color: AppColors.red.withOpacity(0.30)),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.red.withOpacity(0.06),
                blurRadius: 60,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(11),
                      border:
                          Border.all(color: AppColors.red.withOpacity(0.30)),
                    ),
                    child: const Icon(Icons.error_outline_rounded,
                        color: AppColors.red, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('yt-dlp Not Found',
                          style: AppTextStyles.syne(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('Locate yt-dlp.exe to continue',
                          style: AppTextStyles.outfit(
                              fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'yt-dlp was not found in PATH or the default install folder.\n'
                'Download it from yt-dlp.org then select the executable below.',
                style: AppTextStyles.outfit(
                    fontSize: 12, color: AppColors.muted, height: 1.55),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _picking ? null : _pickFile,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _selectedPath != null
                        ? AppColors.greenDim
                        : AppColors.surface2,
                    border: Border.all(
                      color: _selectedPath != null
                          ? AppColors.green.withOpacity(0.50)
                          : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedPath != null
                            ? Icons.check_circle_rounded
                            : Icons.folder_open_rounded,
                        size: 18,
                        color: _selectedPath != null
                            ? AppColors.green
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedPath ?? 'Browse for yt-dlp.exe…',
                          style: AppTextStyles.mono(
                              fontSize: 11,
                              color: _selectedPath != null
                                  ? AppColors.text
                                  : AppColors.muted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_picking)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.green),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _selectedPath != null
                      ? () => widget.onPathSelected(_selectedPath!)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: _selectedPath != null
                          ? AppColors.green
                          : AppColors.surface3,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Continue',
                        style: AppTextStyles.syne(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _selectedPath != null
                              ? Colors.black
                              : AppColors.muted,
                        ),
                      ),
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
