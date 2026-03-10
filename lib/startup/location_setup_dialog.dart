import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

/// Full-screen overlay dialog prompting the user to pick a download folder.
class LocationSetupDialog extends StatefulWidget {
  final void Function(String path) onLocationSet;

  const LocationSetupDialog({super.key, required this.onLocationSet});

  @override
  State<LocationSetupDialog> createState() => _LocationSetupDialogState();
}

class _LocationSetupDialogState extends State<LocationSetupDialog>
    with SingleTickerProviderStateMixin {
  String? _selectedPath;
  bool _picking = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 300))
          ..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    setState(() => _picking = true);
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select download folder',
    );
    setState(() {
      _picking = false;
      if (path != null) _selectedPath = path;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Container(
        color: Colors.black.withOpacity(0.72),
        child: Center(
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              border: Border.all(color: AppColors.accent.withOpacity(0.30)),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.08),
                  blurRadius: 60,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon + title
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accentDim,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                            color: AppColors.accent.withOpacity(0.35)),
                      ),
                      child: Icon(Icons.folder_open_rounded,
                          color: AppColors.accent, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set Download Location',
                          style: AppTextStyles.syne(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Choose where your files will be saved',
                          style: AppTextStyles.outfit(
                              fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Folder picker row
                GestureDetector(
                  onTap: _picking ? null : _pickFolder,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
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
                              : Icons.folder_rounded,
                          size: 18,
                          color: _selectedPath != null
                              ? AppColors.accent
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedPath ?? 'Click to browse…',
                            style: AppTextStyles.mono(
                              fontSize: 12,
                              color: _selectedPath != null
                                  ? AppColors.text
                                  : AppColors.muted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_picking)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          )
                        else
                          Icon(Icons.open_in_new_rounded,
                              size: 15, color: AppColors.muted),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Confirm button
                SizedBox(
                  width: double.infinity,
                  child: _ConfirmButton(
                    enabled: _selectedPath != null,
                    onTap: () {
                      if (_selectedPath != null) {
                        widget.onLocationSet(_selectedPath!);
                      }
                    },
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

class _ConfirmButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _ConfirmButton({required this.enabled, required this.onTap});

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: widget.enabled
                ? AppColors.accent
                : AppColors.surface3,
            borderRadius: BorderRadius.circular(12),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: AppColors.accentGlow.withOpacity(_hov ? 0.5 : 0.28),
                      blurRadius: _hov ? 28 : 18,
                      offset: Offset(0, _hov ? 6 : 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: widget.enabled ? Colors.black : AppColors.muted,
                ),
                const SizedBox(width: 8),
                Text(
                  'Confirm Location',
                  style: AppTextStyles.syne(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: widget.enabled ? Colors.black : AppColors.muted,
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
