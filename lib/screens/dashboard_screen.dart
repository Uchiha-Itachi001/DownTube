import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../widgets/url_input_bar.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback? onAnalyze;

  const DashboardScreen({super.key, this.onAnalyze});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF080C09),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // ── BACKGROUND LAYERS ──
          // Layer 1: Deep radial base glow
          Positioned.fill(
            child: CustomPaint(painter: _BgBasePainter()),
          ),
          // Layer 2: Animated grid
          Positioned.fill(child: const _AnimatedGrid()),
          // Layer 3: Floating orbs
          Positioned.fill(child: const _FloatingOrbs()),
          // Layer 4: Hex rings
          Positioned.fill(child: const _HexRings()),
          // Layer 5: Beam (center vertical light shaft)
          Positioned.fill(child: const _BeamWidget()),
          // Layer 6: Particles
          Positioned.fill(child: const _ParticleField()),
          // Layer 7: Data stream lines
          Positioned.fill(child: const _DataStreams()),
          // Layer 8: Vignette
          Positioned.fill(
            child: CustomPaint(painter: _VignettePainter()),
          ),
          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPoweredPill(),
                  const SizedBox(height: 24),
                  _buildHeroTitle(),
                  const SizedBox(height: 12),
                  _buildDescription(),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 580,
                    child: UrlInputBar(onAnalyze: onAnalyze),
                  ),
                  const SizedBox(height: 16),
                  _buildFeaturePills(),
                ],
              ),
            ),
          ),
          // Platform row at bottom
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: _buildPlatformRow(),
          ),
          // Border overlay — always on top so animation layers never overdraw it
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.green.withOpacity(0.45),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(AppColors.radius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoweredPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.greenDim,
        border: Border.all(color: AppColors.green.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.green, blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'POWERED BY YT-DLP · OPEN SOURCE',
            style: AppTextStyles.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.green,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroTitle() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: AppTextStyles.heroTitle,
        children: [
          const TextSpan(text: 'Download '),
          TextSpan(
            text: 'Anything',
            style: AppTextStyles.heroTitle.copyWith(color: AppColors.green),
          ),
          const TextSpan(text: '\nfrom the Internet'),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return SizedBox(
      width: 460,
      child: Text(
        'Paste any video or audio URL to start.\nSupports YouTube, Twitch, Vimeo, TikTok and 1000+ more sites.',
        textAlign: TextAlign.center,
        style: AppTextStyles.outfit(
          fontSize: 14,
          color: AppColors.muted,
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildFeaturePills() {
    final features = [
      (Icons.movie_rounded, 'Up to 8K', true),
      (Icons.music_note_rounded, 'MP3 / WAV', false),
      (Icons.insert_drive_file_rounded, 'MP4 / MKV', false),
      (Icons.playlist_add_rounded, 'Batch Mode', false),
      (Icons.bolt_rounded, 'Ultra Fast', false),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: features.map((f) {
        return _FeaturePill(icon: f.$1, label: f.$2, isSelected: f.$3);
      }).toList(),
    );
  }

  Widget _buildPlatformRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(color: AppColors.green.withOpacity(0.30)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            'Works with',
            style: AppTextStyles.outfit(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(width: 14),
          // YouTube
          _platformFaIcon(FontAwesomeIcons.youtube, const Color(0xFFFF0000)),
          // Facebook
          _platformFaIcon(FontAwesomeIcons.facebook, const Color(0xFF1877F2)),
          // Instagram
          _platformFaIcon(
            FontAwesomeIcons.instagram,const  Color(0xFFE1306C) 
          ),


          const Spacer(),
          Text(
            '1000+ platforms',
            style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _platformFaIcon(IconData icon, Color? bgColor, {Gradient? gradient}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: 40,
        height: 30,
        decoration: BoxDecoration(
          // color: gradient == null ? (bgColor ?? AppColors.surface3) : null,
          // color: bgColor ?? AppColors.surface3,
          color: bgColor != null ? bgColor.withOpacity(0.1) : AppColors.border,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: bgColor != null ? bgColor.withOpacity(0.5) : AppColors.border,
            width: 1,
          ),
        ),
        child: Center(
          child: FaIcon(icon, size: 15, color: bgColor ?? AppColors.muted),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;

  const _FeaturePill({
    required this.icon,
    required this.label,
    this.isSelected = false,
  });

  @override
  State<_FeaturePill> createState() => _FeaturePillState();
}

class _FeaturePillState extends State<_FeaturePill> {
  late bool _selected;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.isSelected;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => setState(() => _selected = !_selected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: _selected ? AppColors.greenDim : AppColors.surface2,
            border: Border.all(
              color: _selected
                  ? AppColors.green.withOpacity(0.35)
                  : (_hovered
                      ? AppColors.green.withOpacity(0.25)
                      : AppColors.border),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: _selected || _hovered ? AppColors.green : AppColors.muted),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: AppTextStyles.outfit(
                  fontSize: 12,
                  color: _selected || _hovered
                      ? AppColors.green
                      : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BACKGROUND ANIMATION WIDGETS
// ══════════════════════════════════════════════════════════════

// Layer 1 — Static radial base glow
class _BgBasePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Top-center large emerald glow
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF14532D).withOpacity(0.55),
          Colors.transparent,
        ],
        radius: 0.6,
      ).createShader(Rect.fromLTWH(
        size.width * 0.1, -size.height * 0.3,
        size.width * 0.8, size.height * 0.6,
      ));
    canvas.drawRect(Offset.zero & size, paint1);

    // Bottom-left glow
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0F3C1E).withOpacity(0.35),
          Colors.transparent,
        ],
        radius: 0.5,
      ).createShader(Rect.fromLTWH(
        -size.width * 0.1, size.height * 0.5,
        size.width * 0.6, size.height * 0.6,
      ));
    canvas.drawRect(Offset.zero & size, paint2);
  }

  @override
  bool shouldRepaint(_BgBasePainter old) => false;
}

// Layer 2 — Animated scrolling grid
class _AnimatedGrid extends StatefulWidget {
  const _AnimatedGrid();
  @override
  State<_AnimatedGrid> createState() => _AnimatedGridState();
}

class _AnimatedGridState extends State<_AnimatedGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
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
      builder: (_, __) => CustomPaint(
        painter: _GridPainter(_ctrl.value),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double t;
  _GridPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const gridSize = 60.0;
    final offset = t * gridSize;
    final paint = Paint()
      ..color = const Color(0xFF22C55E).withOpacity(0.10)
      ..strokeWidth = 1;

    for (double x = -gridSize + offset; x < size.width + gridSize; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = -gridSize + offset; y < size.height + gridSize; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.t != t;
}

// Layer 3 — Floating orbs
class _FloatingOrbs extends StatefulWidget {
  const _FloatingOrbs();
  @override
  State<_FloatingOrbs> createState() => _FloatingOrbsState();
}

class _FloatingOrbsState extends State<_FloatingOrbs>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
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
        final sin = math.sin(t * math.pi);
        return Stack(
          children: [
            // Orb 1 — top center, pulsing
            Positioned(
              top: -180 + sin * 20,
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: 0.7 + 0.3 * sin,
                  child: Container(
                    width: 500,
                    height: 500,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF22C55E).withOpacity(0.18),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Orb 2 — bottom left floating
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.1 - 40 * sin,
              left: MediaQuery.of(context).size.width * 0.08 + 30 * sin,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF14B874).withOpacity(0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Orb 3 — bottom right floating
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.05 - 30 * sin,
              right: MediaQuery.of(context).size.width * 0.10 - 20 * sin,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF10B981).withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Layer 4 — Spinning hex rings
class _HexRings extends StatefulWidget {
  const _HexRings();
  @override
  State<_HexRings> createState() => _HexRingsState();
}

class _HexRingsState extends State<_HexRings>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
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
      builder: (_, __) => CustomPaint(
        painter: _HexRingPainter(_ctrl.value),
      ),
    );
  }
}

class _HexRingPainter extends CustomPainter {
  final double t;
  _HexRingPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.45;

    // Outer ring — slow clockwise
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(t * 2 * math.pi);
    final paint1 = Paint()
      ..color = const Color(0xFF22C55E).withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset.zero, 350, paint1);
    canvas.restore();

    // Inner ring — faster counter-clockwise
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-t * 2 * math.pi * 1.5);
    final paint2 = Paint()
      ..color = const Color(0xFF22C55E).withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path();
    const r = 250.0;
    const dashLen = 12.0;
    const gapLen = 8.0;
    final circ = 2 * math.pi * r;
    final total = dashLen + gapLen;
    final count = (circ / total).floor();
    for (int i = 0; i < count; i++) {
      final startAngle = i * total / r;
      final sweepAngle = dashLen / r;
      path.addArc(
        Rect.fromCircle(center: Offset.zero, radius: r),
        startAngle,
        sweepAngle,
      );
    }
    canvas.drawPath(path, paint2);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HexRingPainter old) => old.t != t;
}

// Layer 5 — Beam (vertical center glow + wide cone)
class _BeamWidget extends StatefulWidget {
  const _BeamWidget();
  @override
  State<_BeamWidget> createState() => _BeamWidgetState();
}

class _BeamWidgetState extends State<_BeamWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
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
      builder: (_, __) => Opacity(
        opacity: 0.5 + 0.5 * _ctrl.value,
        child: CustomPaint(painter: _BeamPainter()),
      ),
    );
  }
}

class _BeamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // Wide cone from top center
    final conePath = Path()
      ..moveTo(cx - 2, 0)
      ..lineTo(cx + 2, 0)
      ..lineTo(cx + 300, size.height * 0.5)
      ..lineTo(cx - 300, size.height * 0.5)
      ..close();
    final conePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF22C55E).withOpacity(0.07),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5));
    canvas.drawPath(conePath, conePaint);

    // Thin center line
    final linePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF22C55E).withOpacity(0.6),
          const Color(0xFF22C55E).withOpacity(0.15),
          Colors.transparent,
        ],
        stops: const [0, 0.2, 0.6],
      ).createShader(Rect.fromLTWH(cx - 1, 0, 2, size.height))
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), linePaint);
  }

  @override
  bool shouldRepaint(_BeamPainter old) => false;
}

// Layer 6 — Particles rising from bottom
class _ParticleField extends StatefulWidget {
  const _ParticleField();
  @override
  State<_ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<_ParticleField>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_ParticleData> _particles;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _particles = List.generate(35, (_) => _ParticleData(_rng));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick)
      ..repeat();
  }

  void _tick() {
    for (final p in _particles) {
      p.update();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_tick);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ParticlePainter(_particles),
    );
  }
}

class _ParticleData {
  late double x;
  late double y;
  late double speed;
  late double size;
  late double opacity;
  final math.Random rng;

  _ParticleData(this.rng) {
    _reset(fromBottom: false);
  }

  void _reset({bool fromBottom = true}) {
    x = rng.nextDouble();
    y = fromBottom ? 1.05 : rng.nextDouble();
    speed = (0.0008 + rng.nextDouble() * 0.002);
    size = rng.nextDouble() > 0.7 ? 3 : 2;
    opacity = 0.3 + rng.nextDouble() * 0.7;
  }

  void update() {
    y -= speed;
    if (y < -0.05) _reset();
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_ParticleData> particles;
  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final progress = 1.0 - p.y.clamp(0.0, 1.0);
      double opacity = p.opacity;
      if (progress < 0.1) opacity *= progress / 0.1;
      if (progress > 0.9) opacity *= (1.0 - progress) / 0.1;
      final paint = Paint()
        ..color = const Color(0xFF22C55E).withOpacity(opacity.clamp(0, 1));
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size / 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}

// Layer 7 — Data stream lines
class _DataStreams extends StatefulWidget {
  const _DataStreams();
  @override
  State<_DataStreams> createState() => _DataStreamsState();
}

class _DataStreamsState extends State<_DataStreams>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_StreamData> _streams;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _streams = List.generate(18, (_) => _StreamData(_rng));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick)
      ..repeat();
  }

  void _tick() {
    for (final s in _streams) {
      s.update();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_tick);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StreamPainter(_streams));
  }
}

class _StreamData {
  late double x;
  late double y;
  late double speed;
  late double height;
  late double opacity;
  final math.Random rng;

  _StreamData(this.rng) {
    _reset(fromTop: false);
  }

  void _reset({bool fromTop = true}) {
    x = 0.05 + rng.nextDouble() * 0.9;
    y = fromTop ? -0.5 : (-0.5 + rng.nextDouble() * 2.0);
    speed = 0.003 + rng.nextDouble() * 0.005;
    height = 0.10 + rng.nextDouble() * 0.25;
    opacity = 0.45 + rng.nextDouble() * 0.45;
  }

  void update() {
    y += speed;
    if (y > 2.1) _reset();
  }
}

class _StreamPainter extends CustomPainter {
  final List<_StreamData> streams;
  _StreamPainter(this.streams);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in streams) {
      final top = s.y * size.height;
      final bottom = (s.y + s.height) * size.height;
      final cx = s.x * size.width;
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFF22C55E).withOpacity(s.opacity),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(cx - 1, top, 2, bottom - top))
        ..strokeWidth = 1;
      canvas.drawLine(Offset(cx, top), Offset(cx, bottom), paint);
    }
  }

  @override
  bool shouldRepaint(_StreamPainter old) => true;
}

// Layer 8 — Vignette
class _VignettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.7),
        ],
        stops: const [0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_VignettePainter old) => false;
}
