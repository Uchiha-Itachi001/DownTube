<div align="center">

# DownTube

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows&logoColor=white)](https://microsoft.com/windows)
[![yt-dlp](https://img.shields.io/badge/Powered%20by-yt--dlp-FF0000?logo=youtube&logoColor=white)](https://github.com/yt-dlp/yt-dlp)
[![License](https://img.shields.io/badge/License-Source%20Available-orange)](./LICENSE)
[![Author](https://img.shields.io/badge/Author-Pankaj%20Roy-6e40c9?logo=github&logoColor=white)](https://github.com/Uchiha-Itachi001)

*A polished Windows desktop app for downloading videos and audio from 1000+ platforms.*

</div>

---

## What is DownTube?

DownTube is a native **Windows desktop application** that wraps [yt-dlp](https://github.com/yt-dlp/yt-dlp) with a clean, modern Flutter UI. Paste any URL, pick your quality, and download — individually or as an entire playlist. It handles queue management, format conversion, download history, and local library organisation, all from a single, keyboard-friendly interface.

---

## Features

<table>
<tr>
<td width="50%">

**Video Downloads**
- Individual videos and full playlists
- Quality tiers: Best, 4K, 1440p, 1080p, 720p, 480p, 360p
- Container formats: MP4, MKV, WEBM

**Audio Extraction**
- Rip audio from any supported URL
- Formats: MP3, M4A, FLAC, WAV, OGG
- Global or per-item audio mode in playlists

**Playlist Management**
- Entries stream in progressively — no waiting for full fetch
- Per-video quality override in the right panel
- Estimated total download size shown in real time
- Batch download or queue all selected entries

</td>
<td width="50%">

**Download Queue**
- Configurable concurrent download limit
- Pause, resume, and cancel at any time
- Live progress: speed, ETA, and phase (video / audio / merge)
- Per-item speed sparkline chart

**Library & History**
- Persistent history backed by SQLite
- Card-based library view with quick re-download
- Automatic index suffix prevents filename conflicts

**Application**
- Custom accent colour, persists across sessions
- Developer profile screen with contribution graph
- Auto-detects yt-dlp from PATH or `%APPDATA%\DownTube`
- In-app yt-dlp update
- Windows installer via Inno Setup

</td>
</tr>
</table>

---

## Tech Stack

<table>
<tr><th>Layer</th><th>Technology</th><th>Purpose</th></tr>
<tr><td>UI framework</td><td><a href="https://flutter.dev">Flutter 3</a> (Windows desktop)</td><td>Rendering and navigation</td></tr>
<tr><td>Download engine</td><td><a href="https://github.com/yt-dlp/yt-dlp">yt-dlp</a></td><td>Video / audio extraction</td></tr>
<tr><td>Local database</td><td>sqflite_common_ffi (SQLite)</td><td>Download history persistence</td></tr>
<tr><td>Window management</td><td>window_manager</td><td>Title bar, sizing, centering</td></tr>
<tr><td>Preferences</td><td>shared_preferences</td><td>Settings persistence</td></tr>
<tr><td>File picking</td><td>file_picker</td><td>Output folder selection</td></tr>
<tr><td>Fonts</td><td>Outfit · Syne · JetBrains Mono</td><td>UI typography</td></tr>
<tr><td>Notifications</td><td>local_notifier</td><td>System tray alerts</td></tr>
<tr><td>Icons</td><td>font_awesome_flutter · flutter_launcher_icons</td><td>UI icons and app icon</td></tr>
</table>

---

## Prerequisites

| Requirement | Version / Notes |
|---|---|
| [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) | 3.7 or later |
| Windows | 10 or later (64-bit) |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp/releases) | On system PATH **or** `%APPDATA%\DownTube\yt-dlp.exe` |
| [ffmpeg](https://ffmpeg.org/download.html) | On system PATH (required for format merging & audio extraction) |

> Dart SDK is bundled with Flutter — no separate installation needed.

---

## Getting Started

```bash
# 1. Clone
git clone https://github.com/Uchiha-Itachi001/DownTube.git
cd DownTube

# 2. Install dependencies
flutter pub get

# 3. Run on Windows
flutter run -d windows
```

---

## Configuration

**yt-dlp detection order**

1. Path saved in application preferences
2. `%APPDATA%\DownTube\yt-dlp.exe`
3. System `PATH`

If yt-dlp is missing on startup, a setup prompt appears with an option to provide a custom path.

**Settings available in-app**

| Setting | Description |
|---|---|
| Download folder | Default output directory, set on first launch or changed any time in Settings |
| Concurrent downloads | How many downloads run in parallel |
| Accent colour | Fully customisable, persists across sessions |
| Audio bitrate | 128 / 192 / 256 / 320 kbps |

---

## Usage

**Single video**

1. Paste a video URL into the input bar on the Dashboard.
2. Click **Analyze** — metadata loads in seconds.
3. Choose a quality tier and container format.
4. Click **Download** to start immediately, or **Add to Queue**.

**Playlist**

1. Paste a playlist URL and click **Analyze**. Entries appear as they stream in.
2. In the left panel, switch between **Video** mode and **Audio** mode.
3. Adjust global quality / format, or override per entry in the right panel.
4. Use checkboxes to include / exclude specific videos.
5. Click **Download All** or **Queue All** for the selected entries.

**Download management**

Open the **Downloads** screen to see live progress for each item — speed graph, ETA, and the current phase (fetching video, audio, or merging). Downloads can be paused, resumed, or cancelled at any time.

---

## Project Structure

```
lib/
├── core/           # Theme colours and text style definitions
├── models/         # DownloadItem · VideoInfo · PlaylistInfo · PlaylistEntry
├── providers/      # AppState (ChangeNotifier) — central application state
├── screens/        # Dashboard · Analyzed · Playlist · Downloads · Library · History · Settings
├── services/       # YtDlpService · DownloadDb · PrefsService · NotificationService
├── shell/          # AppShell — main navigation scaffold with sidebar
├── startup/        # SplashScreen and StartupController (init sequence)
├── widgets/        # AppHeader · DownloadItemTile · LibraryCard · SparklineChart · …
├── developer_screen.dart
└── main.dart
assetes/
├── images/         # App images (developer profile)
└── icon/           # Launcher icon source
installers/
└── Myexe.iss       # Inno Setup script for Windows installer
```

---

## Build & Distribution

```bash
# Release build
flutter build windows --release
# Output: build\windows\x64\runner\Release\
```

**Installer** — open `installers\Myexe.iss` in [Inno Setup](https://jrsoftware.org/isinfo.php) and compile to produce a standalone `.exe` installer.

**Launcher icons** — regenerate after changing the source icon:

```bash
dart run flutter_launcher_icons
```

---

## License

This project is released under a **source-available, view-only license**.  
You may read and study the code, but you may not copy, modify, distribute, or use it in any product. See [LICENSE](./LICENSE) for the full terms.

© 2025 Pankaj Roy ([Uchiha-Itachi001](https://github.com/Uchiha-Itachi001)). All rights reserved.
