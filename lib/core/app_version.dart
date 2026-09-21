/// Single source of truth for the DownTube app version.
///
/// Change ONLY this file when releasing a new version.
/// Every screen, dialog, and service reads from here — nothing is hardcoded elsewhere.
///
/// Also update [pubspec.yaml] version field to match (Flutter uses it for the
/// executable metadata, but it is not read at runtime on Windows).
library;

class AppVersion {
  AppVersion._();

  /// Current installed version — update this for every release.
  static const String current = '2.7.2';

  /// Display string shown in UI (e.g. settings screen subtitle).
  static const String display = 'v$current';

  /// Full subtitle shown under the app name.
  static const String subtitle = '$display · Open Source Video Downloader';

  /// Name of the installer asset in the GitHub release.
  /// Must match exactly what you name the file when you publish the release.
  static const String installerAssetName = 'DownTube.exe';
}
