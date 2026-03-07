import 'package:flutter/material.dart';
import '../core/app_colors.dart';
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

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  void _onNavSelected(int index) => setState(() => _selectedIndex = index);
  void _goToAnalyzed() => setState(() => _selectedIndex = 5);

  Widget _buildScreen() {
    switch (_selectedIndex) {
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
      case 5:
        return AnalyzedScreen(onDownload: () => _onNavSelected(2));
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
                      const Expanded(child: AppHeader()),
                    ],
                  ),
                ),
                const SizedBox(height: AppColors.gap),
                // ── Sidebar + screen content ──
                Expanded(
                  child: Row(
                    children: [
                      Sidebar(
                        selectedIndex: _selectedIndex > 4 ? -1 : _selectedIndex,
                        onItemSelected: _onNavSelected,
                        width: sidebarWidth,
                        collapsed: collapsed,
                      ),
                      const SizedBox(width: AppColors.gap),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: KeyedSubtree(
                            key: ValueKey(_selectedIndex),
                            child: _buildScreen(),
                          ),
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
