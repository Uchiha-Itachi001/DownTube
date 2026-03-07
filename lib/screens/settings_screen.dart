import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../widgets/toggle_switch.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedNav = 0;

  static const _navItems = <({IconData icon, String label})>[
    (icon: Icons.download_rounded, label: 'Downloads'),
    (icon: Icons.movie_rounded, label: 'Video'),
    (icon: Icons.music_note_rounded, label: 'Audio'),
    (icon: Icons.storage_rounded, label: 'Storage'),
    (icon: Icons.language_rounded, label: 'Network'),
    (icon: Icons.notifications_rounded, label: 'Notifications'),
    (icon: Icons.palette_rounded, label: 'Appearance'),
    (icon: Icons.person_rounded, label: 'Account'),
    (icon: Icons.warning_amber_rounded, label: 'Reset'),
  ];

  // Settings state
  bool _autoDownload = true;
  bool _embedSubs = true;
  bool _saveThumbnail = true;
  bool _addChapters = false;
  bool _autoUpdate = true;
  bool _darkMode = true;
  bool _notifications = true;
  bool _soundEffects = false;
  int _maxConcurrent = 3;
  bool _limitBandwidth = false;

  String _defaultQuality = '1080p';
  String _defaultFormat = 'MP4';
  String _defaultAudioFormat = 'MP3';
  String _audioBitrate = '320 kbps';
  String _savePath = 'D:\\Downloads\\TubeDown';

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Settings nav
        _buildNav(),
        const SizedBox(width: AppColors.gap),
        // Settings content
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildNav() {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.settings_rounded, size: 14, color: AppColors.muted),
                const SizedBox(width: 6),
                Text(
                  'SETTINGS',
                  style: AppTextStyles.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(_navItems.length, (i) {
            final isActive = _selectedNav == i;
            final isReset = i == _navItems.length - 1;
            return Padding(
              padding: EdgeInsets.only(
                bottom: 2,
                top: isReset ? 8 : 0,
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedNav = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          isActive ? AppColors.greenDim : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: isActive
                          ? Border.all(color: AppColors.green.withOpacity(0.15))
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _navItems[i].icon,
                          size: 16,
                          color: isReset && !isActive
                              ? AppColors.red.withOpacity(0.7)
                              : isActive
                                  ? AppColors.green
                                  : AppColors.muted,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _navItems[i].label,
                          style: AppTextStyles.outfit(
                            fontSize: 13,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isReset && !isActive
                                ? AppColors.red.withOpacity(0.7)
                                : isActive
                                    ? AppColors.green
                                    : AppColors.muted,
                          ),
                        ),
                        const Spacer(),
                        if (isActive)
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppColors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          // Storage usage at bottom of nav
          _buildStorageUsage(),
        ],
      ),
    );
  }

  Widget _buildStorageUsage() {
    const used = 42.8;
    const total = 120.0;
    const fraction = used / total;
    return Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, size: 13, color: AppColors.green),
              const SizedBox(width: 6),
              Text(
                'Storage Used',
                style: AppTextStyles.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 5,
              child: Stack(
                children: [
                  Container(color: Colors.white.withOpacity(0.05)),
                  FractionallySizedBox(
                    widthFactor: fraction,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.green,
                            AppColors.green.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${used.toStringAsFixed(1)} / ${total.toStringAsFixed(0)} GB',
            style: AppTextStyles.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active section header
            _buildContentHeader(),
            const SizedBox(height: 20),
            // Content based on selected nav
            _buildSectionContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildContentHeader() {
    final item = _navItems[_selectedNav];
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.greenDim,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.green.withOpacity(0.15)),
          ),
          child: Center(
            child: Icon(item.icon, size: 18, color: AppColors.green),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.label,
              style: AppTextStyles.syne(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              _sectionDescription(),
              style: AppTextStyles.outfit(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ],
    );
  }

  String _sectionDescription() {
    return switch (_selectedNav) {
      0 => 'Configure download behavior and defaults',
      1 => 'Video quality and format preferences',
      2 => 'Audio extraction and format options',
      3 => 'Storage paths and file management',
      4 => 'Proxy and bandwidth settings',
      5 => 'Notification preferences',
      6 => 'Theme and display options',
      7 => 'Account and profile settings',
      8 => 'Reset app to defaults',
      _ => '',
    };
  }

  Widget _buildSectionContent() {
    return switch (_selectedNav) {
      0 => _downloadsSection(),
      1 => _videoSection(),
      2 => _audioSection(),
      3 => _storageSection(),
      4 => _networkSection(),
      5 => _notificationsSection(),
      6 => _appearanceSection(),
      7 => _accountSection(),
      8 => _resetSection(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _downloadsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingRow(
          'Auto-download on paste',
          'Automatically start download when URL is pasted',
          icon: Icons.content_paste_rounded,
          trailing: ToggleSwitch(
            value: _autoDownload,
            onChanged: (v) => setState(() => _autoDownload = v),
          ),
        ),
        _settingRow(
          'Max Concurrent Downloads',
          'Number of files downloading simultaneously',
          icon: Icons.downloading_rounded,
          trailing: _stepper(
            _maxConcurrent,
            (v) => setState(() => _maxConcurrent = v),
          ),
        ),
        _settingRow(
          'Embed Subtitles',
          'Automatically embed available subtitles',
          icon: Icons.subtitles_rounded,
          trailing: ToggleSwitch(
            value: _embedSubs,
            onChanged: (v) => setState(() => _embedSubs = v),
          ),
        ),
        _settingRow(
          'Save Thumbnail',
          'Download and embed video thumbnail',
          icon: Icons.image_rounded,
          trailing: ToggleSwitch(
            value: _saveThumbnail,
            onChanged: (v) => setState(() => _saveThumbnail = v),
          ),
        ),
        _settingRow(
          'Add Chapters',
          'Include chapter markers in download',
          icon: Icons.bookmark_border_rounded,
          trailing: ToggleSwitch(
            value: _addChapters,
            onChanged: (v) => setState(() => _addChapters = v),
          ),
        ),
      ],
    );
  }

  Widget _videoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingRow(
          'Default Quality',
          'Preferred video quality for downloads',
          icon: Icons.high_quality_rounded,
          trailing: _dropdown(
            _defaultQuality,
            ['4K', '1080p', '720p', '480p', '360p'],
            (v) => setState(() => _defaultQuality = v),
          ),
        ),
        _settingRow(
          'Default Format',
          'Preferred output container format',
          icon: Icons.video_file_rounded,
          trailing: _dropdown(
            _defaultFormat,
            ['MP4', 'MKV', 'WEBM'],
            (v) => setState(() => _defaultFormat = v),
          ),
        ),
      ],
    );
  }

  Widget _audioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingRow(
          'Audio Format',
          'Preferred audio extraction format',
          icon: Icons.audio_file_rounded,
          trailing: _dropdown(
            _defaultAudioFormat,
            ['MP3', 'FLAC', 'WAV', 'AAC', 'OGG'],
            (v) => setState(() => _defaultAudioFormat = v),
          ),
        ),
        _settingRow(
          'Bitrate',
          'Audio quality bitrate',
          icon: Icons.graphic_eq_rounded,
          trailing: _dropdown(
            _audioBitrate,
            ['128 kbps', '192 kbps', '256 kbps', '320 kbps'],
            (v) => setState(() => _audioBitrate = v),
          ),
        ),
      ],
    );
  }

  Widget _storageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingRow(
          'Save Location',
          'Where downloaded files are stored',
          icon: Icons.folder_rounded,
          trailing: _pathInput(),
        ),
        const SizedBox(height: 12),
        _buildStorageBreakdown(),
      ],
    );
  }

  Widget _buildStorageBreakdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STORAGE BREAKDOWN',
            style: AppTextStyles.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          _storageItem('Videos', 34.2, AppColors.green),
          const SizedBox(height: 8),
          _storageItem('Audio', 6.4, const Color(0xFF3B82F6)),
          const SizedBox(height: 8),
          _storageItem('Thumbnails', 1.8, AppColors.yellow),
          const SizedBox(height: 8),
          _storageItem('Other', 0.4, AppColors.muted),
        ],
      ),
    );
  }

  Widget _storageItem(String label, double gb, Color color) {
    const total = 120.0;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.outfit(fontSize: 12, color: AppColors.text),
          ),
        ),
        Text(
          '${gb.toStringAsFixed(1)} GB',
          style: AppTextStyles.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(color: Colors.white.withOpacity(0.05)),
                FractionallySizedBox(
                  widthFactor: (gb / total).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _networkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingRow(
          'Limit Bandwidth',
          'Restrict download speed to avoid network saturation',
          icon: Icons.speed_rounded,
          trailing: ToggleSwitch(
            value: _limitBandwidth,
            onChanged: (v) => setState(() => _limitBandwidth = v),
          ),
        ),
        _settingRow(
          'Auto-update YT-DLP',
          'Keep yt-dlp engine updated automatically',
          icon: Icons.system_update_rounded,
          trailing: ToggleSwitch(
            value: _autoUpdate,
            onChanged: (v) => setState(() => _autoUpdate = v),
          ),
        ),
      ],
    );
  }

  Widget _notificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingRow(
          'Desktop Notifications',
          'Show system notifications for downloads',
          icon: Icons.notifications_active_rounded,
          trailing: ToggleSwitch(
            value: _notifications,
            onChanged: (v) => setState(() => _notifications = v),
          ),
        ),
        _settingRow(
          'Sound Effects',
          'Play sound when download completes',
          icon: Icons.volume_up_rounded,
          trailing: ToggleSwitch(
            value: _soundEffects,
            onChanged: (v) => setState(() => _soundEffects = v),
          ),
        ),
      ],
    );
  }

  Widget _appearanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingRow(
          'Dark Mode',
          'Use dark theme across the application',
          icon: Icons.dark_mode_rounded,
          trailing: ToggleSwitch(
            value: _darkMode,
            onChanged: (v) => setState(() => _darkMode = v),
          ),
        ),
      ],
    );
  }

  Widget _accountSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(Icons.person_rounded, size: 42, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            'No account linked',
            style: AppTextStyles.outfit(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            'Sign in to sync settings across devices',
            style: AppTextStyles.outfit(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          // Version info
          Text(
            'DownTube v2.4.0',
            style: AppTextStyles.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Powered by yt-dlp 2024.12.06',
            style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted2),
          ),
        ],
      ),
    );
  }

  Widget _resetSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.red.withOpacity(0.05),
        border: Border.all(color: AppColors.red.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.red),
              const SizedBox(width: 8),
              Text(
                'Danger Zone',
                style: AppTextStyles.syne(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'These actions cannot be undone. Please proceed with caution.',
            style: AppTextStyles.outfit(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          _dangerButton('Reset All Settings', Icons.settings_backup_restore_rounded),
          const SizedBox(height: 8),
          _dangerButton('Clear Download History', Icons.delete_sweep_rounded),
          const SizedBox(height: 8),
          _dangerButton('Clear Cache', Icons.cleaning_services_rounded),
        ],
      ),
    );
  }

  Widget _dangerButton(String label, IconData icon) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          border: Border.all(color: AppColors.red.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.red.withOpacity(0.7)),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTextStyles.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.red.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingRow(String title, String subtitle,
      {required Widget trailing, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.muted),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.outfit(
                        fontSize: 11.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _dropdown(
      String value, List<String> items, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.surface3,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: AppColors.surface2,
          style: AppTextStyles.outfit(fontSize: 12, fontWeight: FontWeight.w500),
          icon: const Icon(Icons.arrow_drop_down_rounded,
              size: 18, color: AppColors.muted),
          items: items
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _stepper(int value, ValueChanged<int> onChanged) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.surface3,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepperBtn(Icons.remove_rounded, () {
            if (value > 1) onChanged(value - 1);
          }),
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: AppTextStyles.outfit(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          _stepperBtn(Icons.add_rounded, () {
            if (value < 10) onChanged(value + 1);
          }),
        ],
      ),
    );
  }

  Widget _stepperBtn(IconData icon, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(icon, size: 16, color: AppColors.muted),
        ),
      ),
    );
  }

  Widget _pathInput() {
    return Container(
      width: 240,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface3,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _savePath,
              style: AppTextStyles.outfit(fontSize: 12, color: AppColors.muted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                // File picker would go here in functionality phase
              },
              child: const Icon(
                Icons.folder_open_rounded,
                size: 16,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
