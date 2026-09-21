import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../providers/app_state.dart';

/// Modal dialog that shows the available app update and handles the install flow.
class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({super.key});

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    AppState.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final isDownloading = state.appUpdating;
    final progress = state.appUpdateProgress;
    final error = state.appUpdateError;
    final pct = (progress * 100).clamp(0, 100).toInt();

    return Dialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.system_update_rounded,
                      color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'App Update Available',
                  style: AppTextStyles.syne(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (!isDownloading)
                  _IconBtn(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Version comparison card ────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _VersionCol(
                    label: 'INSTALLED',
                    version: AppState.appVersion,
                    color: AppColors.muted,
                  ),
                  const Icon(Icons.arrow_forward_rounded,
                      color: Colors.orange, size: 18),
                  _VersionCol(
                    label: 'LATEST',
                    version: state.latestAppVersion ?? '—',
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Description ───────────────────────────────────────────────
            Text(
              'A new version of DownTube is available on GitHub. '
              'Click "Update Now" to download and install it automatically.',
              style: AppTextStyles.outfit(
                fontSize: 13,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // ── Progress bar (visible during download) ────────────────────
            if (isDownloading) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    pct < 100 ? 'Downloading installer…' : 'Launching installer…',
                    style: AppTextStyles.outfit(
                        fontSize: 12, color: AppColors.muted),
                  ),
                  Text(
                    pct < 100 ? '$pct%' : '✓',
                    style: AppTextStyles.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (_, v, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: v,
                    backgroundColor: AppColors.surface2,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.orange),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Error message ─────────────────────────────────────────────
            if (error != null && !isDownloading) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.red.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: AppColors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error,
                        style: AppTextStyles.outfit(
                            fontSize: 12, color: AppColors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Action buttons ────────────────────────────────────────────
            if (!isDownloading)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Later',
                      style: AppTextStyles.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(
                      _started ? 'Retry' : 'Update Now',
                      style: AppTextStyles.outfit(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      setState(() => _started = true);
                      AppState.instance.downloadAndInstallApp();
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _VersionCol extends StatelessWidget {
  final String label;
  final String version;
  final Color color;
  const _VersionCol(
      {required this.label, required this.version, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: AppTextStyles.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.6))),
        const SizedBox(height: 4),
        Text(version,
            style: AppTextStyles.outfit(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 18, color: AppColors.muted),
      ),
    );
  }
}
