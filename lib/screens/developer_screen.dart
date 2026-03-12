import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Developer Credits Screen
// ─────────────────────────────────────────────────────────────────────────────

class DeveloperScreen extends StatefulWidget {
  const DeveloperScreen({super.key});

  @override
  State<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends State<DeveloperScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _bgCtrl;

  bool _showRealCommits = false;
  Timer? _toggleTimer;

  // ── Pixel font for "DOWNTUBE" (5×7, uppercase) ───────────────────────────
  static const Map<String, List<String>> _font = {
    'D': ['XXXX.', 'X...X', 'X...X', 'X...X', 'X...X', 'X...X', 'XXXX.'],
    'O': ['.XXX.', 'X...X', 'X...X', 'X...X', 'X...X', 'X...X', '.XXX.'],
    'W': ['X...X', 'X...X', 'X.X.X', 'X.X.X', 'X.X.X', '.X.X.', '.X.X.'],
    'N': ['X...X', 'XX..X', 'X.X.X', 'X..XX', 'X...X', 'X...X', 'X...X'],
    'T': ['XXXXX', '..X..', '..X..', '..X..', '..X..', '..X..', '..X..'],
    'U': ['X...X', 'X...X', 'X...X', 'X...X', 'X...X', 'X...X', '.XXX.'],
    'B': ['XXXX.', 'X...X', 'X...X', 'XXXX.', 'X...X', 'X...X', 'XXXX.'],
    'E': ['XXXXX', 'X....', 'X....', 'XXXX.', 'X....', 'X....', 'XXXXX'],
  };

  // 52 weeks × 7 days grid encoding "DOWNTUBE" as lit cells
  static final List<int> _downtubeGrid = _buildDownTubeGrid();

  // Realistic dev-activity grid for toggle view
  static final List<int> _commitsGrid = _buildCommitsGrid();

  static List<int> _buildDownTubeGrid() {
    const text = 'DOWNTUBE';
    const weeks = 52;
    const days = 7;
    const charW = 5;
    const charGap = 1;
    final grid = List<int>.filled(weeks * days, 0);
    // total width = 8*5 + 7*1 = 47; leftPad = (52-47)/2 = 2
    const leftPad = 2;
    for (int ci = 0; ci < text.length; ci++) {
      final pattern = _font[text[ci]]!;
      final charStart = leftPad + ci * (charW + charGap);
      for (int col = 0; col < charW; col++) {
        for (int row = 0; row < days; row++) {
          final cellCol = charStart + col;
          if (cellCol >= weeks) continue;
          if (pattern[row][col] == 'X') {
            grid[cellCol * days + row] = 4;
          }
        }
      }
    }
    return grid;
  }

  static List<int> _buildCommitsGrid() {
    final rng = math.Random(42);
    return List.generate(364, (i) {
      final pos = i / 363;
      final base = pos > 0.60
          ? 0.72
          : pos > 0.35
              ? 0.42
              : 0.18;
      final r = rng.nextDouble();
      if (r < base * 0.16) return 4;
      if (r < base * 0.38) return 3;
      if (r < base * 0.58) return 2;
      if (r < base * 0.78) return 1;
      return 0;
    });
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _bgCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 18))
          ..repeat();
    _startAutoToggle();
  }

  void _startAutoToggle() {
    _toggleTimer?.cancel();
    _toggleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _showRealCommits = !_showRealCommits);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _bgCtrl.dispose();
    _toggleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Animated orb background ──────────────────────────────────────
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              painter: _OrbPainter(_bgCtrl.value),
            ),
          ),
        ),
        // ── Scrollable content ───────────────────────────────────────────
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTwoColumnLayout(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTwoColumnLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;

        final contributionGraph = _ContributionGraph(
          contributions: _showRealCommits ? _commitsGrid : _downtubeGrid,
          showRealCommits: _showRealCommits,
          onToggle: () {
            // Manual tap resets the 5 s timer so it doesn't flip right after
            setState(() => _showRealCommits = !_showRealCommits);
            _startAutoToggle();
          },
        );

        final profileColumn = Column(
          children: [
            _ProfileCard(pulseCtrl: _pulseCtrl),
            const SizedBox(height: 12),
            _StatsRow(),
          ],
        );

        final infoColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SkillsCard(),
            const SizedBox(height: 12),
            _AppCard(),
          ],
        );

        if (isNarrow) {
          // Narrow: contribution on top (full width), then profile | info side by side
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              contributionGraph,
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 280, child: profileColumn),
                  const SizedBox(width: 16),
                  Expanded(child: infoColumn),
                ],
              ),
            ],
          );
        }

        // Wide: left = profile+stats, right = contribution+skills+about
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 280, child: profileColumn),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  contributionGraph,
                  const SizedBox(height: 12),
                  _SkillsCard(),
                  const SizedBox(height: 12),
                  _AppCard(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Animated orb background ───────────────────────────────────────────────────

class _OrbPainter extends CustomPainter {
  final double t;

  static final List<_OrbData> _orbs = List.generate(16, (i) {
    final rng = math.Random(i * 13 + 7);
    return _OrbData(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      r: 55.0 + rng.nextDouble() * 110,
      spd: 0.05 + rng.nextDouble() * 0.18,
      phase: rng.nextDouble() * math.pi * 2,
    );
  });

  _OrbPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final orb in _orbs) {
      final angle = t * math.pi * 2;
      final ox =
          ((orb.x + math.sin(angle * orb.spd + orb.phase) * 0.13) % 1.0)
              .abs();
      final oy = ((orb.y +
                  math.cos(angle * orb.spd * 0.65 + orb.phase + 1.2) *
                      0.10) %
              1.0)
          .abs();
      final cx = ox * size.width;
      final cy = oy * size.height;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.accent.withOpacity(0.11),
            AppColors.accent.withOpacity(0.0),
          ],
        ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: orb.r));
      canvas.drawCircle(Offset(cx, cy), orb.r, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t;
}

class _OrbData {
  final double x, y, r, spd, phase;
  const _OrbData(
      {required this.x,
      required this.y,
      required this.r,
      required this.spd,
      required this.phase});
}

// ── Profile card ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatefulWidget {
  final AnimationController pulseCtrl;
  const _ProfileCard({required this.pulseCtrl});

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard>
    with SingleTickerProviderStateMixin {
  bool _hovering = false;
  late AnimationController _ringCtrl;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceTransparent,
        border: Border.all(color: AppColors.accent.withOpacity(0.28)),
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.05),
            blurRadius: 28,
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Avatar ──────────────────────────────────────────────────
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer rotating comet ring
                AnimatedBuilder(
                  animation: _ringCtrl,
                  builder: (_, __) => CustomPaint(
                    size: const Size(150, 150),
                    painter: _ArcRingPainter(
                      t: _ringCtrl.value,
                      radius: 71,
                      reverse: false,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                // Inner counter-rotating comet ring
                AnimatedBuilder(
                  animation: _ringCtrl,
                  builder: (_, __) => CustomPaint(
                    size: const Size(150, 150),
                    painter: _ArcRingPainter(
                      t: _ringCtrl.value,
                      radius: 63,
                      reverse: true,
                      color: AppColors.accent.withOpacity(0.45),
                    ),
                  ),
                ),
                MouseRegion(
                  onEnter: (_) => setState(() => _hovering = true),
                  onExit: (_) => setState(() => _hovering = false),
                  child: AnimatedScale(
                    scale: _hovering ? 1.06 : 1.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    child: AnimatedBuilder(
                      animation: widget.pulseCtrl,
                      builder: (_, child) => Container(
                        width: 114,
                        height: 114,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accent.withOpacity(
                                0.40 + 0.35 * widget.pulseCtrl.value),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withOpacity(
                                  0.12 + 0.22 * widget.pulseCtrl.value),
                              blurRadius: 28,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assetes/images/Dev_Img.png',
                          width: 114,
                          height: 114,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── Name + handle ────────────────────────────────────────────
          Text(
            'Pankoj Roy',
            style: AppTextStyles.syne(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.alternate_email_rounded,
                  size: 12, color: AppColors.muted),
              const SizedBox(width: 3),
              Text(
                'Uchiha-Itachi001',
                style: AppTextStyles.outfit(
                  fontSize: 12,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentDim,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.accent.withOpacity(0.35)),
            ),
            child: Text(
              'Developer',
              style: AppTextStyles.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // ── Bio ───────────────────────────────────────────────────────
          Text(
            'Passionate about coding, teaching, and building creative tools. '
            'Exploring Flutter and full-stack development with a love for '
            'elegant UIs and open-source projects.',
            style: AppTextStyles.outfit(
              fontSize: 11.5,
              color: AppColors.text.withOpacity(0.70),
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          // ── Info chips ────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InfoChip(Icons.location_on_rounded, 'India'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InfoChip(Icons.mail_outline_rounded, 'rpankoj32@gmail.com'),
            ],
          ),
          const SizedBox(height: 16),
          // ── GitHub button ─────────────────────────────────────────────
          _GithubButton(
            label: 'Uchiha-Itachi001',
            url: 'https://github.com/Uchiha-Itachi001',
          ),
          const SizedBox(height: 8),
          // ── Social links ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _SocialButton(
                  icon: FontAwesomeIcons.instagram,
                  label: 'Instagram',
                  url: 'https://www.instagram.com/invites/contact/?utm_source=ig_contact_invite&utm_medium=copy_link&utm_content=n9jjh8e',
                  color: const Color(0xFFE1306C),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SocialButton(
                  icon: FontAwesomeIcons.linkedin,
                  label: 'LinkedIn',
                  url: 'https://www.linkedin.com/in/pankoj-roy-b201202b0',
                  color: const Color(0xFF0A66C2),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SocialButton(
                  icon: FontAwesomeIcons.facebook,
                  label: 'Facebook',
                  url: 'https://www.facebook.com/share/1EbvK7YMWL/',
                  color: const Color(0xFF1877F2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Social icon button ────────────────────────────────────────────────────────

class _SocialButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String url;
  final Color color;
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.url,
    required this.color,
  });
  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUrl(context, widget.url),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withOpacity(0.12)
                : AppColors.surfaceTransparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? widget.color.withOpacity(0.55)
                  : widget.color.withOpacity(0.25),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(widget.icon, size: 15, color: widget.color),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: AppTextStyles.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Arc-ring painter (replaces ripple circles) ────────────────────────────────
// Draws a rotating "comet tail" arc around the developer photo.

class _ArcRingPainter extends CustomPainter {
  final double t;
  final double radius;
  final bool reverse;
  final Color color;

  const _ArcRingPainter({
    required this.t,
    required this.radius,
    this.reverse = false,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final angle = (reverse ? 1.0 - t : t) * 2 * math.pi;
    const sweepAngle = math.pi * 1.4; // 252° comet tail
    final rect = Rect.fromCircle(center: center, radius: radius);
    const steps = 28;
    const stepSweep = sweepAngle / steps;
    for (var i = 0; i < steps; i++) {
      final alpha = (i / steps) * color.a;
      canvas.drawArc(
        rect,
        angle + i * stepSweep,
        stepSweep + 0.02,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.butt
          ..color = color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_ArcRingPainter old) =>
      old.t != t || old.radius != radius || old.reverse != reverse;
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: const Color.fromARGB(255, 150, 150, 166)),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _GithubButton extends StatefulWidget {
  final String label;
  final String url;
  const _GithubButton({required this.label, required this.url});
  @override
  State<_GithubButton> createState() => _GithubButtonState();
}

class _GithubButtonState extends State<_GithubButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openUrl(context, widget.url),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.accentDim
                : AppColors.surfaceTransparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered
                  ? AppColors.accent.withOpacity(0.60)
                  : AppColors.accent.withOpacity(0.28),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                        color: AppColors.accent.withOpacity(0.15),
                        blurRadius: 10)
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.code_rounded, size: 14, color: AppColors.accent),
              const SizedBox(width: 7),
              Text(
                'github.com/${widget.label}',
                style: AppTextStyles.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.open_in_new_rounded,
                  size: 11,
                  color: AppColors.accent.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _StatBox(
                label: 'Repos', value: '12', icon: Icons.folder_copy_rounded)),
        const SizedBox(width: 8),
        Expanded(
            child: _StatBox(
                label: 'Commits', value: '347', icon: Icons.commit_rounded)),
        const SizedBox(width: 8),
        Expanded(
            child: _StatBox(
                label: 'Projects',
                value: '8',
                icon: Icons.rocket_launch_rounded)),
      ],
    );
  }
}

class _StatBox extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatBox(
      {required this.label, required this.value, required this.icon});
  @override
  State<_StatBox> createState() => _StatBoxState();
}

class _StatBoxState extends State<_StatBox> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.accentDim : AppColors.surfaceTransparent,
          border: Border.all(
            color: _hovered
                ? AppColors.accent.withOpacity(0.45)
                : AppColors.accent.withOpacity(0.18),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(widget.icon, size: 16, color: AppColors.accent),
            const SizedBox(height: 5),
            Text(
              widget.value,
              style: AppTextStyles.syne(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.label,
              style: AppTextStyles.outfit(
                  fontSize: 9.5, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Contribution graph ────────────────────────────────────────────────────────

class _ContributionGraph extends StatelessWidget {
  final List<int> contributions;
  final bool showRealCommits;
  final VoidCallback onToggle;
  const _ContributionGraph({
    required this.contributions,
    required this.showRealCommits,
    required this.onToggle,
  });

  Color _cellColor(int level, bool lit) {
    if (!lit && level == 0) return AppColors.accent.withOpacity(0.055);
    switch (level) {
      case 0:
        return AppColors.accent.withOpacity(0.055);
      case 1:
        return AppColors.accent.withOpacity(0.22);
      case 2:
        return AppColors.accent.withOpacity(0.45);
      case 3:
        return AppColors.accent.withOpacity(0.70);
      default:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    const weeks = 52;
    const days = 7;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceTransparent,
        border: Border.all(color: AppColors.accent.withOpacity(0.20)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insights_rounded,
                      size: 14, color: AppColors.accent),
                  const SizedBox(width: 7),
                  Text(
                    'CONTRIBUTION ACTIVITY',
                    style: AppTextStyles.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              // Toggle button
              GestureDetector(
                onTap: onToggle,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: showRealCommits
                          ? AppColors.accentDim
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.accent.withOpacity(
                            showRealCommits ? 0.55 : 0.25),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.35),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          )),
                          child: child,
                        ),
                      ),
                      child: Row(
                        key: ValueKey(showRealCommits),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            showRealCommits
                                ? Icons.commit_rounded
                                : Icons.text_fields_rounded,
                            size: 11,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            showRealCommits ? 'Real commits' : 'DownTube',
                            style: AppTextStyles.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── Grid (animated crossfade between DownTube / commits) ─────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(showRealCommits),
              child: ClipRect(
            child: LayoutBuilder(
            builder: (_, constraints) {
              final cellSize =
                  ((constraints.maxWidth - (weeks - 1) * 3) / weeks)
                      .clamp(4.0, 13.0);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(weeks, (w) {
                  return Padding(
                    padding: EdgeInsets.only(right: w < weeks - 1 ? 3 : 0),
                    child: Column(
                      children: List.generate(days, (d) {
                        final idx = w * days + d;
                        final lvl = idx < contributions.length
                            ? contributions[idx]
                            : 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Tooltip(
                            message: showRealCommits
                                ? (lvl == 0
                                    ? 'No commits'
                                    : '$lvl commit${lvl > 1 ? 's' : ''}')
                                : '',
                            child: Container(
                              width: cellSize,
                              height: cellSize,
                              decoration: BoxDecoration(
                                color: _cellColor(lvl, !showRealCommits),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
                ),  // close Row
              );    // close SingleChildScrollView
            },
          ),
          ),
            ),  // KeyedSubtree
          ),  // AnimatedSwitcher
          const SizedBox(height: 10),
          // ── Footer / legend ──────────────────────────────────────────
          Row(
            children: [
              Flexible(
                child: Text(
                showRealCommits
                    ? '347 contributions in the last year'
                    : 'DownTube — built with Flutter & yt-dlp',
                style: AppTextStyles.outfit(
                  fontSize: 10,
                  color: AppColors.muted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              ),
              const SizedBox(width: 8),
              if (showRealCommits) ...[
                Text('Less',
                    style: AppTextStyles.outfit(
                        fontSize: 9.5, color: AppColors.muted)),
                const SizedBox(width: 4),
                for (int i = 0; i <= 4; i++)
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(left: 3),
                    decoration: BoxDecoration(
                      color: _cellColor(i, false),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                const SizedBox(width: 4),
                Text('More',
                    style: AppTextStyles.outfit(
                        fontSize: 9.5, color: AppColors.muted)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Skills card ───────────────────────────────────────────────────────────────

class _SkillsCard extends StatelessWidget {
  const _SkillsCard();

  // (label, icon, tier)  tier: 0=primary, 1=secondary, 2=tertiary
  static const _skills = [
    ('Flutter', Icons.widgets_rounded, 0),
    ('Dart', Icons.code_rounded, 0),
    ('Python', Icons.terminal_rounded, 1),
    ('Electron', Icons.desktop_mac_rounded, 1),
    ('JavaScript', Icons.javascript_rounded, 1),
    ('React', Icons.web_rounded, 1),
    ('Node.js', Icons.dns_rounded, 2),
    ('MongoDB', Icons.storage_rounded, 2),
    ('Java', Icons.coffee_rounded, 2),
    ('HTML/CSS', Icons.html_rounded, 1),
    ('Express', Icons.api_rounded, 2),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceTransparent,
        border: Border.all(color: AppColors.accent.withOpacity(0.20)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terminal_rounded,
                  size: 14, color: AppColors.accent),
              const SizedBox(width: 7),
              Text(
                'TECH STACK',
                style: AppTextStyles.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _skills.map((s) => _SkillChip(s.$1, s.$2, s.$3)).toList(),
          ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final int tier;
  const _SkillChip(this.label, this.icon, this.tier);
  @override
  State<_SkillChip> createState() => _SkillChipState();
}

class _SkillChipState extends State<_SkillChip> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final basOp = widget.tier == 0
        ? 0.60
        : widget.tier == 1
            ? 0.42
            : 0.28;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
            const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.accent.withOpacity(basOp + 0.18)
              : AppColors.accent.withOpacity(basOp * 0.22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.accent
                .withOpacity(_hovered ? 0.55 : basOp * 0.42),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 12, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: AppTextStyles.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── App card ──────────────────────────────────────────────────────────────────

class _AppCard extends StatelessWidget {
  const _AppCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceTransparent,
        border: Border.all(color: AppColors.accent.withOpacity(0.20)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.download_rounded,
                  size: 14, color: AppColors.accent),
              const SizedBox(width: 7),
              Text(
                'ABOUT DOWNTUBE',
                style: AppTextStyles.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'DownTube is an open-source, cross-platform video downloader built '
            'with Flutter. Powered by yt-dlp, it supports high-quality downloads, '
            'playlists, smart history tracking, and a clean native-feeling desktop UI.',
            style: AppTextStyles.outfit(
              fontSize: 12,
              color: AppColors.text.withOpacity(0.78),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _AppChip('Flutter 3+'),
              _AppChip('yt-dlp'),
              _AppChip('SQLite'),
              _AppChip('Open Source'),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppChip extends StatelessWidget {
  final String label;
  const _AppChip(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentDim,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accent.withOpacity(0.22)),
      ),
      child: Text(
        label,
        style: AppTextStyles.outfit(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

// ── URL launcher ─────────────────────────────────────────────────────────────

Future<void> _openUrl(BuildContext context, String url) async {
  try {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', url]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else {
      await Process.run('xdg-open', [url]);
    }
  } catch (_) {}
}
