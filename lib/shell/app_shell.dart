import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../providers/app_state.dart';
import '../widgets/sidebar.dart';
import '../widgets/app_header.dart';
import '../widgets/app_notification.dart';
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

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
    AppState.instance.addListener(_drainNotifications);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_drainNotifications);
    _refreshSpinCtrl.dispose();
    super.dispose();
  }

  void _drainNotifications() {
    final notifs = AppState.instance.drainNotifications();
    if (notifs.isEmpty) return;
    for (final n in notifs) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final (type, icon) = switch (n.type) {
          DownloadNotifType.videoPhase => (NotificationType.info, null),
          DownloadNotifType.audioPhase => (NotificationType.info, null),
          DownloadNotifType.mergeDone => (NotificationType.success, null),
        };
        showAppNotification(
          context,
          type: type,
          message: n.message,
          subtitle: n.subtitle,
          duration: const Duration(seconds: 3),
        );
      });
    }
  }

  Widget _buildNonAnalyzeScreen() {
    switch (_selectedIndex < 5 ? _selectedIndex : 0) {
      case 0:
        return DashboardScreen(onAnalyze: _goToAnalyzed);
      case 1:
        return const LibraryScreen();
      case 2:
        return DownloadsScreen(onAnalyze: _goToAnalyzed);
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
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        elevation: 0,
        width: 280,
        child: Padding(
          padding: const EdgeInsets.only(
            top: AppColors.gap,
            bottom: AppColors.gap,
            left: 8,
          ),
          child: Sidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (i) {
              _onNavSelected(i);
              if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
                Navigator.pop(context);
              }
            },
            hasAnalysis: _pendingUrl != null,
            onAnalyzeSelected: () {
              _onNavSelected(5);
              if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
                Navigator.pop(context);
              }
            },
            width: 280,
            collapsed: false,
            drawerMode: true,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.0, -0.9),
            radius: 1.4,
            colors: [
              Color.lerp(const Color(0xFF060809), AppColors.accent, 0.12)!, // accent tint at top
              const Color(0xFF080B08), // near-black mid
              const Color(0xFF060809), // deep base
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            // Responsive sidebar: hidden in drawer <700, collapsed icon-only 700-800, full >800
                final isDrawer = w < 900;
            final collapsed = !isDrawer && w < 1200;
            final sidebarWidth =
                isDrawer
                    ? 0.0
                    : (collapsed ? 60.0 : (w < 1100 ? 180.0 : 210.0));

            return Padding(
              padding: const EdgeInsets.all(AppColors.gap),
              child: Column(
                children: [
                  // Top row: [Logo box] + gap + [Header controls]
                  SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        // Logo section — same width as the sidebar below
                        if (!isDrawer) ...[
                          _LogoBox(width: sidebarWidth, collapsed: collapsed),
                          const SizedBox(width: AppColors.gap),
                        ],
                        // Header controls — takes all remaining space, never overflows
                        Expanded(
                          child: AppHeader(
                            isRefreshing: _isRefreshing,
                            refreshSpinCtrl: _refreshSpinCtrl,
                            onRefresh: _onRefresh,
                            onOpenDrawer:
                                isDrawer
                                    ? () =>
                                        _scaffoldKey.currentState?.openDrawer()
                                    : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppColors.gap),
                  // Sidebar + screen content
                  Expanded(
                    child: Row(
                      children: [
                        if (!isDrawer) ...[
                          Sidebar(
                            selectedIndex: _selectedIndex,
                            onItemSelected: _onNavSelected,
                            hasAnalysis: _pendingUrl != null,
                            onAnalyzeSelected: () => _onNavSelected(5),
                            width: sidebarWidth,
                            collapsed: collapsed,
                          ),
                          const SizedBox(width: AppColors.gap),
                        ],
                        Expanded(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // All screens (0–5) unified via AnimatedSwitcher
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  final slide = Tween<Offset>(
                                    begin: const Offset(0.04, 0),
                                    end: Offset.zero,
                                  ).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: slide,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _selectedIndex == 5 && _pendingUrl != null
                                    ? KeyedSubtree(
                                        key: ValueKey('analyze-$_pendingUrl-$_fetchKey'),
                                        child: AnalyzedScreen(
                                            key: ValueKey('$_pendingUrl-$_fetchKey'),
                                            initialUrl: _pendingUrl,
                                            onDownload: () => _onNavSelected(2),
                                            onQueue: () => _onNavSelected(0),
                                            onError: () {
                                              setState(() {
                                                _selectedIndex = 0;
                                                _pendingUrl = null;
                                              });
                                            },
                                          ),
                                      )
                                    : KeyedSubtree(
                                        key: ValueKey(
                                          'nav-${_selectedIndex < 5 ? _selectedIndex : 0}-$_screenRefreshKey',
                                        ),
                                        child: _buildNonAnalyzeScreen(),
                                      ),
                              ),
                              // Refresh overlay
                              if (_isRefreshing)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: AnimatedOpacity(
                                      opacity: _isRefreshing ? 1.0 : 0.0,
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.bg.withOpacity(0.72),
                                          borderRadius: BorderRadius.circular(
                                            AppColors.radius,
                                          ),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 48,
                                                height: 48,
                                                child: _GlowSpinner(
                                                  controller: _refreshSpinCtrl,
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              Text(
                                                'Refreshing...',
                                                style: TextStyle(
                                                  fontFamily: 'Outfit',
                                                  fontSize: 13,
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
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppColors.surfaceTransparent,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      // OverflowBox + SizedBox(width: width) — same pattern as Sidebar —
      // prevents RenderFlex overflow during the expand/collapse animation.
      child: OverflowBox(
        minWidth: 0,
        maxWidth: width,
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: width,
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child:
            collapsed
                ? Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(color: AppColors.accentGlow, blurRadius: 16),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.black,
                      size: 18,
                    ),
                  ),
                )
                : Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(color: AppColors.accentGlow, blurRadius: 16),
                        ],
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.black,
                        size: 18,
                      ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
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
        ),
      ),
    );
  }
}

// Cool glowing spinner for refresh overlay
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
    final color = AppColors.accent;
    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);

    // Glow ring
    final glowPaint =
        Paint()
          ..color = color.withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(rect, 0, 3.14159 * 1.7, false, glowPaint);

    // Main arc
    final arcPaint =
        Paint()
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
