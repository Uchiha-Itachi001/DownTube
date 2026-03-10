import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../models/download_item.dart';
import '../providers/app_state.dart';
import '../widgets/app_notification.dart';
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
    (icon: Icons.notifications_rounded, label: 'Notifications'),
    (icon: Icons.palette_rounded, label: 'Appearance'),
    (icon: Icons.person_rounded, label: 'Account'),
    (icon: Icons.info_outline_rounded, label: 'Info'),
    (icon: Icons.warning_amber_rounded, label: 'Reset'),
  ];

  // Profile editing controllers
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(
      text: AppState.instance.userFirstName ?? '',
    );
    _lastNameCtrl = TextEditingController(
      text: AppState.instance.userLastName ?? '',
    );
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNav(),
            const SizedBox(width: AppColors.gap),
            Expanded(child: _buildContent()),
          ],
        );
      },
    );
  }

  // --- NAV -----------------------------------------------------------------

  Widget _buildNav() {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceTransparent,
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
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
              padding: EdgeInsets.only(bottom: 2, top: isReset ? 8 : 0),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedNav = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isActive ? AppColors.accentDim : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: isActive
                          ? Border.all(
                              color:
                                  AppColors.accent.withValues(alpha: 0.15),
                            )
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
                                  ? AppColors.accent
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
                                    ? AppColors.accent
                                    : AppColors.muted,
                          ),
                        ),
                        const Spacer(),
                        if (isActive)
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
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
          _buildStorageUsage(),
        ],
      ),
    );
  }

  Widget _buildStorageUsage() {
    final totalBytes = AppState.instance.totalStorageBytes;
    final label = AppState.formatBytes(totalBytes);
    final count = AppState.instance.downloads
        .where((d) => d.status == DownloadStatus.done)
        .length;
    return Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceTransparent2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, size: 13, color: AppColors.accent),
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
          Text(
            label,
            style: AppTextStyles.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$count downloads',
            style: AppTextStyles.outfit(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  // --- CONTENT -------------------------------------------------------------

  Widget _buildContent() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceTransparent,
        border: Border.all(color: AppColors.accent.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(AppColors.radius),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContentHeader(),
            const SizedBox(height: 20),
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
            color: AppColors.accentDim,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
          ),
          child: Center(
            child: Icon(item.icon, size: 18, color: AppColors.accent),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.label,
              style: AppTextStyles.syne(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _sectionDescription(),
              style:
                  AppTextStyles.outfit(fontSize: 12, color: AppColors.muted),
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
      4 => 'Notification preferences',
      5 => 'Theme and display options',
      6 => 'Your profile and display name',
      7 => 'App version, engine info and updates',
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
      4 => _notificationsSection(),
      5 => _appearanceSection(),
      6 => _accountSection(),
      7 => _infoSection(),
      8 => _resetSection(),
      _ => const SizedBox.shrink(),
    };
  }

  // --- DOWNLOADS -----------------------------------------------------------

  Widget _downloadsSection() {
    final state = AppState.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingRow(
          'Auto-download on paste',
          'Automatically start download when URL is pasted',
          icon: Icons.content_paste_rounded,
          trailing: ToggleSwitch(
            value: state.autoDownload,
            onChanged: (v) => state.setAutoDownload(v),
          ),
        ),
        _settingRow(
          'Max Concurrent Downloads',
          state.autoDownload
              ? 'Auto-managed based on queue size (1-500)'
              : 'Number of files downloading simultaneously (1-500)',
          icon: Icons.downloading_rounded,
          trailing: state.autoDownload
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accentDim,
                    border: Border.all(
                        color: AppColors.accent.withOpacity(0.25)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Auto',
                    style: AppTextStyles.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        _settingRow(
          'Embed Subtitles',
          'Automatically embed available subtitles',
          icon: Icons.subtitles_rounded,
          trailing: ToggleSwitch(
            value: state.embedSubs,
            onChanged: (v) => state.setEmbedSubs(v),
          ),
        ),
        _settingRow(
          'Save Thumbnail',
          'Download and embed video thumbnail',
          icon: Icons.image_rounded,
          trailing: ToggleSwitch(
            value: state.saveThumbnail,
            onChanged: (v) => state.setSaveThumbnail(v),
          ),
        ),
        _settingRow(
          'Add Chapters',
          'Include chapter markers in download',
          icon: Icons.bookmark_border_rounded,
          trailing: ToggleSwitch(
            value: state.addChapters,
            onChanged: (v) => state.setAddChapters(v),
          ),
        ),
      ],
    );
  }

  // --- VIDEO ---------------------------------------------------------------

  Widget _videoSection() {
    final state = AppState.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingRow(
          'Default Quality',
          'Applied automatically when analyzing a video',
          icon: Icons.high_quality_rounded,
          trailing: _dropdown(state.defaultQuality, [
            'Best',
            '4K',
            '1080p',
            '720p',
            '480p',
            '360p',
          ], (v) => state.setDefaultQuality(v)),
        ),
        _settingRow(
          'Default Format',
          'Applied automatically to every download',
          icon: Icons.video_file_rounded,
          trailing: _dropdown(state.defaultFormat, [
            'MP4',
            'MKV',
            'WEBM',
          ], (v) => state.setDefaultFormat(v)),
        ),
      ],
    );
  }

  // --- AUDIO ---------------------------------------------------------------

  Widget _audioSection() {
    final state = AppState.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingRow(
          'Audio Format',
          'Applied automatically for audio downloads',
          icon: Icons.audio_file_rounded,
          trailing: _dropdown(state.defaultAudioFormat, [
            'MP3',
            'FLAC',
            'WAV',
            'AAC',
            'OGG',
          ], (v) => state.setDefaultAudioFormat(v)),
        ),
        _settingRow(
          'Bitrate',
          'Audio quality bitrate',
          icon: Icons.graphic_eq_rounded,
          trailing: _dropdown(state.audioBitrate, [
            '128 kbps',
            '192 kbps',
            '256 kbps',
            '320 kbps',
          ], (v) => state.setAudioBitrate(v)),
        ),
      ],
    );
  }

  // --- STORAGE -------------------------------------------------------------

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
    final videoBytes = AppState.instance.videoStorageBytes;
    final audioBytes = AppState.instance.audioStorageBytes;
    final totalBytes = AppState.instance.totalStorageBytes;
    final otherBytes = totalBytes - videoBytes - audioBytes;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceTransparent2,
        border: Border.all(color: AppColors.accent.withOpacity(0.20)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              const Spacer(),
              Text(
                AppState.formatBytes(totalBytes),
                style: AppTextStyles.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _storageItem('Videos', videoBytes, totalBytes, AppColors.accent),
          const SizedBox(height: 8),
          _storageItem(
              'Audio', audioBytes, totalBytes, const Color(0xFF3B82F6)),
          if (otherBytes > 0) ...[
            const SizedBox(height: 8),
            _storageItem('Other', otherBytes, totalBytes, AppColors.muted),
          ],
        ],
      ),
    );
  }

  Widget _storageItem(String label, int bytes, int totalBytes, Color color) {
    final fraction =
        totalBytes > 0 ? (bytes / totalBytes).clamp(0.0, 1.0) : 0.0;
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
          AppState.formatBytes(bytes),
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
                  widthFactor: fraction,
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

  // --- NOTIFICATIONS -------------------------------------------------------

  Widget _notificationsSection() {
    final state = AppState.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingRow(
          'Desktop Notifications',
          'Show system notifications when downloads complete',
          icon: Icons.notifications_active_rounded,
          trailing: ToggleSwitch(
            value: state.notificationsEnabled,
            onChanged: (v) => state.setNotificationsEnabled(v),
          ),
        ),
        _settingRow(
          'Sound Effects',
          'Play sound when download completes',
          icon: Icons.volume_up_rounded,
          trailing: ToggleSwitch(
            value: state.soundEffects,
            onChanged: (v) => state.setSoundEffects(v),
          ),
        ),
      ],
    );
  }

  // --- APPEARANCE ----------------------------------------------------------

  Widget _appearanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _settingRow(
          'Accent Color',
          'Choose the app accent color. Changes take effect immediately.',
          icon: Icons.palette_rounded,
          trailing: const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: AppColors.themeOptions.map((opt) {
            final isSelected = AppState.instance.themeColor.toARGB32() ==
                opt.color.toARGB32();
            return GestureDetector(
              onTap: () => AppState.instance.setThemeColor(opt.color),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Tooltip(
                  message: opt.name,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: opt.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: opt.color.withValues(alpha: 0.5),
                                blurRadius: 12,
                              ),
                            ]
                          : [],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.black, size: 20)
                        : null,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- ACCOUNT / PROFILE ---------------------------------------------------

  Widget _accountSection() {
    final state = AppState.instance;
    final hasPic =
        state.userProfilePic != null && File(state.userProfilePic!).existsSync();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceTransparent2,
            border: Border.all(color: AppColors.accent.withOpacity(0.20)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: _pickProfilePicture,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.accentDim,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.accent.withOpacity(0.40),
                            width: 2,
                          ),
                          image: hasPic
                              ? DecorationImage(
                                  image:
                                      FileImage(File(state.userProfilePic!)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: hasPic
                            ? null
                            : Center(
                                child: Text(
                                  state.userInitial,
                                  style: AppTextStyles.syne(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
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
                                color: AppColors.bg, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 12, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Name + info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.userDisplayName,
                      style: AppTextStyles.syne(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All data is stored locally - nothing leaves your device.',
                      style: AppTextStyles.outfit(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Edit fields
        _settingRow(
          'First Name',
          'Your display first name',
          icon: Icons.badge_rounded,
          trailing: _textInput(
            _firstNameCtrl,
            onChanged: (v) {
              AppState.instance.setUserProfile(
                firstName: v,
                lastName: _lastNameCtrl.text,
              );
            },
          ),
        ),
        _settingRow(
          'Last Name',
          'Your display last name',
          icon: Icons.badge_rounded,
          trailing: _textInput(
            _lastNameCtrl,
            onChanged: (v) {
              AppState.instance.setUserProfile(
                firstName: _firstNameCtrl.text,
                lastName: v,
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pickProfilePicture() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      await AppState.instance.setUserProfilePicture(result.files.single.path!);
    }
  }

  // --- INFO ----------------------------------------------------------------

  Widget _infoSection() {
    final state = AppState.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // App info card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceTransparent,
            border: Border.all(color: AppColors.accent.withOpacity(0.30)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.accentDim,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                          color: AppColors.accent.withOpacity(0.25)),
                    ),
                    child: Icon(Icons.download_rounded,
                        size: 22, color: AppColors.accent),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DownTube',
                        style: AppTextStyles.syne(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'v2.4.0 - Open Source Video Downloader',
                        style: AppTextStyles.outfit(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceTransparent2,
                  border: Border.all(color: AppColors.accent.withOpacity(0.18)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RELEASE NOTES',
                      style: AppTextStyles.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _releaseItem('Transparent UI with glass effect'),
                        _releaseItem('User profile and first-time setup'),
                        _releaseItem('Persistent video & audio defaults'),
                        _releaseItem('Info tab with engine updates'),
                        _releaseItem('Improved settings layout'),
                        _releaseItem('Playlist batch downloads'),
                        _releaseItem('SQLite download history'),
                        _releaseItem('Session stats & live speed'),
                        _releaseItem('Smart yt-dlp error handling'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // yt-dlp engine info
        _settingRow(
          'yt-dlp Engine',
          state.ytDlpReady
              ? 'Version: ${state.ytDlpVersion ?? "Unknown"}'
              : 'Engine not found',
          icon: Icons.engineering_rounded,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: state.ytDlpReady ? AppColors.accent : AppColors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                state.ytDlpReady ? 'Ready' : 'Offline',
                style: AppTextStyles.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: state.ytDlpReady ? AppColors.accent : AppColors.red,
                ),
              ),
            ],
          ),
        ),
        _settingRow(
          'Auto-update yt-dlp',
          'Keep yt-dlp engine updated automatically',
          icon: Icons.system_update_rounded,
          trailing: ToggleSwitch(
            value: state.autoUpdateYtDlp,
            onChanged: (v) => state.setAutoUpdateYtDlp(v),
          ),
        ),
      ],
    );
  }

  Widget _releaseItem(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accentDim,
        border: Border.all(color: AppColors.accent.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 12, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.outfit(
              fontSize: 11,
              color: AppColors.text.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  // --- RESET ---------------------------------------------------------------

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
              Icon(Icons.warning_amber_rounded,
                  size: 20, color: AppColors.red),
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
          _dangerButton(
            'Reset All Settings',
            Icons.settings_backup_restore_rounded,
            () {
              _showConfirmDialog(
                title: 'Reset All Settings',
                message:
                    'This will reset all preferences to default values. This action cannot be undone.',
                onConfirm: () async {
                  Navigator.of(context).pop();
                  await AppState.instance.resetAllSettings();
                  if (context.mounted) {
                    showAppNotification(
                      context,
                      type: NotificationType.success,
                      message: 'Settings reset to defaults',
                      duration: const Duration(seconds: 3),
                    );
                  }
                },
              );
            },
          ),
          const SizedBox(height: 8),
          _dangerButton(
              'Clear Download History', Icons.delete_sweep_rounded, () {
            _showConfirmDialog(
              title: 'Clear Download History',
              message:
                  'This will permanently remove all download records from the database. Downloaded files on disk will not be deleted.',
              onConfirm: () async {
                Navigator.of(context).pop();
                await AppState.instance.clearHistory();
                if (context.mounted) {
                  showAppNotification(
                    context,
                    type: NotificationType.success,
                    message: 'Download history cleared',
                    duration: const Duration(seconds: 3),
                  );
                }
              },
            );
          }),
          const SizedBox(height: 8),
          _dangerButton('Clear Cache', Icons.cleaning_services_rounded, () {
            _showConfirmDialog(
              title: 'Clear Cache',
              message:
                  'This will remove download records for files that no longer exist on disk. Active downloads will not be affected.',
              onConfirm: () async {
                Navigator.of(context).pop();
                final removed =
                    await AppState.instance.cleanMissingFiles();
                if (context.mounted) {
                  showAppNotification(
                    context,
                    type: NotificationType.success,
                    message: removed > 0
                        ? 'Removed $removed stale record${removed > 1 ? "s" : ""}'
                        : 'No stale records found',
                    duration: const Duration(seconds: 3),
                  );
                }
              },
            );
          }),
        ],
      ),
    );
  }

  // --- SHARED WIDGETS ------------------------------------------------------

  Widget _dangerButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceTransparent2,
            border: Border.all(color: AppColors.red.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 16, color: AppColors.red.withOpacity(0.7)),
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
      ),
    );
  }

  void _showConfirmDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.red.withOpacity(0.25)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 22, color: AppColors.red),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: AppTextStyles.syne(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  style: AppTextStyles.outfit(
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Cancel',
                            style: AppTextStyles.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onConfirm,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Confirm',
                            style: AppTextStyles.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingRow(
    String title,
    String subtitle, {
    required Widget trailing,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surfaceTransparent2,
          border: Border.all(color: AppColors.accent.withOpacity(0.15)),
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
                      fontSize: 11.5,
                      color: AppColors.muted,
                    ),
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
    String value,
    List<String> items,
    ValueChanged<String> onChanged,
  ) {
    final safeValue = items.contains(value) ? value : items.first;
    if (safeValue != value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(safeValue));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.surfaceTransparent2,
        border: Border.all(color: AppColors.accent.withOpacity(0.20)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          dropdownColor: AppColors.surface2,
          style: AppTextStyles.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          icon: const Icon(
            Icons.arrow_drop_down_rounded,
            size: 18,
            color: AppColors.muted,
          ),
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

  Widget _textInput(
    TextEditingController ctrl, {
    ValueChanged<String>? onChanged,
  }) {
    return SizedBox(
      width: 180,
      height: 32,
      child: TextField(
        controller: ctrl,
        onChanged: onChanged,
        style: AppTextStyles.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          filled: true,
          fillColor: AppColors.surfaceTransparent2,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: AppColors.accent.withOpacity(0.20)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: AppColors.accent.withOpacity(0.50)),
          ),
        ),
      ),
    );
  }

  Widget _pathInput() {
    final currentPath = AppState.instance.downloadPath ?? 'Not set';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final picked = await FilePicker.platform.getDirectoryPath();
          if (picked != null) {
            await AppState.instance.setDownloadPath(picked);
          }
        },
        child: Container(
          width: 240,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceTransparent2,
            border: Border.all(color: AppColors.accent, width: .5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  currentPath,
                  style: AppTextStyles.outfit(
                    fontSize: 12,
                    color: AppColors.accent.withOpacity(0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.folder_open_rounded,
                size: 16,
                color: AppColors.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
