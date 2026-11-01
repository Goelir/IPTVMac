import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

/// The SQLite file (or an in-memory database for tests). The schema and the migration names match the Apple apps
/// (GRDB's `grdb_migrations` table), so the two stay in step.
///
/// sqlite3 is synchronous: [read] and [write] just run the callback. [write] is one transaction (BEGIN IMMEDIATE ... COMMIT),
/// which is what makes bulk loading 100k rows fast.
class AppDatabase {
  AppDatabase._(this.raw);

  /// A fresh in-memory database.
  factory AppDatabase.memory() => AppDatabase._(_configure(sqlite3.openInMemory(), null));

  /// Opens (and migrates) the file. Throws a [SqliteException] when it is not a database: see [openRecovering].
  factory AppDatabase.open(String path) {
    final db = sqlite3.open(path);
    try {
      _configure(db, path);
      return AppDatabase._(db);
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  /// Opens the database; a corrupt/non-SQLite file is moved aside (not deleted) and a fresh one is created.
  /// Returns the moved-aside path when that happened. Busy/IO errors are rethrown.
  static ({AppDatabase db, String? movedAside}) openRecovering(String path) {
    try {
      return (db: AppDatabase.open(path), movedAside: null);
    } on SqliteException catch (e) {
      if (e.resultCode != 26 && e.resultCode != 11) rethrow; // SQLITE_NOTADB, SQLITE_CORRUPT
      final aside = '$path.corrupt-${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
      File(path).renameSync(aside);
      for (final suffix in ['-wal', '-shm']) {
        try {
          File('$path$suffix').deleteSync();
        } on FileSystemException {
          // not there
        }
      }
      return (db: AppDatabase.open(path), movedAside: aside);
    }
  }

  final Database raw;

  T read<T>(T Function(Database db) f) => f(raw);

  T write<T>(T Function(Database db) f) {
    raw.execute('BEGIN IMMEDIATE');
    try {
      final r = f(raw);
      raw.execute('COMMIT');
      return r;
    } catch (_) {
      raw.execute('ROLLBACK');
      rethrow;
    }
  }

  void close() => raw.close();

  static Database _configure(Database db, String? path) {
    db.execute('PRAGMA foreign_keys = ON'); // the cascades (deleting a playlist deletes its items) depend on it
    if (path != null) {
      // A WAL file: readers never wait for the long sync write. A second process waits 5 s instead of failing at once.
      db.execute('PRAGMA busy_timeout = 5000');
      db.execute('PRAGMA journal_mode = WAL');
      if (!migrationsCompleted(db) && _tableExists(db, 'account')) {
        // Existing data and a pending migration: keep a copy first (it also holds the account passwords: same 0600 rules).
        final bak = '$path.bak';
        try {
          File(bak).deleteSync();
        } on FileSystemException {
          // no old copy
        }
        try {
          db.execute('VACUUM INTO ?', [bak]);
          _ownerOnly(bak);
        } on SqliteException {
          // the copy is a courtesy: never block opening the database
        }
      }
    }
    migrate(db);
    if (path != null) {
      for (final suffix in ['', '-wal', '-shm']) {
        _ownerOnly('$path$suffix');
      }
    }
    return db;
  }

  /// The file holds account passwords: owner-only. Best effort (no chmod on Windows).
  static void _ownerOnly(String path) {
    if (Platform.isWindows || !File(path).existsSync()) return;
    try {
      Process.runSync('chmod', ['600', path]);
    } on ProcessException {
      // no chmod binary: the app-private directory still protects the file
    }
  }

  static bool _tableExists(Database db, String name) =>
      db.select("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", [name]).isNotEmpty;

  static bool migrationsCompleted(Database db) {
    if (!_tableExists(db, 'grdb_migrations')) return false;
    final done = {for (final r in db.select('SELECT identifier FROM grdb_migrations')) r['identifier'] as String};
    return migrations.every((m) => done.contains(m.$1));
  }

  /// Applies the pending migrations, in order, each in its own transaction. [upTo] stops after that migration.
  static void migrate(Database db, {String? upTo}) {
    db.execute('CREATE TABLE IF NOT EXISTS grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)');
    final done = {for (final r in db.select('SELECT identifier FROM grdb_migrations')) r['identifier'] as String};
    for (final (name, sql) in migrations) {
      if (!done.contains(name)) {
        db.execute('BEGIN');
        try {
          db.execute(sql);
          db.execute('INSERT INTO grdb_migrations (identifier) VALUES (?)', [name]);
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      }
      if (name == upTo) break;
    }
  }

  static const migrations = <(String, String)>[
    ('v1', _v1),
    // Account passwords: the Apple apps keep them in this table; the Android shell uses the platform keystore through
    // `SecretStore`. The table stays so a database file is the same on both.
    ('v2-secret', _v2),
    // Search index maintenance only when the name changes: re-syncs rewrite every row but almost never change a name.
    ('v3-fts-trigger', _v3),
    // What the provider says about a movie or series (parsed JSON, no credentials), kept for 14 days; goes with its playlist.
    ('v4-item-info', _v4),
    // Where the intro and the credits of a series are, marked by the user once and used for every episode.
    ('v5-series-marks', _v5),
  ];

  static const _v1 = '''
CREATE TABLE "account" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "name" TEXT NOT NULL, "kind" TEXT NOT NULL, "server" TEXT, "username" TEXT, "url" TEXT);
CREATE TABLE "category" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "accountId" INTEGER NOT NULL REFERENCES "account"("id") ON DELETE CASCADE,
  "type" TEXT NOT NULL, "remoteId" TEXT NOT NULL, "name" TEXT NOT NULL,
  UNIQUE ("accountId","type","remoteId"));
CREATE TABLE "item" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "accountId" INTEGER NOT NULL REFERENCES "account"("id") ON DELETE CASCADE,
  "type" TEXT NOT NULL, "name" TEXT NOT NULL, "categoryId" TEXT, "icon" TEXT, "rating" TEXT,
  "streamId" TEXT NOT NULL, "containerExt" TEXT, "directURL" TEXT,
  "tvArchive" BOOLEAN NOT NULL DEFAULT 0, "archiveDays" INTEGER NOT NULL DEFAULT 0,
  "epgChannelId" TEXT, "stale" BOOLEAN NOT NULL DEFAULT 0,
  UNIQUE ("accountId","type","streamId"));
CREATE INDEX "item_category" ON "item"("accountId","type","categoryId");
CREATE VIRTUAL TABLE "item_fts" USING fts5(name, content='item', content_rowid='id', tokenize='unicode61 remove_diacritics 2');
CREATE TRIGGER "__item_fts_ai" AFTER INSERT ON "item" BEGIN
  INSERT INTO "item_fts"("rowid","name") VALUES (new."id", new."name");
END;
CREATE TRIGGER "__item_fts_ad" AFTER DELETE ON "item" BEGIN
  INSERT INTO "item_fts"("item_fts","rowid","name") VALUES('delete', old."id", old."name");
END;
CREATE TRIGGER "__item_fts_au" AFTER UPDATE ON "item" BEGIN
  INSERT INTO "item_fts"("item_fts","rowid","name") VALUES('delete', old."id", old."name");
  INSERT INTO "item_fts"("rowid","name") VALUES (new."id", new."name");
END;
CREATE TABLE "episode" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "accountId" INTEGER NOT NULL REFERENCES "account"("id") ON DELETE CASCADE,
  "seriesId" TEXT NOT NULL, "season" INTEGER NOT NULL, "number" INTEGER NOT NULL,
  "title" TEXT NOT NULL, "streamId" TEXT NOT NULL, "containerExt" TEXT,
  UNIQUE ("accountId","streamId"));
CREATE TABLE "favorite" (
  "accountId" INTEGER NOT NULL, "type" TEXT NOT NULL, "streamId" TEXT NOT NULL,
  PRIMARY KEY ("accountId","type","streamId"));
CREATE TABLE "history" (
  "accountId" INTEGER NOT NULL, "type" TEXT NOT NULL, "streamId" TEXT NOT NULL,
  "position" DOUBLE NOT NULL, "duration" DOUBLE NOT NULL, "updated" DATETIME NOT NULL,
  PRIMARY KEY ("accountId","type","streamId"));
''';

  static const _v2 = '''
CREATE TABLE "secret" (
  "accountId" INTEGER NOT NULL PRIMARY KEY REFERENCES "account"("id") ON DELETE CASCADE,
  "password" TEXT NOT NULL);
''';

  static const _v3 = '''
DROP TRIGGER IF EXISTS "__item_fts_au";
CREATE TRIGGER "__item_fts_au" AFTER UPDATE OF name ON item WHEN old.name IS NOT new.name BEGIN
  INSERT INTO item_fts(item_fts, rowid, name) VALUES('delete', old.id, old.name);
  INSERT INTO item_fts(rowid, name) VALUES (new.id, new.name);
END;
''';

  static const _v5 = '''
CREATE TABLE "series_marks" (
  "accountId" INTEGER NOT NULL REFERENCES "account"("id") ON DELETE CASCADE,
  "seriesId" TEXT NOT NULL, "introStart" DOUBLE, "introEnd" DOUBLE, "creditsLen" DOUBLE,
  PRIMARY KEY ("accountId","seriesId"));
''';

  static const _v4 = '''
CREATE TABLE "item_info" (
  "accountId" INTEGER NOT NULL REFERENCES "account"("id") ON DELETE CASCADE,
  "type" TEXT NOT NULL, "streamId" TEXT NOT NULL, "json" TEXT NOT NULL, "fetched" DATETIME NOT NULL,
  PRIMARY KEY ("accountId","type","streamId"));
''';
}
