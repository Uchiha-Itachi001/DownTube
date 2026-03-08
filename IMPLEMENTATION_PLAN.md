# DownTube — Full Implementation Plan

> **Stack:** Flutter (Windows-first) · `yt-dlp` subprocess · `shared_preferences` · `path_provider` · `file_picker`  
> **Design language:** Dark terminal aesthetic — `AppColors`, `AppTextStyles` (Syne · Outfit · Space Grotesk · JetBrains Mono), green accent `#22C55E`

---

## Table of Contents

1. [Phase 0 — App Startup & Bootstrapping](#phase-0)
2. [Phase 1 — yt-dlp Dependency Check](#phase-1)
3. [Phase 2 — Download Location Setup (First-Run Dialog)](#phase-2)
4. [Phase 3 — URL Input & Video Fetch Flow](#phase-3)
5. [Phase 4 — Skeleton Loaders (Notification + Analyzed Screen)](#phase-4)
6. [Phase 5 — Download Execution](#phase-5)
7. [Phase 6 — State Management Architecture](#phase-6)
8. [Phase 7 — UI Refinements Already Applied](#phase-7)
9. [New Files to Create](#new-files)
10. [Packages to Add](#packages)

---

<a name="phase-0"></a>
## Phase 0 — App Startup & Bootstrapping

### Goal
Replace the plain `AppShell` cold-start with a proper splash/init sequence that:
1. Shows an **animated loading screen** while async checks run
2. Checks yt-dlp installation
3. Checks saved download path
4. Only then lands on the main shell

### Implementation

#### `lib/startup/startup_controller.dart` (new)
```dart
enum StartupStep { ytDlpCheck, locationCheck, done, error }

class StartupController extends ChangeNotifier {
  StartupStep step = StartupStep.ytDlpCheck;
  String? errorMessage;

  Future<void> run() async { ... }
}
```

#### `lib/startup/splash_screen.dart` (new)
- Full-screen dark background matching `AppColors.bg`
- App logo centred with `AppTextStyles.syne` — large, weight 800
- Animated green pulse ring around the logo (using `AnimationController`)
- Progress label below: e.g. `"Checking yt-dlp..."` using `AppTextStyles.mono`
- Transitions:
  - yt-dlp missing → inline error card + install prompt
  - location not set → slides into the **First-Run Location Dialog**
  - all ok → `Navigator.pushReplacement → AppShell`

#### `lib/main.dart` changes
```dart
// Before runApp, run startup checks via StartupController
home: const SplashScreen(),  // ← was AppShell
```

### Splash Animation Detail
| Element | Behaviour |
|---|---|
| Logo word-mark | Fade-in slide-up, 600 ms |
| Green ring | Radial expand + fade, loops while checking |
| Step label | Cross-fades between step descriptions |
| Error state | Ring turns red, error message slides up |

---

<a name="phase-1"></a>
## Phase 1 — yt-dlp Dependency Check

### Goal
Detect whether `yt-dlp.exe` (Windows) is available at startup. If not, guide the user to install it without leaving the app.

### Implementation

#### `lib/services/ytdlp_service.dart` (new)
```dart
class YtDlpService {
  // Returns null if not found, or the resolved path string
  static Future<String?> detectPath() async { ... }

  // Run: yt-dlp --version  → returns version string or throws
  static Future<String> getVersion(String path) async { ... }

  // Fetch video metadata as JSON  (yt-dlp --dump-json <url>)
  static Future<Map<String, dynamic>> fetchMetadata(String url) async { ... }

  // Download with progress callback
  static Future<void> download({
    required String url,
    required String outputPath,
    required String format,
    required String quality,
    required void Function(double progress, String speed, String eta) onProgress,
    required void Function() onDone,
    required void Function(String error) onError,
  }) async { ... }
}
```

**Detection logic (priority order):**
1. Check `shared_preferences` key `ytdlp_path`
2. Check `%APPDATA%\DownTube\yt-dlp.exe`
3. Check `PATH` via `where yt-dlp`
4. Prompt user

#### Startup Check Flow
```
detectPath()
  ├── found → verify with --version
  │     ├── ok  → continue to Phase 2
  │     └── bad → show error "yt-dlp found but not working"
  └── not found → show "yt-dlp not installed" dialog
        ├── [Download yt-dlp] → open releases URL in browser
        └── [Locate manually] → FilePicker → validate → save to prefs
```

#### "yt-dlp Not Found" Dialog Design
- Uses `showDialog` with a custom `Dialog` widget styled with `AppColors.surface1` background
- Title: `AppTextStyles.spaceGrotesk` — `"yt-dlp Required"`
- Body: explains yt-dlp is the download engine
- Two action buttons: `[Download yt-dlp]` (primary green) · `[Locate File]` (ghost)
- Shows detected version string after successful validation: `JetBrains Mono`, green, `"v2024.xx.xx ✓"`

---

<a name="phase-2"></a>
## Phase 2 — Download Location Setup (First-Run Dialog)

### Goal
On first launch (or when no path is stored), show a **full-screen overlay dialog** prompting the user to pick a download folder. Store persistently so it never shows again unless the user resets it from Settings.

### Storage Key
```
shared_preferences key: "download_path"
```

### Implementation

#### `lib/startup/location_setup_dialog.dart` (new)
A modal dialog (not a route, but a full-overlay `Stack` child on `AppShell`) containing:

```
┌──────────────────────────────────────────────────────┐
│  [Icon: folder_open]                                 │
│  Set Your Download Folder          [SpaceGrotesk 18] │
│  Choose where DownTube saves files [Outfit muted]    │
│                                                       │
│  ┌──────────────────────────────────────┐  [Browse]  │
│  │  D:\Downloads\DownTube               │            │
│  └──────────────────────────────────────┘            │
│                                                       │
│  ☑  Create folder if it doesn't exist               │
│                                                       │
│              [Confirm & Continue ▶]                  │
└──────────────────────────────────────────────────────┘
```

- Background: `AppColors.bg` with a semi-transparent overlay blur (`BackdropFilter`)
- Path text field styled with `AppColors.surface2` border, `JetBrains Mono` font
- Uses `file_picker` package (`FilePicker.platform.getDirectoryPath()`)
- On confirm: saves path to `shared_preferences` → dismiss overlay → show main shell

#### `lib/services/prefs_service.dart` (new)
```dart
class PrefsService {
  static Future<void> setDownloadPath(String path) async { ... }
  static Future<String?> getDownloadPath() async { ... }
  static Future<void> setYtDlpPath(String path) async { ... }
  static Future<String?> getYtDlpPath() async { ... }
  static Future<bool> isFirstRun() async { ... }
  static Future<void> markFirstRunComplete() async { ... }
}
```

#### Settings Screen Integration
The existing `SettingsScreen` already has a `_savePath` field. Wire it to `PrefsService`:
- On change → call `PrefsService.setDownloadPath()`
- On init → load from `PrefsService.getDownloadPath()`
- Add a `[Reset to Default]` button that clears the pref and re-triggers the location dialog

---

<a name="phase-3"></a>
## Phase 3 — URL Input & Video Fetch Flow

### Goal
When the user pastes a URL and taps **Analyze** in `DashboardScreen`, the app:
1. Validates the URL format
2. Shows a **skeleton loader** in `AnalyzedScreen`
3. Runs `yt-dlp --dump-json <url>` via `YtDlpService`
4. Populates `AnalyzedScreen` with real data
5. Shows an `AppNotificationCard` (success / error)

### Data Model

#### `lib/models/video_info.dart` (new)
```dart
class VideoInfo {
  final String id;
  final String title;
  final String uploader;       // channel name
  final String uploaderUrl;
  final int subscriberCount;
  final String thumbnailUrl;
  final int durationSeconds;
  final String uploadDate;     // "20241201" → formatted
  final int viewCount;
  final double likeRatio;      // likes / (likes+dislikes) * 100
  final List<FormatInfo> formats;
  final List<String> availableSubtitleLangs;
  final bool hasHdr;
  final String webpage_url;

  factory VideoInfo.fromYtDlpJson(Map<String, dynamic> json) { ... }
}

class FormatInfo {
  final String formatId;
  final String ext;
  final int? height;       // null for audio-only
  final int? abr;          // audio bitrate kbps
  final String? vcodec;
  final String? acodec;
  final int? filesize;     // bytes, may be null (estimated)
  final bool hasHdr;
}
```

### State Flow

```
UrlInputBar.onAnalyze(url)
  → AppShell._goToAnalyzed()        ← already wired
  → AnalyzedScreen enters loading state (isLoading = true)
  → YtDlpService.fetchMetadata(url)
       ├── success → VideoInfo.fromYtDlpJson()
       │     → setState(isLoading: false, videoInfo: info)
       │     → AppNotificationCard(type: success, "Ready to download")
       └── error  → setState(isLoading: false, error: msg)
             → AppNotificationCard(type: error, msg)
```

#### `AnalyzedScreen` state additions
```dart
bool _isLoading = false;
VideoInfo? _videoInfo;
String? _fetchError;
```

The `AnalyzedScreen` widget needs:
- `final String? initialUrl;` passed from `AppShell._goToAnalyzed(url)`
- `initState()` triggers the fetch when `initialUrl != null`

#### `AppShell` change
```dart
void _goToAnalyzed(String url) =>
    setState(() { _selectedIndex = 5; _pendingUrl = url; });

// Pass _pendingUrl to AnalyzedScreen
case 5: return AnalyzedScreen(initialUrl: _pendingUrl, onDownload: ...);
```

---

<a name="phase-4"></a>
## Phase 4 — Skeleton Loaders

### Design Principle
Skeletons must match the **exact layout** of the real content — same dimensions, same border-radius. They use an animated shimmer gradient that sweeps left-to-right, using the existing green accent.

### Shimmer Helper

#### `lib/widgets/shimmer_box.dart` (new)
```dart
/// A single shimmering placeholder block.
/// Uses AnimationController to sweep a gradient across the container.
class ShimmerBox extends StatefulWidget {
  final double width;
  final double? height;
  final double borderRadius;
  final Color baseColor;
  final Color shimmerColor;
  ...
}
```
- `baseColor`: `AppColors.surface2`
- `shimmerColor`: `AppColors.green.withOpacity(0.08)`
- Animation: `LinearGradient` sweep over 1.4 seconds, infinite loop

---

### 4A — AnalyzedScreen Skeleton

When `_isLoading == true`, `_buildVideoHeader()` renders **skeleton version**:

```
┌────────────────────────────────────────────┐
│  [16:9 shimmer block — thumbnail area]     │  ← AspectRatio(16/9) shimmer
│────────────────────────────────────────────│
│  [shimmer w:80 h:18 — badge]               │
│  [shimmer w:full h:15 — title line 1]      │
│  [shimmer w:70% h:15 — title line 2]       │
│  ── channel row ──                         │
│  [circle 26] [shimmer w:100 h:10]          │
│              [shimmer w:70  h:8]           │
│  ── meta chips ──                          │
│  [shimmer w:70 h:20] × 4                   │
└────────────────────────────────────────────┘
```

Quality card row skeleton (when loading):
```
[shimmer full-width tile] × 5 (video) or × 3 (audio)
```
Each tile: same `borderRadius: 12`, height of real tile.

**Implementation:** Add `_buildVideoHeaderSkeleton()` and `_buildQualityRowSkeleton()` methods to `_AnalyzedScreenState`. Switch in `build()`:
```dart
Widget build(BuildContext context) {
  return SingleChildScrollView(
    child: Column(children: [
      _isLoading ? _buildVideoHeaderSkeleton() : _buildVideoHeader(),
      const SizedBox(height: AppColors.gap),
      _isLoading ? _buildConfigCardSkeleton() : _buildConfigCard(),
      if (!_isLoading) ...[
        const SizedBox(height: AppColors.gap),
        _buildActionBar(),
      ],
    ]),
  );
}
```

---

### 4B — AppNotificationCard Skeleton / Loading State

The existing `NotificationType.loading` case already has a `hourglass_top_rounded` icon. Enhancements:

1. **Animated icon** — replace static icon with a `RotationTransition` spinner on loading type
2. **Progress text** — accept optional `subtitle` parameter:
   ```dart
   const AppNotificationCard(
     type: NotificationType.loading,
     message: 'Fetching video info...',
     subtitle: 'Running yt-dlp --dump-json',   // ← new optional param
   )
   ```
3. **Inline skeleton variant** — when shown in the notification position, display two shimmer lines instead of static text while fetching

#### Notification Display in AppShell
Add a `_notification` field to `_AppShellState`:
```dart
AppNotificationData? _notification;
void _showNotification(AppNotificationData n) =>
    setState(() => _notification = n);
```
Pass `_showNotification` down through the widget tree so `AnalyzedScreen` and `YtDlpService` callbacks can trigger it.

The `AppHeader` widget already has the notification slot — wire `_notification` to it.

---

<a name="phase-5"></a>
## Phase 5 — Download Execution

### Flow
```
[Download Now] button
  → YtDlpService.download(url, path, format, quality, callbacks)
  → DownloadsScreen entry added (pending → active)
  → AppNotificationCard(loading, "Downloading 1080p MP4...")
  → Real-time progress via stdout parsing
  → On complete: AppNotificationCard(success, "Download complete")
  → DownloadItem status = done
```

### Progress Parsing
`yt-dlp` stdout format:
```
[download]  34.2% of  450.23MiB at  3.12MiB/s ETA 01:23
```
Parse with regex:
```dart
final _progressRe = RegExp(
  r'\[download\]\s+([\d.]+)%.*?at\s+([\d.]+\w+/s).*?ETA\s+(\d+:\d+)',
);
```
Emit `(progress: 0.342, speed: "3.12MiB/s", eta: "01:23")` to the `onProgress` callback.

### `lib/models/download_item.dart` (new)
```dart
enum DownloadStatus { queued, active, paused, done, failed }

class DownloadItem {
  final String id;          // uuid
  final String title;
  final String url;
  final String quality;
  final String format;
  final String outputPath;
  final String thumbnailUrl;
  DownloadStatus status;
  double progress;          // 0.0–1.0
  String speed;
  String eta;
  String? errorMessage;
  DateTime startedAt;
}
```

---

<a name="phase-6"></a>
## Phase 6 — State Management Architecture

### Chosen Approach: `ChangeNotifier` + `ListenableBuilder`
Keeps the existing widget structure (no Riverpod or Bloc needed at this stage), aligns with already used `setState` pattern, and is easy to extend.

### Providers

#### `lib/providers/app_state.dart` (new)
```dart
class AppState extends ChangeNotifier {
  // ── Startup
  bool ytDlpReady = false;
  String? ytDlpVersion;
  String? downloadPath;

  // ── Current analysis
  bool isFetching = false;
  VideoInfo? currentVideo;
  String? fetchError;

  // ── Downloads
  final List<DownloadItem> downloads = [];
  void addDownload(DownloadItem item) { ... }
  void updateDownload(String id, {double? progress, DownloadStatus? status, String? speed, String? eta}) { ... }

  // ── Notifications
  _NotificationData? activeNotification;
  void showNotification(_NotificationData n) { ... }
  void clearNotification() { ... }

  // ── Services
  late final YtDlpService ytDlp;
  late final PrefsService prefs;
}
```

Inject at app root via `ListenableProvider`/`ChangeNotifierProvider` or simply pass as a constructor argument through `AppShell`.

---

<a name="phase-7"></a>
## Phase 7 — UI Refinements Already Applied

These changes are **already committed** to the codebase:

| File | Change |
|---|---|
| `lib/core/app_text_styles.dart` | Added `spaceGrotesk()` and `mono()` (JetBrains Mono) font helpers |
| `lib/screens/analyzed_screen.dart` | Thumbnail changed from side-strip (210px wide) to **full-width 16:9 banner** at top of header card |
| `lib/screens/analyzed_screen.dart` | Thumbnail overlays redesigned: quality badge `"4K · HDR"` (SpaceGrotesk), duration (Mono), YouTube badge — all positioned correctly for the wider banner |
| `lib/screens/analyzed_screen.dart` | Video title now uses `AppTextStyles.spaceGrotesk` (was Syne) |
| `lib/screens/analyzed_screen.dart` | `_QualityTile` resolution number → `spaceGrotesk(18, w700)` |
| `lib/screens/analyzed_screen.dart` | `_QualityTile` file size → `mono(9, w600)` with bordered chip |
| `lib/screens/analyzed_screen.dart` | `_QualityTile` border-radius bumped to 12, dual-layer glow on selected |
| `lib/screens/analyzed_screen.dart` | Removed `_platformBadge()` (moved inline to thumbnail overlay) |

---

<a name="new-files"></a>
## New Files to Create

```
lib/
├── startup/
│   ├── splash_screen.dart          Phase 0 — animated boot screen
│   ├── startup_controller.dart     Phase 0 — async init logic
│   └── location_setup_dialog.dart  Phase 2 — first-run folder picker
├── services/
│   ├── ytdlp_service.dart          Phase 1 — yt-dlp subprocess wrapper
│   └── prefs_service.dart          Phase 2 — shared_preferences helpers
├── models/
│   ├── video_info.dart             Phase 3 — parsed metadata model
│   └── download_item.dart          Phase 5 — download queue model
├── providers/
│   └── app_state.dart              Phase 6 — global ChangeNotifier
└── widgets/
    └── shimmer_box.dart            Phase 4 — animated skeleton block
```

---

<a name="packages"></a>
## Packages to Add to `pubspec.yaml`

```yaml
dependencies:
  shared_preferences: ^2.3.2   # persist download path, yt-dlp path, first-run flag
  path_provider: ^2.1.4        # default app data directory for yt-dlp storage
  uuid: ^4.5.1                 # generate download item IDs
  url_launcher: ^6.3.1         # open yt-dlp GitHub releases page
  # file_picker already present (^6.1.7)
  # window_manager already present (^0.4.3)
  # google_fonts already present (^6.2.1)
```

Run after adding:
```powershell
flutter pub get
```

---

## Implementation Sequence (Recommended Order)

```
[1] Add packages → flutter pub get
[2] PrefsService + basic tests
[3] YtDlpService.detectPath() + .getVersion()
[4] SplashScreen + StartupController (yt-dlp check only)
[5] LocationSetupDialog + PrefsService.setDownloadPath()
[6] Wire splash → location dialog → AppShell
[7] VideoInfo model + YtDlpService.fetchMetadata()
[8] ShimmerBox widget
[9] AnalyzedScreen skeleton loaders (header + quality row)
[10] AppNotificationCard loading state + subtitle param
[11] AppState ChangeNotifier
[12] Wire URL fetch end-to-end (Dashboard → Analyzed)
[13] YtDlpService.download() + progress parsing
[14] DownloadItem model + DownloadsScreen live updates
[15] Settings screen ↔ PrefsService wiring
```

---

*Last updated: 2026-03-08*
