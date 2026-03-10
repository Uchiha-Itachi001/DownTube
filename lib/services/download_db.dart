import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/download_item.dart';

/// Persistent SQLite storage for completed download records.
///
/// • Only *completed* downloads (status == done) are stored.
/// • On [loadAndClean], records whose output directory no longer exists on disk
///   are automatically removed, keeping the library fresh.
/// • Uses [sqflite_common_ffi] so it works on Windows / Linux desktop.
class DownloadDb {
  static const _dbName = 'downtube_history.db';
  static const _version = 6;
  static Database? _db;

  static Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    sqfliteFfiInit();
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, _dbName);
    return databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        onCreate: (db, _) => db.execute('''
          CREATE TABLE downloads (
            id          TEXT PRIMARY KEY,
            title       TEXT NOT NULL,
            url         TEXT,
            output_path TEXT,
            resolution  TEXT,
            format      TEXT,
            thumbnail_url TEXT,
            extractor   TEXT,
            status      TEXT,
            created_at  INTEGER NOT NULL,
            download_index INTEGER NOT NULL DEFAULT 0,
            show_in_history INTEGER NOT NULL DEFAULT 1,
            show_in_library INTEGER NOT NULL DEFAULT 1,
            file_path       TEXT NOT NULL DEFAULT '',
            file_size       TEXT,
            video_duration  INTEGER,
            error_message   TEXT
          )
        '''),
        onUpgrade: (db, oldVer, newVer) async {
          if (oldVer < 2) {
            await db.execute(
              'ALTER TABLE downloads ADD COLUMN download_index INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (oldVer < 3) {
            await db.execute(
              'ALTER TABLE downloads ADD COLUMN show_in_history INTEGER NOT NULL DEFAULT 1',
            );
            await db.execute(
              'ALTER TABLE downloads ADD COLUMN show_in_library INTEGER NOT NULL DEFAULT 1',
            );
          }
          if (oldVer < 4) {
            await db.execute(
              "ALTER TABLE downloads ADD COLUMN file_path TEXT NOT NULL DEFAULT ''",
            );
          }
          if (oldVer < 5) {
            await db.execute('ALTER TABLE downloads ADD COLUMN file_size TEXT');
            await db.execute('ALTER TABLE downloads ADD COLUMN video_duration INTEGER');
          }
          if (oldVer < 6) {
            await db.execute('ALTER TABLE downloads ADD COLUMN error_message TEXT');
          }
        },
      ),
    );
  }

  /// Persist a completed download. Replaces any existing record with the same id.
  static Future<void> save(DownloadItem item) async {
    final db = await _database;
    await db.insert(
      'downloads',
      item.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Load all saved records. No automatic deduplication — every record is kept.
  static Future<List<DownloadItem>> loadAndClean() async {
    final db = await _database;
    final rows = await db.query('downloads', orderBy: 'created_at DESC');
    return rows.map((row) => DownloadItem.fromDbMap(row)).toList();
  }

  /// Remove records whose output files no longer exist on disk.
  /// Only checks successfully downloaded items (status == done).
  /// Error/cancelled items are never auto-cleaned.
  static Future<int> cleanMissing() async {
    final db = await _database;
    final rows = await db.query('downloads', orderBy: 'created_at DESC');
    int removed = 0;
    for (final row in rows) {
      final item = DownloadItem.fromDbMap(row);
      // Only clean successfully downloaded items
      if (item.status != DownloadStatus.done) continue;
      // Only check records that have a real file path (not empty, not a template)
      if (item.filePath.isEmpty) continue;
      if (item.filePath.contains('%(')) continue; // unexpanded yt-dlp template
      // Safety: only remove if the parent directory exists but the file doesn't.
      // If the whole directory is gone (e.g. drive unmounted), keep the record.
      final file = File(item.filePath);
      final parentDir = file.parent;
      if (!parentDir.existsSync()) continue; // directory missing — keep record
      if (!file.existsSync()) {
        await db.delete('downloads', where: 'id = ?', whereArgs: [item.id]);
        removed++;
      }
    }
    return removed;
  }

  /// Remove a single record (e.g. user deletes from library).
  static Future<void> remove(String id) async {
    final db = await _database;
    await db.delete('downloads', where: 'id = ?', whereArgs: [id]);
  }

  /// Soft-delete: hide a record from History screen while keeping it in Library.
  static Future<void> hideFromHistory(String id) async {
    final db = await _database;
    await db.update(
      'downloads',
      {'show_in_history': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Remove ALL saved records (clear history).
  static Future<void> clearAll() async {
    final db = await _database;
    await db.delete('downloads');
  }
}
