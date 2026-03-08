# Data Storage — How Downloaded Files Are Shown

## Overview

DownTube does **not** use a traditional database (SQL, SQLite, etc.) to store its data.  
Instead, it follows a lightweight **in-memory + file-path reference** model:

```
User downloads a video
        ↓
yt-dlp saves the file to disk  (e.g. C:\Users\you\Videos\video.mp4)
        ↓
AppState stores a DownloadItem object in memory
        ↓
Library / History screens read from AppState and display the items
```

---

## How It Works in Detail

### 1. DownloadItem — The In-Memory Record

Every download is represented by a `DownloadItem` object (see `lib/models/download_item.dart`):

```dart
class DownloadItem {
  final String title;       // Video title
  final String url;         // Original video URL
  final String resolution;  // e.g. "1080p", "720p", "320k"
  final String format;      // e.g. "MP4", "MP3"
  final String outputPath;  // Local path where the file was saved
  final String? thumbnailUrl; // Remote thumbnail URL (not saved locally)
  DownloadStatus status;     // queued / downloading / done / error
  double progress;           // 0.0 – 1.0
  String? speed;             // "2.4 MiB/s"
  String? eta;               // "00:45"
  // ...
}
```

> **`outputPath`** is the key piece — it stores the exact path on the user's device where
> yt-dlp saved the file (e.g. `C:\Users\you\Videos\My Video.mp4`).

### 2. AppState — Singleton In-Memory Store

`lib/providers/app_state.dart` holds a `List<DownloadItem> downloads` in memory.  
It is a `ChangeNotifier` singleton, so any screen can listen to it reactively.

```dart
// Adding a download:
AppState.instance.enqueueDownload(DownloadItem(...));

// Reading downloads:
final completed = AppState.instance.downloads
    .where((d) => d.status == DownloadStatus.done)
    .toList();
```

### 3. Library & History — Queries Against In-Memory List

- **Library screen** shows `status == DownloadStatus.done` items.
- **History screen** shows all items with timestamps.
- Filtering (Video / Audio) and search work by iterating over the in-memory list.

No SQL query, no disk read — everything is already in RAM.

---

## Is It SQL-Like?

| Concept         | SQL / SQLite          | DownTube (current)          |
|-----------------|-----------------------|-----------------------------|
| Storage medium  | File on disk (.db)    | Dart `List<>` in RAM        |
| Persistence     | Survives app restart  | **Lost on app restart** ❌  |
| Queries         | SELECT / WHERE        | `.where()` / `.firstWhere()`|
| Schema          | Tables + columns      | Dart class fields           |
| Relationships   | Foreign keys          | Not needed (flat list)      |

So **no**, it is not SQL-like. It is closer to a **plain in-memory list** — fast, simple,
but **ephemeral** (all history is lost when the app closes).

---

## Current Limitation — No Persistence

Because nothing is written to disk, **restarting the app clears all download history**.  
The actual video files still exist on disk; only the app's memory of them is lost.

---

## Recommended Future: SQLite via `drift` or `sqflite`

To make history persistent across restarts, store each `DownloadItem` in a local SQLite
database (the file lives in the app documents directory, e.g.  
`C:\Users\you\AppData\Roaming\DownTube\downloads.db`).

You would:
1. Store only the **file path** + metadata (title, format, resolution, date).
2. On startup, load the database and restore `AppState.downloads`.
3. When a file is moved/deleted on disk, mark the item as missing.

```
downloads.db
┌────┬──────────────────────┬────────┬────────────┬────────────────────────────────┐
│ id │ title                │ format │ resolution │ output_path                    │
├────┼──────────────────────┼────────┼────────────┼────────────────────────────────┤
│  1 │ My Video Title       │ MP4    │ 1080p      │ C:\Users\you\Videos\my_vid.mp4 │
│  2 │ Another Song         │ MP3    │ 320k       │ C:\Users\you\Music\song.mp3    │
└────┴──────────────────────┴────────┴────────────┴────────────────────────────────┘
```

> The database stores the **location pointer**, not the file itself.  
> Opening a file = reading `output_path` and calling the OS file-open API.

---

## Summary

| Question                              | Answer                                 |
|---------------------------------------|----------------------------------------|
| Where are video files stored?         | User-chosen folder on their device     |
| Does the app store the full video?    | No — yt-dlp saves it, app just records the path |
| Is a database used now?               | No — in-memory Dart list only          |
| Does history survive app restart?     | No (current limitation)                |
| What would add persistence?           | SQLite (`drift` / `sqflite` package)   |
