import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static const _keyDownloadPath = 'download_path';
  static const _keyYtDlpPath = 'ytdlp_path';

  final SharedPreferences _prefs;
  PrefsService._(this._prefs);

  static Future<PrefsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PrefsService._(prefs);
  }

  String? get downloadPath => _prefs.getString(_keyDownloadPath);

  Future<void> setDownloadPath(String path) =>
      _prefs.setString(_keyDownloadPath, path);

  Future<void> clearDownloadPath() => _prefs.remove(_keyDownloadPath);

  String? get ytDlpPath => _prefs.getString(_keyYtDlpPath);

  Future<void> setYtDlpPath(String path) =>
      _prefs.setString(_keyYtDlpPath, path);
}
