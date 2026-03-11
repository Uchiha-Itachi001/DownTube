import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static const _keyDownloadPath = 'download_path';
  static const _keyYtDlpPath = 'ytdlp_path';
  static const _keyThemeColor = 'theme_color';
  // User profile
  static const _keyUserFirstName = 'user_first_name';
  static const _keyUserLastName = 'user_last_name';
  static const _keyUserProfilePic = 'user_profile_pic';
  static const _keyUserSetupDone = 'user_setup_done';
  // Download settings
  static const _keyAutoDownload = 'auto_download';
  static const _keyEmbedSubs = 'embed_subs';
  static const _keySaveThumbnail = 'save_thumbnail';
  static const _keyAddChapters = 'add_chapters';
  static const _keyAutoUpdateYtDlp = 'auto_update_ytdlp';
  static const _keyNotifications = 'notifications_enabled';
  static const _keySoundEffects = 'sound_effects';
  // Video defaults
  static const _keyDefaultQuality = 'default_quality';
  static const _keyDefaultFormat = 'default_format';
  // Audio defaults
  static const _keyDefaultAudioFormat = 'default_audio_format';
  static const _keyAudioBitrate = 'audio_bitrate';
  // Concurrent / limit
  static const _keyConcurrentDownloads = 'concurrent_downloads';
  static const _keyMaxDownloadLimit = 'max_download_limit';

  final SharedPreferences _prefs;
  PrefsService._(this._prefs);

  static Future<PrefsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PrefsService._(prefs);
  }

  // Download path
  String? get downloadPath => _prefs.getString(_keyDownloadPath);
  Future<void> setDownloadPath(String path) =>
      _prefs.setString(_keyDownloadPath, path);
  Future<void> clearDownloadPath() => _prefs.remove(_keyDownloadPath);

  // yt-dlp path
  String? get ytDlpPath => _prefs.getString(_keyYtDlpPath);
  Future<void> setYtDlpPath(String path) =>
      _prefs.setString(_keyYtDlpPath, path);

  // Theme color
  Color? get themeColor {
    final v = _prefs.getInt(_keyThemeColor);
    return v == null ? null : Color(v);
  }
  Future<void> setThemeColor(Color color) =>
      _prefs.setInt(_keyThemeColor, color.toARGB32());

  // User profile
  String? get userFirstName => _prefs.getString(_keyUserFirstName);
  Future<void> setUserFirstName(String name) =>
      _prefs.setString(_keyUserFirstName, name);

  String? get userLastName => _prefs.getString(_keyUserLastName);
  Future<void> setUserLastName(String name) =>
      _prefs.setString(_keyUserLastName, name);

  String? get userProfilePic => _prefs.getString(_keyUserProfilePic);
  Future<void> setUserProfilePic(String path) =>
      _prefs.setString(_keyUserProfilePic, path);

  bool get userSetupDone => _prefs.getBool(_keyUserSetupDone) ?? false;
  Future<void> setUserSetupDone(bool done) =>
      _prefs.setBool(_keyUserSetupDone, done);

  // Download settings
  bool get autoDownload => _prefs.getBool(_keyAutoDownload) ?? true;
  Future<void> setAutoDownload(bool v) => _prefs.setBool(_keyAutoDownload, v);

  bool get embedSubs => _prefs.getBool(_keyEmbedSubs) ?? true;
  Future<void> setEmbedSubs(bool v) => _prefs.setBool(_keyEmbedSubs, v);

  bool get saveThumbnail => _prefs.getBool(_keySaveThumbnail) ?? true;
  Future<void> setSaveThumbnail(bool v) => _prefs.setBool(_keySaveThumbnail, v);

  bool get addChapters => _prefs.getBool(_keyAddChapters) ?? false;
  Future<void> setAddChapters(bool v) => _prefs.setBool(_keyAddChapters, v);

  bool get autoUpdateYtDlp => _prefs.getBool(_keyAutoUpdateYtDlp) ?? true;
  Future<void> setAutoUpdateYtDlp(bool v) =>
      _prefs.setBool(_keyAutoUpdateYtDlp, v);

  bool get notifications => _prefs.getBool(_keyNotifications) ?? true;
  Future<void> setNotifications(bool v) => _prefs.setBool(_keyNotifications, v);

  bool get soundEffects => _prefs.getBool(_keySoundEffects) ?? false;
  Future<void> setSoundEffects(bool v) => _prefs.setBool(_keySoundEffects, v);

  // Video defaults
  String get defaultQuality => _prefs.getString(_keyDefaultQuality) ?? '1080p';
  Future<void> setDefaultQuality(String v) =>
      _prefs.setString(_keyDefaultQuality, v);

  String get defaultFormat => _prefs.getString(_keyDefaultFormat) ?? 'MP4';
  Future<void> setDefaultFormat(String v) =>
      _prefs.setString(_keyDefaultFormat, v);

  // Audio defaults
  String get defaultAudioFormat =>
      _prefs.getString(_keyDefaultAudioFormat) ?? 'MP3';
  Future<void> setDefaultAudioFormat(String v) =>
      _prefs.setString(_keyDefaultAudioFormat, v);

  String get audioBitrate => _prefs.getString(_keyAudioBitrate) ?? '320 kbps';
  Future<void> setAudioBitrate(String v) =>
      _prefs.setString(_keyAudioBitrate, v);

  // Concurrent / limit
  int get concurrentDownloads =>
      _prefs.getInt(_keyConcurrentDownloads) ?? 4;
  Future<void> setConcurrentDownloads(int v) =>
      _prefs.setInt(_keyConcurrentDownloads, v);

  int get maxDownloadLimit =>
      _prefs.getInt(_keyMaxDownloadLimit) ?? 1000;
  Future<void> setMaxDownloadLimit(int v) =>
      _prefs.setInt(_keyMaxDownloadLimit, v);
}
