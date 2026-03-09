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
  static const _version = 5;
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
            video_duration  INTEGER
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

  /// Load all saved records. Deduplicates by URL (keeps most recent per URL).
  /// Does NOT remove records with missing files — use [cleanMissing] for that.
  static Future<List<DownloadItem>> loadAndClean() async {
    final db = await _database;
    final rows = await db.query('downloads', orderBy: 'created_at DESC');

    final items = rows.map((row) => DownloadItem.fromDbMap(row)).toList();

    // Deduplicate: keep only the most recent record per URL
    final seenUrls = <String>{};
    final deduped = <DownloadItem>[];
    for (final item in items) {
      final key = item.url.isNotEmpty ? item.url : item.id;
      if (seenUrls.add(key)) {
        deduped.add(item);
      } else {
        // Older duplicate — remove from DB
        await db.delete('downloads', where: 'id = ?', whereArgs: [item.id]);
      }
    }

    return deduped;
  }

  /// Remove records whose output files no longer exist on disk.
  static Future<int> cleanMissing() async {
    final db = await _database;
    final rows = await db.query('downloads', orderBy: 'created_at DESC');
    int removed = 0;
    for (final row in rows) {
      final item = DownloadItem.fromDbMap(row);
      final bool exists;
      if (item.filePath.isNotEmpty) {
        // Check exact path first
        if (File(item.filePath).existsSync()) {
          exists = true;
        } else {
          // yt-dlp may have changed the extension during merge/conversion.
          // Look for any file with the same base name in the same directory.
          final dir = Directory(p.dirname(item.filePath));
          final baseName = p.basenameWithoutExtension(item.filePath);
          if (dir.existsSync()) {
            exists = dir.listSync().whereType<File>().any(
              (f) => p.basenameWithoutExtension(f.path) == baseName,
            );
          } else {
            exists = false;
          }
        }
      } else {
        // No filePath stored (legacy record) — we can't verify file existence,
        // so keep the record to avoid wrongly deleting valid entries.
        exists = true;
      }
      if (!exists) {
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
