import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/download_item.dart';
import '../providers/app_state.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final double width;
  final bool collapsed;
  final bool hasAnalysis;
  final VoidCallback? onAnalyzeSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.width = 210,
    this.collapsed = false,
    this.hasAnalysis = false,
    this.onAnalyzeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.green.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppColors.radius),
        child: Stack(
          children: [
            // Subtle green glow at bottom
            Positioned(
              bottom: -80,
              left: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.green.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Nav content — clipped to prevent any overflow warnings
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 8 : 12,
                vertical: 18,
              ),
              child: Column(
                crossAxisAlignment: collapsed
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  if (!collapsed) ...[
                    Text('MAIN', style: AppTextStyles.navGroupLabel),
                    const SizedBox(height: 4),
                  ] else
                    const SizedBox(height: 4),
                  Expanded(
                    child: ClipRect(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: collapsed
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _NavItem(
                              icon: Icons.dashboard_rounded,
                              label: 'Dashboard',
                              isActive: selectedIndex == 0,
                              onTap: () => onItemSelected(0),
                              collapsed: collapsed,
                            ),
                            if (hasAnalysis)
                              _NavItem(
                                icon: Icons.analytics_rounded,
                                label: 'Analyze',
                                isActive: selectedIndex == 5,
                                onTap: () => onAnalyzeSelected?.call(),
                                collapsed: collapsed,
                                accent: const Color(0xFF22C55E),
                              ),
                            _NavItem(
                              icon: Icons.video_library_rounded,
                              label: 'Library',
                              isActive: selectedIndex == 1,
                              onTap: () => onItemSelected(1),
                              collapsed: collapsed,
                            ),
                            ListenableBuilder(
                              listenable: AppState.instance,
                              builder: (_, __) {
                                final n = AppState.instance.downloads
                                    .where((d) =>
                                        d.status == DownloadStatus.downloading ||
                                        d.status == DownloadStatus.queued)
                                    .length;
                                return _NavItem(
                                  icon: Icons.download_rounded,
                                  label: 'Downloads',
                                  badge: n > 0 ? '$n' : null,
                                  isActive: selectedIndex == 2,
                                  onTap: () => onItemSelected(2),
                                  collapsed: collapsed,
                                );
                              },
                            ),
                            _NavItem(
                              icon: Icons.history_rounded,
                              label: 'History',
                              isActive: selectedIndex == 3,
                              onTap: () => onItemSelected(3),
                              collapsed: collapsed,
                            ),
                            if (!collapsed) ...[
                              const SizedBox(height: 4),
                              Text('MORE', style: AppTextStyles.navGroupLabel),
                              const SizedBox(height: 4),
                            ] else
                              const SizedBox(height: 8),
                            _NavItem(
                              icon: Icons.settings_rounded,
                              label: 'Settings',
                              isActive: selectedIndex == 4,
                              onTap: () => onItemSelected(4),
                              collapsed: collapsed,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!collapsed) ...[
                    const SizedBox(height: 8),
                    _buildStorageBox(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageBox() {
    final totalBytes = AppState.instance.totalStorageBytes;
    final label = AppState.formatBytes(totalBytes);
    // Show count of completed downloads
    final count = AppState.instance.downloads
        .where((d) => d.status == DownloadStatus.done)
        .length;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Storage',
                  style: AppTextStyles.outfit(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              Text('$count files',
                  style: AppTextStyles.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.green)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.storage_rounded, size: 12, color: AppColors.muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text),
              ),
              Text(
                ' used',
                style: AppTextStyles.outfit(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final bool isActive;
  final VoidCallback onTap;
  final bool collapsed;
  final Color? accent;

  const _NavItem({
    required this.icon,
    required this.label,
    this.badge,
    required this.isActive,
    required this.onTap,
    this.collapsed = false,
    this.accent,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final accent = widget.accent ?? AppColors.green;
    final bg = isActive
        ? accent.withOpacity(0.12)
        : (_hovered ? AppColors.surface2 : Colors.transparent);
    final borderColor = isActive
        ? accent.withOpacity(0.25)
        : Colors.transparent;
    final iconColor = isActive
        ? accent
        : (_hovered ? AppColors.text : AppColors.muted);

    if (widget.collapsed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Tooltip(
          message: widget.label,
          preferBelow: false,
          textStyle: AppTextStyles.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.text,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            border: Border.all(color: AppColors.green.withOpacity(0.35)),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bg,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(widget.icon, size: 18, color: iconColor),
                    if (widget.badge != null)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Full label mode
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 16, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: AppTextStyles.outfit(fontSize: 13, color: iconColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.badge!,
                      style: AppTextStyles.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

