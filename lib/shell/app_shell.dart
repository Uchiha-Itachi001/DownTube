import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../providers/app_state.dart';
import '../widgets/sidebar.dart';
import '../widgets/app_header.dart';
import '../screens/dashboard_screen.dart';
import '../screens/analyzed_screen.dart';
import '../screens/downloads_screen.dart';
import '../screens/library_screen.dart';
import '../screens/history_screen.dart';
import '../screens/settings_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  String? _pendingUrl;
  int _fetchKey = 0; // incremented on every new search to force widget rebuild
  int _screenRefreshKey = 0; // incremented to force screen refresh
  bool _isRefreshing = false;
  late AnimationController _refreshSpinCtrl;

  void _onNavSelected(int index) => setState(() => _selectedIndex = index);

  void _goToAnalyzed(String url) {
    AppState.instance.resetFetch();
    setState(() {
      _pendingUrl = url;
      _selectedIndex = 5;
      _fetchKey++;
    });
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _refreshSpinCtrl.repeat();
    // Reload AppState data from DB
    await AppState.instance.refreshFromDb();
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      _screenRefreshKey++;
      _isRefreshing = false;
    });
    _refreshSpinCtrl
      ..stop()
      ..reset();
  }

  @override
  void initState() {
    super.initState();
    _refreshSpinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _refreshSpinCtrl.dispose();
    super.dispose();
  }

  Widget _buildNonAnalyzeScreen() {
    switch (_selectedIndex < 5 ? _selectedIndex : 0) {
      case 0:
        return DashboardScreen(onAnalyze: _goToAnalyzed);
      case 1:
        return const LibraryScreen();
      case 2:
        return const DownloadsScreen();
      case 3:
        return const HistoryScreen();
      case 4:
        return const SettingsScreen();
      default:
        return DashboardScreen(onAnalyze: _goToAnalyzed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.9),
            radius: 1.4,
            colors: [
              Color(0xFF0D1F10), // faint dark-green at top
              Color(0xFF080B08), // near-black mid
              Color(0xFF060809), // deep base
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          // Responsive sidebar: collapsed icon-only <800, narrow 800-1099, full >=1100
          final collapsed = w < 800;
          final sidebarWidth = collapsed ? 60.0 : (w < 1100 ? 180.0 : 210.0);

          return Padding(
            padding: const EdgeInsets.all(AppColors.gap),
            child: Column(
              children: [
                // ── Top row: [Logo box] + gap + [Header controls] ──
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      // Logo section — same width as the sidebar below
                      _LogoBox(
                        width: sidebarWidth,
                        collapsed: collapsed,
                      ),
                      const SizedBox(width: AppColors.gap),
                      // Header controls — takes all remaining space, never overflows
                      Expanded(
                        child: AppHeader(
                          isRefreshing: _isRefreshing,
                          refreshSpinCtrl: _refreshSpinCtrl,
                          onRefresh: _onRefresh,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppColors.gap),
                // ── Sidebar + screen content ──
                Expanded(
                  child: Row(
                    children: [
                      Sidebar(
                        selectedIndex: _selectedIndex,
                        onItemSelected: _onNavSelected,
                        hasAnalysis: _pendingUrl != null,
                        onAnalyzeSelected: () => _onNavSelected(5),
                        width: sidebarWidth,
                        collapsed: collapsed,
                      ),
                      const SizedBox(width: AppColors.gap),
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Screens 0–4: swapped via AnimatedSwitcher with slide
                            Offstage(
                              offstage: _selectedIndex == 5,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  final slide = Tween<Offset>(
                                    begin: const Offset(0.04, 0),
                                    end: Offset.zero,
                                  ).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(position: slide, child: child),
                                  );
                                },
                                child: KeyedSubtree(
                                  key: ValueKey(
                                      '${_selectedIndex < 5 ? _selectedIndex : 0}-$_screenRefreshKey'),
                                  child: _buildNonAnalyzeScreen(),
                                ),
                              ),
                            ),
                            // Analyze screen — kept alive in the widget tree
                            if (_pendingUrl != null)
                              Offstage(
                                offstage: _selectedIndex != 5,
                                child: AnalyzedScreen(
                                  key: ValueKey('$_pendingUrl-$_fetchKey'),
                                  initialUrl: _pendingUrl,
                                  onDownload: () => _onNavSelected(2),
                                ),
                              ),
                            // ── Refresh overlay ──────────────────────────────
                            if (_isRefreshing)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: AnimatedOpacity(
                                    opacity: _isRefreshing ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.bg.withOpacity(0.72),
                                        borderRadius: BorderRadius.circular(AppColors.radius),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 48,
                                              height: 48,
                                              child: _GlowSpinner(controller: _refreshSpinCtrl),
                                            ),
                                            const SizedBox(height: 14),
                                            Text(
                                              'Refreshing...',
                                              style: const TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}

/// Standalone logo panel that sits above the sidebar (same width).
class _LogoBox extends StatelessWidget {
  final double width;
  final bool collapsed;
  const _LogoBox({required this.width, required this.collapsed});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.green.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: collapsed
            ? Center(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.green,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(color: AppColors.greenGlow, blurRadius: 16),
                    ],
                  ),
                  child: const Icon(Icons.check, color: Colors.black, size: 18),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(color: AppColors.greenGlow, blurRadius: 16),
                      ],
                    ),
                    child:
                        const Icon(Icons.check, color: Colors.black, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'TubeDown',
                      style: const TextStyle(
                        fontFamily: 'Syne',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.text,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Cool glowing spinner for refresh overlay ─────────────────────────────────

class _GlowSpinner extends StatelessWidget {
  final AnimationController controller;
  const _GlowSpinner({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Transform.rotate(
          angle: controller.value * 2 * 3.14159265,
          child: CustomPaint(
            painter: _GlowArcPainter(progress: controller.value),
            size: const Size(48, 48),
          ),
        );
      },
    );
  }
}

class _GlowArcPainter extends CustomPainter {
  final double progress;
  const _GlowArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const color = AppColors.green;
    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);

    // Glow ring
    final glowPaint = Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(rect, 0, 3.14159 * 1.7, false, glowPaint);

    // Main arc
    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: [color.withOpacity(0.1), color],
        startAngle: 0,
        endAngle: 3.14159 * 1.7,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 3.14159 * 1.7, false, arcPaint);
  }

  @override
  bool shouldRepaint(_GlowArcPainter old) => old.progress != progress;
}
