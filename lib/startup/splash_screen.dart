import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../providers/app_state.dart';
import '../shell/app_shell.dart';
import 'startup_controller.dart';
import 'location_setup_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _spinCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _glowCtrl;
  late StartupController _startup;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

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
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _startup.removeListener(_onStartupChange);
    _startup.dispose();
    super.dispose();
  }

  double get _progressValue {
    switch (_startup.stage) {
      case StartupStage.checking:
        return 0.35;
      case StartupStage.ytDlpMissing:
        return 0.40;
      case StartupStage.locationNeeded:
        return 0.60;
      case StartupStage.userSetupNeeded:
        return 0.82;
      case StartupStage.ready:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background grid
          const CustomPaint(
            size: Size.infinite,
            painter: _BgGridPainter(),
          ),

          // Center content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulse rings + logo
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 3 expanding pulse rings
                      ...[0.0, 0.34, 0.67].map((offset) =>
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, __) {
                            final t = (_pulseCtrl.value + offset) % 1.0;
                            return CustomPaint(
                              size: const Size(220, 220),
                              painter: _PulseRingPainter(t),
                            );
                          },
                        ),
                      ),
                      // Logo
                      _buildLogo(),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  'DownTube',
                  style: AppTextStyles.syne(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Video Download Engine',
                  style: AppTextStyles.outfit(
                    fontSize: 12,
                    color: AppColors.muted,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 32),

                _buildProgressBar(),

                const SizedBox(height: 16),

                _buildStatusRow(),
              ],
            ),
          ),

          // yt-dlp missing overlay
          if (_startup.stage == StartupStage.ytDlpMissing)
            _YtDlpMissingPanel(
              onPathSelected: (path) => _startup.retryAfterYtDlpSet(path),
            ),

          // Location needed overlay
          if (_startup.stage == StartupStage.locationNeeded)
            LocationSetupDialog(
              onLocationSet: (path) => _startup.markLocationSet(path),
            ),

          // User setup overlay
          if (_startup.stage == StartupStage.userSetupNeeded)
            _UserSetupPanel(
              onDone: () => _startup.markUserSetupDone(),
            ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Spinning arc
          AnimatedBuilder(
            animation: _spinCtrl,
            builder: (_, __) => CustomPaint(
              size: const Size(100, 100),
              painter: _ArcPainter(_spinCtrl.value),
            ),
          ),
          // Breathing glow
          AnimatedBuilder(
            animation: _glowCtrl,
            builder: (_, __) => Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(
                      0.08 + _glowCtrl.value * 0.22,
                    ),
                    blurRadius: 24 + _glowCtrl.value * 20,
                    spreadRadius: 2 + _glowCtrl.value * 6,
                  ),
                ],
              ),
            ),
          ),
          // Icon image
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bg,
              border: Border.all(
                color: AppColors.accent.withOpacity(0.55),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'assetes/images/icon.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return SizedBox(
      width: 220,
      height: 2,
      child: Stack(
        children: [
          Container(
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            width: 220 * _progressValue,
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow() {
    final isDone = _startup.stage == StartupStage.ready;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Row(
        key: ValueKey(_startup.statusMessage),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDone)
            Icon(Icons.check_circle_rounded,
                size: 14, color: AppColors.accent)
          else
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.accent,
              ),
            ),
          const SizedBox(width: 8),
          Text(
            _startup.statusMessage,
            style: AppTextStyles.outfit(
              fontSize: 12,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

// Background grid painter
class _BgGridPainter extends CustomPainter {
  const _BgGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 40.0;
    final linePaint = Paint()
      ..color = AppColors.accent.withOpacity(0.035)
      ..strokeWidth = 0.5;
    final dotPaint = Paint()
      ..color = AppColors.accent.withOpacity(0.10);

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    for (double x = 0; x <= size.width; x += spacing) {
      for (double y = 0; y <= size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_BgGridPainter old) => false;
}

// Pulse ring painter
class _PulseRingPainter extends CustomPainter {
  final double t;
  _PulseRingPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const minR = 56.0;
    const maxR = 92.0;
    final radius = minR + (maxR - minR) * t;
    final opacity = (1.0 - t) * 0.35;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.accent.withOpacity(opacity),
    );
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) => old.t != t;
}

// Arc painter
class _ArcPainter extends CustomPainter {
  final double value;
  _ArcPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.accent.withOpacity(0.12),
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + value * 2 * math.pi,
      math.pi * 0.55,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.value != value;
}

// yt-dlp missing panel
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
                        ? AppColors.accentDim
                        : AppColors.surface2,
                    border: Border.all(
                      color: _selectedPath != null
                          ? AppColors.accent.withOpacity(0.50)
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
                            ? AppColors.accent
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
                          SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent),
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
                          ? AppColors.accent
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

// User setup panel – first-time profile setup
class _UserSetupPanel extends StatefulWidget {
  final VoidCallback onDone;
  const _UserSetupPanel({required this.onDone});

  @override
  State<_UserSetupPanel> createState() => _UserSetupPanelState();
}

class _UserSetupPanelState extends State<_UserSetupPanel> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  String? _picPath;
  bool _valid = false;

  void _checkValid() {
    setState(() {
      _valid = _firstCtrl.text.trim().isNotEmpty;
    });
  }

  Future<void> _pickPicture() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _picPath = result.files.single.path!);
    }
  }

  Future<void> _finish() async {
    await AppState.instance.setUserProfile(
      firstName: _firstCtrl.text.trim(),
      lastName: _lastCtrl.text.trim(),
    );
    if (_picPath != null) {
      await AppState.instance.setUserProfilePicture(_picPath!);
    }
    widget.onDone();
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.75),
      child: Center(
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            border: Border.all(color: AppColors.accent.withOpacity(0.30)),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.06),
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
                      color: AppColors.accentDim,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                          color: AppColors.accent.withOpacity(0.30)),
                    ),
                    child: Icon(Icons.person_rounded,
                        color: AppColors.accent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome to DownTube',
                          style: AppTextStyles.syne(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text("Let's set up your profile",
                          style: AppTextStyles.outfit(
                              fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Profile picture
              Center(
                child: GestureDetector(
                  onTap: _pickPicture,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.accentDim,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.accent.withOpacity(0.40),
                              width: 2,
                            ),
                            image: _picPath != null
                                ? DecorationImage(
                                    image:
                                        FileImage(File(_picPath!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _picPath == null
                              ? Icon(Icons.add_a_photo_rounded,
                                  size: 28,
                                  color: AppColors.accent.withOpacity(0.6))
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.surface1, width: 2),
                            ),
                            child: const Icon(Icons.edit_rounded,
                                size: 12, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Optional',
                  style: AppTextStyles.outfit(
                      fontSize: 10, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 20),
              // First name
              Text('First Name *',
                  style: AppTextStyles.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted)),
              const SizedBox(height: 6),
              TextField(
                controller: _firstCtrl,
                onChanged: (_) => _checkValid(),
                style: AppTextStyles.outfit(
                    fontSize: 13, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: AppColors.surface2,
                  hintText: 'Enter your first name',
                  hintStyle:
                      AppTextStyles.outfit(fontSize: 12, color: AppColors.muted),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: AppColors.accent.withOpacity(0.20)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: AppColors.accent.withOpacity(0.60)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Last name
              Text('Last Name',
                  style: AppTextStyles.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted)),
              const SizedBox(height: 6),
              TextField(
                controller: _lastCtrl,
                style: AppTextStyles.outfit(
                    fontSize: 13, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: AppColors.surface2,
                  hintText: 'Optional',
                  hintStyle:
                      AppTextStyles.outfit(fontSize: 12, color: AppColors.muted),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: AppColors.accent.withOpacity(0.20)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: AppColors.accent.withOpacity(0.60)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Privacy note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentDim,
                  border:
                      Border.all(color: AppColors.accent.withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 16, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'All data stays local — open source, nothing leaves your device.',
                        style: AppTextStyles.outfit(
                          fontSize: 11,
                          color: AppColors.accent.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // Continue button
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: _valid ? _finish : null,
                  child: MouseRegion(
                    cursor: _valid
                        ? SystemMouseCursors.click
                        : SystemMouseCursors.basic,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color:
                            _valid ? AppColors.accent : AppColors.surface3,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Get Started',
                          style: AppTextStyles.syne(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _valid ? Colors.black : AppColors.muted,
                          ),
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
