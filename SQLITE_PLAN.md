# SQLite Persistent History — Implementation Plan

## The Idea

Right now every download record lives in `AppState`'s in-memory `List<DownloadItem>`.  
When the app is closed and reopened, that list is gone — the library screen shows nothing.

The goal: **persist download metadata in a local SQLite database** so the library survives restarts.  
The stored data is *never* the video file itself — only pointers and metadata about it.

---

## What Gets Stored (Schema)

| Column | Type | Example |
|--------|------|---------|
| `id` | TEXT PK | UUID generated at download start |
| `title` | TEXT | "Gehra Hua – Dhurandhar" |
| `url` | TEXT | full YouTube/Instagram URL |
| `output_path` | TEXT | `C:\Users\hp\Videos\gehra_hua.mp4` |
| `resolution` | TEXT | `1080p`, `320k` |
| `format` | TEXT | `MP4`, `MP3` |
| `thumbnail_url` | TEXT | CDN thumbnail URL |
| `extractor` | TEXT | `youtube`, `instagram` |
| `file_size_bytes` | INTEGER | 0 until done |
| `status` | TEXT | `done`, `error` |
| `downloaded_at` | INTEGER | Unix timestamp (ms) |
| `duration_seconds` | INTEGER | from yt-dlp metadata |

---

## Is This Possible? Yes, 100%.

Flutter has first-class SQLite support via two packages:

| Package | Style | Best For |
|---------|-------|----------|
| `sqflite` | Raw SQL (`INSERT`, `SELECT`) | Simple, direct control |
| `drift` (formerly Moor) | Type-safe ORM, Dart DSL | Large schemas, migrations |

For this app **`sqflite` is recommended** — the schema is small, queries are simple, no ORM overhead needed.

---

## How the "Missing File" Check Works

When the app opens and loads history from DB:

```
for each record in DB:
  if File(record.output_path).existsSync() == false:
    delete record from DB
  else:
    add to in-memory list
```

This handles:
- User manually deleting the file from Explorer
- File moved to a different folder
- External drive disconnected

---

## Implementation Plan (Step by Step)

### Step 1 — Add dependency

```yaml
# pubspec.yaml
dependencies:
  sqflite: ^2.3.3+1
  path: ^1.9.0        # for constructing DB file path
  uuid: ^4.4.2        # for generating unique IDs per download
```

Run `flutter pub get`.

---

### Step 2 — Create `lib/services/download_db.dart`

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/download_item.dart';

class DownloadDb {
  static const _dbName = 'downtube_history.db';
  static const _version = 1;
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = join(dir, _dbName);
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE downloads (
          id TEXT PRIMARY KEY,
          title TEXT,
          url TEXT,
          output_path TEXT,
          resolution TEXT,
          format TEXT,
          thumbnail_url TEXT,
          extractor TEXT,
          file_size_bytes INTEGER DEFAULT 0,
          status TEXT,
          downloaded_at INTEGER,
          duration_seconds INTEGER
        )
      '''),
    );
  }

  /// Insert or replace a completed download record.
  static Future<void> save(DownloadItem item) async {
    final database = await db;
    await database.insert(
      'downloads',
      item.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Load all records, deleting any whose file no longer exists.
  static Future<List<DownloadItem>> loadAndClean() async {
    final database = await db;
    final rows = await database.query('downloads', orderBy: 'downloaded_at DESC');
    final result = <DownloadItem>[];
    for (final row in rows) {
      final item = DownloadItem.fromDbMap(row);
      if (File(item.outputPath).existsSync()) {
        result.add(item);
      } else {
        // File was deleted from disk — remove from DB too
        await database.delete('downloads', where: 'id = ?', whereArgs: [item.id]);
      }
    }
    return result;
  }

  /// Delete a single record (e.g. user manually removes from library).
  static Future<void> remove(String id) async {
    final database = await db;
    await database.delete('downloads', where: 'id = ?', whereArgs: [id]);
  }
}
```

---

### Step 3 — Update `DownloadItem` model

Add `id`, `downloadedAt`, and `durationSeconds` fields.  
Add `toDbMap()` and `fromDbMap()` methods:

```dart
// In DownloadItem:
final String id;          // uuid
final DateTime downloadedAt;
final int? durationSeconds;

Map<String, dynamic> toDbMap() => {
  'id': id,
  'title': title,
  'url': url,
  'output_path': outputPath,
  'resolution': resolution,
  'format': format,
  'thumbnail_url': thumbnailUrl,
  'extractor': extractor,
  'status': status.name,
  'downloaded_at': downloadedAt.millisecondsSinceEpoch,
  'duration_seconds': durationSeconds,
};

factory DownloadItem.fromDbMap(Map<String, dynamic> row) => DownloadItem(
  id: row['id'] as String,
  title: row['title'] as String,
  url: row['url'] as String,
  outputPath: row['output_path'] as String,
  resolution: row['resolution'] as String,
  format: row['format'] as String,
  thumbnailUrl: row['thumbnail_url'] as String?,
  extractor: row['extractor'] as String?,
  status: DownloadStatus.done,
  downloadedAt: DateTime.fromMillisecondsSinceEpoch(row['downloaded_at'] as int),
  durationSeconds: row['duration_seconds'] as int?,
);
```

---

### Step 4 — Wire into `AppState`

**On app start** (in `AppState` constructor or `initState` of root widget):

```dart
Future<void> _loadHistory() async {
  final saved = await DownloadDb.loadAndClean();
  _downloads.addAll(saved);
  notifyListeners();
}
```

**When a download completes** (inside the download loop, status → done):

```dart
if (item.status == DownloadStatus.done) {
  item = item.copyWith(
    id: Uuid().v4(),
    downloadedAt: DateTime.now(),
  );
  await DownloadDb.save(item);
}
```

---

### Step 5 — Library screen "remove" button

Add a delete option to `LibraryCard` that:
1. Calls `DownloadDb.remove(item.id)`
2. Removes from `AppState._downloads`
3. Does NOT delete the actual file (that's the user's choice)

Optionally: show a "Also delete file?" dialog.

---

## Database File Location

On Windows: `C:\Users\<user>\AppData\Roaming\com.example.youtube_downloder\downtube_history.db`  
On Android: App internal storage (`/data/data/<package>/databases/`)

The user never needs to touch this file directly.

---

## Migration Strategy

If the schema changes in a future version, increment `_version` and add `onUpgrade`:

```dart
onUpgrade: (db, oldVersion, newVersion) async {
  if (oldVersion < 2) {
    await db.execute('ALTER TABLE downloads ADD COLUMN duration_seconds INTEGER');
  }
}
```

---

## Summary

| Concern | Answer |
|---------|--------|
| Is SQLite possible in Flutter? | ✅ Yes, first-class support via `sqflite` |
| What is stored? | Metadata only (path, title, resolution, etc.) |
| What if the file was deleted? | DB record auto-removed on next app open |
| Persistence across restarts? | ✅ Fully persistent |
| File size of DB? | Tiny — a few KB for thousands of records |
| Platform support? | Windows, Android, iOS, Linux, macOS ✅ |
