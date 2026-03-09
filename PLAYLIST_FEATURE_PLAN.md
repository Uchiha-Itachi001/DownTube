# Playlist Download Feature — Implementation Plan

## Overview

When a user enters a YouTube playlist URL (or any playlist-type URL supported by yt-dlp), the app detects it, fetches playlist metadata, and presents a dedicated **Playlist Analyzed Screen** instead of the single-video screen. Each video in the playlist gets its own quality selector and individual download button, plus a **Download All** action at the top.

---

## 1. URL Detection Flow

```
User types URL in UrlInputBar
          │
          ▼
   _triggerAnalyze(url)
          │
          ▼
  ┌───────────────────────────────────────────┐
  │  AppState.fetchVideoInfo(url)             │
  │                                           │
  │  Run: yt-dlp --flat-playlist -J <url>     │
  │                                           │
  │  Parse top-level JSON:                    │
  │    "_type" == "playlist"  ──▶ PLAYLIST    │
  │    "_type" == "video"     ──▶ SINGLE      │
  │    "_type" absent / other ──▶ SINGLE      │
  └───────────────────────────────────────────┘
          │                       │
          ▼                       ▼
  PlaylistAnalyzedScreen    AnalyzedScreen
  (new — this plan)         (existing)
```

---

## 2. Data Models

### 2a. `PlaylistEntry` (new — `lib/models/playlist_entry.dart`)

```
PlaylistEntry
├── id            : String          — yt-dlp video id
├── title         : String
├── url           : String          — full watch URL
├── thumbnail     : String?
├── duration      : int?            — seconds
├── channelName   : String?
├── uploaderUrl   : String?
├── index         : int             — position in playlist (1-based)
└── isAvailable   : bool            — false if private/deleted
```

### 2b. `PlaylistInfo` (new — `lib/models/playlist_info.dart`)

```
PlaylistInfo
├── id            : String          — playlist id
├── title         : String
├── description   : String?
├── thumbnail     : String?         — first video thumb fallback
├── channelName   : String?
├── channelUrl    : String?
├── viewCount     : int?
├── modifiedDate  : String?
├── entryCount    : int             — total videos
├── entries       : List<PlaylistEntry>
└── webpageUrl    : String
```

### 2c. `PlaylistFetchState` (new enum in `app_state.dart`)

```
enum PlaylistFetchState { idle, loading, success, error }
```

---

## 3. yt-dlp Commands

### Step 1 — Flat fetch (fast, no format data)
```
yt-dlp --flat-playlist -J <playlist_url>
```
Produces `_type: "playlist"` JSON with `entries[]` containing id, title, url, duration, thumbnail.  
**Used for**: initial display, building the list fast.

### Step 2 — Per-entry format fetch (on demand, when user expands a row)
```
yt-dlp -J <video_url>
```
Produces full `VideoInfo` with available resolutions.  
**Used for**: populating the quality selector for that individual row.

### Step 3 — Download individual
```
yt-dlp -f <format_selector> -o <output_template> <video_url>
```

### Step 4 — Download all (sequential queue)
Calls `AppState.enqueueDownload()` for every selected entry in order.

---

## 4. AppState Changes (`lib/providers/app_state.dart`)

```
AppState
├── (existing) fetchState : FetchState
├── (existing) videoInfo  : VideoInfo?
│
├── NEW: playlistFetchState : PlaylistFetchState   default: idle
├── NEW: playlistInfo       : PlaylistInfo?
├── NEW: isPlaylist         : bool                 derived from playlistInfo != null
│
├── NEW: fetchPlaylist(url) → void
│         Runs yt-dlp --flat-playlist -J
│         Sets playlistFetchState: loading → success/error
│         Populates playlistInfo
│
└── NEW: resetPlaylist() → void
          Clears playlistInfo, resets playlistFetchState to idle
```

**`fetchVideoInfo(url)` — updated logic:**
```
fetchVideoInfo(url):
  1. Run: yt-dlp --flat-playlist -J <url>   [with 10s timeout for detection]
  2. If JSON._type == "playlist":
       call fetchPlaylist(url)              → navigates to PlaylistAnalyzedScreen
  3. Else:
       continue existing single-video flow  → navigates to AnalyzedScreen
```

---

## 5. Navigation Changes (`lib/shell/app_shell.dart`)

```
AppShell
├── _selectedIndex  (existing)
├── _pendingUrl     (existing)
│
├── NEW: _isPlaylist : bool   — set when detection returns playlist type
│
├── _buildNonAnalyzeScreen():
│     case 5:  if _isPlaylist
│                → PlaylistAnalyzedScreen(url: _pendingUrl, onQueue, onDownloadAll, ...)
│              else
│                → AnalyzedScreen(url: _pendingUrl, onDownload, onQueue)
│
└── _goToAnalyzed(url):
      resetFetch()
      resetPlaylist()
      _pendingUrl = url
      _isPlaylist = false     ← reset flag; screen routing updates once type detected
      _selectedIndex = 5
```

---

## 6. Playlist Analyzed Screen Layout

File: `lib/screens/playlist_analyzed_screen.dart`

The screen uses a **two-column Row** layout identical in spirit to YouTube's own playlist page:
- **Left panel** — fixed width (~300 dp), full height, not scrollable. Contains playlist identity, global settings, and the primary action buttons.
- **Right panel** — fills remaining width, fully scrollable vertical list of videos.

```
┌──────────────────────────────────┬──────────────────────────────────────────────────────┐
│  LEFT PANEL  (fixed ~300 dp)     │  RIGHT PANEL  (scrollable)                           │
│  ─────────────────────────────── │  ────────────────────────────────────────────────── │
│                                  │                                                      │
│  ┌────────────────────────────┐  │  FILTER / SORT BAR                                   │
│  │                            │  │  ┌──────────────────────────────────────────────┐   │
│  │   Playlist Thumbnail       │  │  │ ☑ Select All  [47/47]   Sort: [Index▼]       │   │
│  │   full width, 16:9         │  │  └──────────────────────────────────────────────┘   │
│  │   rounded corners          │  │                                                      │
│  └────────────────────────────┘  │  VIDEO ROW 1                                         │
│                                  │  ┌──────────────────────────────────────────────┐   │
│  Playlist Title                  │  │ ☑  1  ┌─────────┐  Title of Video One        │   │
│  (bold, 18pt, max 2 lines)       │  │       │  thumb  │  Channel Name              │   │
│                                  │  │       │ 120×68  │  01:42          1080p▼  ⬇  │   │
│  Channel Name  ·  47 videos      │  │       └─────────┘                            │   │
│  Total: 3h 22m                   │  └──────────────────────────────────────────────┘   │
│  Updated: 7 days ago             │                                                      │
│                                  │  VIDEO ROW 2                                         │
│  ─────────────────────────────── │  ┌──────────────────────────────────────────────┐   │
│                                  │  │ ☑  2  ┌─────────┐  Title of Video Two        │   │
│  SETTINGS                        │  │       │  thumb  │  Channel Name              │   │
│  ┌────────────────────────────┐  │  │       │ 120×68  │  05:18          720p▼   ⬇  │   │
│  │ QUALITY  [1080p ▼]         │  │  │       └─────────┘                            │   │
│  │ FORMAT   [MP4   ▼]         │  │  └──────────────────────────────────────────────┘   │
│  │ OUTPUT   [📁 /Downloads/]  │  │                                                      │
│  └────────────────────────────┘  │  VIDEO ROW 3  (unavailable)                          │
│                                  │  ┌──────────────────────────────────────────────┐   │
│  ─────────────────────────────── │  │ ☐  3  ┌─────────┐  [Private video]           │   │
│                                  │  │  (dim)│  grey   │  --:--       🚫 Unavailable│   │
│  ┌────────────────────────────┐  │  │       └─────────┘                            │   │
│  │  ⬇  DOWNLOAD ALL (47)  🟢  │  │  └──────────────────────────────────────────────┘   │
│  │  ────────────────────────  │  │                                                      │
│  │  ⬇  Queue All  (ghost btn) │  │  VIDEO ROW 4                                         │
│  └────────────────────────────┘  │  ┌──────────────────────────────────────────────┐   │
│                                  │  │ ☑  4  ┌─────────┐  Title of Video Four       │   │
│  [🔗 Copy playlist URL]          │  │       │  thumb  │  Channel Name              │   │
│                                  │  │       │ 120×68  │  12:07          1080p▼  ⬇  │   │
└──────────────────────────────────┘  │       └─────────┘                            │   │
                                      └──────────────────────────────────────────────┘   │
                                                   ... more rows ...                       │
                                      ────────────────────────────────────────────────── │
```

### Layout Rules

| Property | Value |
|---|---|
| Left panel width | 300 dp fixed, `SizedBox(width: 300)` |
| Left panel scroll | None — fixed, uses `Column` |
| Right panel width | `Expanded` — fills remaining space |
| Right panel scroll | `ListView.builder` — all video rows |
| Separator | 1 dp vertical divider, `AppColors.border` |
| Overall padding | 18 dp outer, 12 dp between columns |
| Row height | 88 dp per video row |
| Thumbnail size | 120×68 (16:9) rounded 6 dp |
| Left panel thumbnail | full panel width, 16:9 aspect ratio, rounded 10 dp |

---

## 7. Screen Sections — Detail

### Left Panel — Section A: Playlist Identity

| Element | Details |
|---|---|
| Thumbnail | Full panel width, 16:9 `AspectRatio`, network image, shimmer placeholder, rounded 10 dp |
| Playlist title | `AppTextStyles.outfit` 18pt bold, max 2 lines, top padding 14 dp |
| Channel name | 13pt muted, `Icons.person_outline` prefix |
| Stats row | `{N} videos · {total duration}` muted 12pt |
| Updated date | `Updated {N} days ago` muted 11pt |

### Left Panel — Section B: Global Settings

| Control | Details |
|---|---|
| Section label | `SETTINGS` uppercase muted 11pt label |
| Quality dropdown | Chip-style selector: `Best / 4K / 1080p / 720p / 480p / 360p / Audio Only`. Applies as **default** to every row that has no per-row override |
| Format dropdown | `MP4 / MKV / WEBM / MP3 / WAV / FLAC` |
| Output folder picker | Full-width ghost button with folder icon + truncated path. Same `file_picker` usage as single-video screen |

### Left Panel — Section C: Action Buttons

| Element | Details |
|---|---|
| **Download All** | Full-width solid green button. Queues all **checked** available entries (uses per-row overrides where set, global quality otherwise). Navigates to **Dashboard** via `onDownloadAll()` |
| **Queue All** | Full-width ghost (bordered) button. Same queuing logic but navigates to **Downloads** via `onQueueAll()` |
| Copy URL chip | Small borderless chip at bottom — `Icons.link` + `Copy URL`. Tapping copies `playlistInfo.webpageUrl` to clipboard + shows snackbar |

### Right Panel — Section D: Filter / Sort Bar

| Element | Details |
|---|---|
| Select All checkbox | `☑ Select All` — checks/unchecks all **available** entries in `_checkedEntries` |
| Selected count | `{selected}/{total} selected` badge, muted 12pt |
| Sort dropdown | `Index (default) / Title A–Z / Duration` — re-orders displayed list only, does not affect download order in queue |

### Right Panel — Section E: Video Rows

Each row (`_PlaylistVideoRow`, height 88 dp) contains:

| Element | Position | Details |
|---|---|---|
| Checkbox | Left edge | Include/exclude from Download All / Queue All |
| Index number | After checkbox | `01`–`999`, muted 12pt monospace |
| Thumbnail | Center-left | 120×68, rounded 6 dp, network image, shimmer placeholder. Duration badge bottom-right |
| Title | Center | `AppTextStyles.outfit` 13pt bold, max 2 lines |
| Channel name | Below title | 11pt muted |
| Quality chip | Right side | Defaults to global setting label. Tapping opens a small popup menu. Lazy-loads formats via `yt-dlp -J <url>` on first open, shows spinner while loading |
| Download button | Right edge | `Icons.download_rounded` icon button — queues this single entry, navigates to Downloads |
| Unavailable state | Full row | Opacity 0.35, thumbnail replaced by grey box, `🚫 Unavailable` text, no checkbox/quality/download controls |

---

## 8. Per-Row Quality Loading Flow

```
User taps quality chip on row N
          │
          ▼
Row state: formatsLoading = true  →  show spinner on chip
          │
          ▼
  yt-dlp -J <entry.url>  (background isolate / process)
          │
          ▼
Parse VideoInfo.formats  →  build quality list
          │
          ▼
Row state: formatsLoaded = true  →  show quality dropdown
          │
          ▼
User selects resolution  →  _rowQualityOverrides[entry.id] = resolution
```

---

## 9. Download All Flow

```
User presses Download All
          │
          ▼
Filter: entries where checkbox == true && isAvailable
          │
          ▼
For each entry (in order):
  resolution = _rowQualityOverrides[entry.id] ?? globalQuality
  format     = globalFormat
  AppState.enqueueDownload(DownloadItem(
    title     : entry.title,
    url       : entry.url,
    resolution: resolution,
    format    : format,
    outputPath: outputPath,
    thumbnail : entry.thumbnail,
    extractor : 'youtube',
    videoDuration: entry.duration,
    downloadIndex: AppState.downloadIndex(entry.url),
  ))
          │
          ▼
widget.onDownloadAll?.call()   →   AppShell._onNavSelected(0)   (Dashboard)
```

---

## 10. Individual Download Flow (per row)

```
User presses ⬇ on row N
          │
          ▼
resolution = _rowQualityOverrides[entry.id] ?? globalQuality
AppState.enqueueDownload(DownloadItem(...entry N data...))
          │
          ▼
widget.onDownloadOne?.call()   →   AppShell._onNavSelected(2)   (Downloads)
```

---

## 11. State Management Inside the Screen

```
PlaylistAnalyzedScreen (StatefulWidget)
│
├── _globalQuality       : String         ('1080p' default)
├── _globalFormat        : String         ('MP4' default)
├── _outputPath          : String?        (null = use AppState.downloadPath)
├── _checkedEntries      : Set<String>    (entry.id values — all checked by default)
├── _rowQualityOverrides : Map<String,String>   (entry.id → resolution)
├── _rowFormatsCache     : Map<String,List<_QOption>>  (lazy-loaded formats per entry)
├── _rowLoadingFormats   : Set<String>    (entry ids currently fetching formats)
│
├── _onSelectAll(bool) → toggles all available entries in _checkedEntries
├── _onToggleRow(id, bool) → add/remove from _checkedEntries
├── _onGlobalQualityChange(res) → updates _globalQuality
├── _onLoadRowFormats(entry) → fetches via yt-dlp -J, caches in _rowFormatsCache
├── _onDownloadAll() → queues all checked, calls widget.onDownloadAll
└── _onDownloadOne(entry) → queues single entry, calls widget.onDownloadOne
```

---

## 12. Callbacks on `PlaylistAnalyzedScreen`

```dart
class PlaylistAnalyzedScreen extends StatefulWidget {
  final String url;
  final VoidCallback? onDownloadAll;   // → navigate to Dashboard (index 0)
  final VoidCallback? onQueueAll;      // → navigate to Downloads (index 2)
  final VoidCallback? onDownloadOne;   // → navigate to Downloads (index 2)
  ...
}
```

Passed from `AppShell`:
```dart
PlaylistAnalyzedScreen(
  url: _pendingUrl!,
  onDownloadAll: () => _onNavSelected(0),   // Dashboard
  onQueueAll:    () => _onNavSelected(2),   // Downloads
  onDownloadOne: () => _onNavSelected(2),   // Downloads
)
```

---

## 13. New Files to Create

| File | Purpose |
|---|---|
| `lib/models/playlist_entry.dart` | `PlaylistEntry` data class |
| `lib/models/playlist_info.dart` | `PlaylistInfo` data class |
| `lib/screens/playlist_analyzed_screen.dart` | Full playlist screen |
| `lib/widgets/playlist_video_row.dart` | Individual video row widget |

---

## 14. Files to Modify

| File | Change |
|---|---|
| `lib/providers/app_state.dart` | Add `playlistFetchState`, `playlistInfo`, `fetchPlaylist()`, `resetPlaylist()`. Update `fetchVideoInfo()` to detect `_type == "playlist"` |
| `lib/shell/app_shell.dart` | Add `_isPlaylist` flag, route to `PlaylistAnalyzedScreen` when true, pass correct callbacks |
| `lib/services/ytdlp_service.dart` | Optionally add `fetchPlaylistFlat(url)` method that runs `--flat-playlist -J` |

---

## 15. Visual States

| State | What the user sees |
|---|---|
| `PlaylistFetchState.loading` | Shimmer header + shimmer rows (5–6 skeleton rows) |
| `PlaylistFetchState.success` | Full screen with real data |
| `PlaylistFetchState.error` | Error card with retry button |
| Row format loading | Spinner on quality chip, other controls still active |
| Row unavailable | Dim opacity 0.4, 🚫 badge, no download button, checkbox disabled |
| Download All pressed | Rows flash a brief green tick, button shows "Queued!" for 1.5s |

---

## 16. Loading Skeleton Layout

```
┌──────────────────────────────────┬────────────────────────────────────────────────────┐
│  LEFT PANEL (loading)            │  RIGHT PANEL (loading)                             │
│                                  │                                                    │
│  [████████████████████████████]  │  [░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░]  │
│  shimmer 16:9 full width         │  filter bar shimmer                                │
│                                  │                                                    │
│  [████████████████]  title       │  ROW shimmer ×1                                    │
│  [██████████]  channel           │  ┌──────────────────────────────────────────────┐  │
│  [████]  stats                   │  │ ○  ##  [████ 120×68]  [██████████████████]  │  │
│                                  │  │                        [████████]            │  │
│  [█████]  [████]  settings       │  └──────────────────────────────────────────────┘  │
│  [████████████████]  output      │                                                    │
│                                  │  ROW shimmer ×2  (same pattern, repeat ×5)        │
│  [████████████████████████████]  │                                                    │
│  Download All shimmer            │                                                    │
│  [████████████████████████████]  │                                                    │
│  Queue All shimmer               │                                                    │
└──────────────────────────────────┴────────────────────────────────────────────────────┘
```

---

## 17. Implementation Order

1. **Models** — `PlaylistEntry`, `PlaylistInfo` (no dependencies)
2. **YtDlpService** — add `fetchPlaylistFlat(url)` returning `PlaylistInfo`
3. **AppState** — add playlist state fields + `fetchPlaylist()`, update `fetchVideoInfo()` type detection
4. **AppShell** — add `_isPlaylist` routing
5. **`playlist_video_row.dart`** — build the row widget
6. **`playlist_analyzed_screen.dart`** — compose all sections
7. **Testing** — test with public YouTube playlists, verify unavailable-video handling, verify Download All queuing order
