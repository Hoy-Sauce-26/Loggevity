import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggevity/data/database.dart';
import 'package:loggevity/scoring/scoring.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// The exact schema shipped as version 1, kept verbatim so the upgrade path is
/// exercised against what real installs actually have on disk.
const _v1Schema = [
  'CREATE TABLE "daily_entries" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,'
      ' "occurred_at" INTEGER NOT NULL, "local_date" TEXT NOT NULL,'
      ' "category" INTEGER NOT NULL, "value" REAL NOT NULL, "note" TEXT NULL);',
  'CREATE TABLE "weekly_snapshots" ("id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,'
      ' "week_start_date" INTEGER NOT NULL UNIQUE,'
      ' "week_start_day" INTEGER NOT NULL DEFAULT 1,'
      ' "composite_score" REAL NOT NULL, "score_mod_p_a" REAL NOT NULL,'
      ' "score_vig_p_a" REAL NOT NULL, "score_res" REAL NOT NULL,'
      ' "score_flex" REAL NOT NULL, "score_nat" REAL NOT NULL,'
      ' "score_soc" REAL NOT NULL, "score_sleep" REAL NOT NULL,'
      ' "is_sealed" INTEGER NOT NULL DEFAULT 0 CHECK ("is_sealed" IN (0, 1)));',
  'CREATE TABLE "app_settings" ("id" INTEGER NOT NULL DEFAULT 0,'
      ' "week_start_day" INTEGER NOT NULL DEFAULT 1, PRIMARY KEY ("id"));',
  'CREATE INDEX idx_daily_entries_local_date ON daily_entries (local_date);',
  'CREATE INDEX idx_daily_entries_category ON daily_entries (category);',
];

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('loggevity_migration');
    file = File(p.join(dir.path, 'loggevity.sqlite'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  /// Lays down a populated version 1 database on disk.
  void writeV1Database() {
    final raw = sqlite3.open(file.path);
    for (final statement in _v1Schema) {
      raw.execute(statement);
    }
    raw.execute('INSERT INTO app_settings (id, week_start_day) VALUES (0, 7)');
    raw.execute(
      'INSERT INTO daily_entries (occurred_at, local_date, category, value, note)'
      ' VALUES (?, ?, ?, ?, ?)',
      [
        DateTime.utc(2026, 7, 6, 12).millisecondsSinceEpoch ~/ 1000,
        '2026-07-06',
        ActivityCategory.moderatePA.index,
        50.0,
        'walk',
      ],
    );
    raw.execute('PRAGMA user_version = 1');
    raw.dispose();
  }

  test('a fresh database is created at the current version', () async {
    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    expect(db.schemaVersion, 2);
    expect((await db.loadSettings()).ringShowsPace, isTrue);
  });

  group('upgrading a version 1 database', () {
    test('adds the new column with its default', () async {
      writeV1Database();
      final db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);

      final settings = await db.loadSettings();
      expect(settings.ringShowsPace, isTrue);
    });

    test('preserves settings the user had already chosen', () async {
      writeV1Database();
      final db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);

      // A Sunday week start must survive the upgrade, not reset to Monday.
      expect((await db.loadSettings()).weekStartDay, DateTime.sunday);
    });

    test('preserves logged entries', () async {
      writeV1Database();
      final db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);

      final rows = await db.select(db.dailyEntries).get();
      expect(rows, hasLength(1));
      expect(rows.single.category, ActivityCategory.moderatePA);
      expect(rows.single.value, 50);
      expect(rows.single.localDate, '2026-07-06');
      expect(rows.single.note, 'walk');
    });

    test('stamps the database at the new version', () async {
      writeV1Database();
      final db = AppDatabase.forTesting(NativeDatabase(file));
      await db.loadSettings();
      await db.close();

      final raw = sqlite3.open(file.path);
      addTearDown(raw.dispose);
      expect(raw.select('PRAGMA user_version').first.values.first, 2);
    });

    test('is idempotent across repeated opens', () async {
      writeV1Database();
      for (var i = 0; i < 3; i++) {
        final db = AppDatabase.forTesting(NativeDatabase(file));
        expect((await db.loadSettings()).weekStartDay, DateTime.sunday);
        await db.close();
      }
      final raw = sqlite3.open(file.path);
      addTearDown(raw.dispose);
      expect(raw.select('SELECT COUNT(*) c FROM app_settings').first['c'], 1);
      expect(raw.select('SELECT COUNT(*) c FROM daily_entries').first['c'], 1);
    });
  });
}
