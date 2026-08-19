import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggevity/data/database.dart';
import 'package:loggevity/scoring/scoring.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('schema', () {
    Future<List<String>> tableNames() async {
      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
          .get();
      return rows.map((r) => r.read<String>('name')).toList();
    }

    Future<Set<String>> columnsOf(String table) async {
      final rows = await db.customSelect('PRAGMA table_info($table)').get();
      return rows.map((r) => r.read<String>('name')).toSet();
    }

    test('creates every table', () async {
      final names = await tableNames();
      expect(names,
          containsAll(['daily_entries', 'weekly_snapshots', 'app_settings']));
    });

    test('daily_entries has the expected columns', () async {
      expect(
        await columnsOf('daily_entries'),
        {'id', 'occurred_at', 'local_date', 'category', 'value', 'note'},
      );
    });

    test('weekly_snapshots carries all seven sub-scores', () async {
      expect(
        await columnsOf('weekly_snapshots'),
        containsAll([
          'week_start_date',
          'week_start_day',
          'composite_score',
          'score_mod_p_a',
          'score_vig_p_a',
          'score_res',
          'score_flex',
          'score_nat',
          'score_soc',
          'score_sleep',
          'is_sealed',
        ]),
      );
    });

    test('indexes the columns the week query filters on', () async {
      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type='index'")
          .get();
      final names = rows.map((r) => r.read<String>('name')).toList();
      expect(names, contains('idx_daily_entries_local_date'));
      expect(names, contains('idx_daily_entries_category'));
    });

    test('schemaVersion is 2', () => expect(db.schemaVersion, 2));

    test('app_settings carries the ring preference', () async {
      expect(await columnsOf('app_settings'),
          {'id', 'week_start_day', 'ring_shows_pace'});
    });
  });

  group('settings', () {
    test('a singleton row is seeded on first open, defaulting to Monday',
        () async {
      final s = await db.loadSettings();
      expect(s.id, 0);
      expect(s.weekStartDay, DateTime.monday);
      expect(await db.select(db.appSettings).get(), hasLength(1));
    });

    test('the ring preference defaults to pace and persists', () async {
      expect((await db.loadSettings()).ringShowsPace, isTrue);
      await db.setRingShowsPace(false);
      expect((await db.loadSettings()).ringShowsPace, isFalse);
      await db.setRingShowsPace(true);
      expect((await db.loadSettings()).ringShowsPace, isTrue);
    });

    test('week start is user-configurable and persists', () async {
      await db.setWeekStartDay(DateTime.sunday);
      expect((await db.loadSettings()).weekStartDay, DateTime.sunday);
      // Re-opening must not clobber the stored value with the default.
      expect(await db.select(db.appSettings).get(), hasLength(1));
    });

    test('changes push through the settings stream', () async {
      final seen = <int>[];
      final sub = db.watchSettings().listen((s) => seen.add(s.weekStartDay));
      await pumpEventQueue();
      await db.setWeekStartDay(DateTime.saturday);
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, [DateTime.monday, DateTime.saturday]);
    });
  });

  group('enum ordinals are a storage contract', () {
    // Reordering ActivityCategory would silently recategorise every stored
    // row, because drift persists intEnum columns as the ordinal.
    test('are pinned', () {
      expect(ActivityCategory.values.map((c) => c.name).toList(), [
        'moderatePA',
        'vigorousPA',
        'resistance',
        'flexibility',
        'nature',
        'socializing',
        'sleep',
      ]);
      expect(ActivityCategory.moderatePA.index, 0);
      expect(ActivityCategory.sleep.index, 6);
    });

    test('round-trip through the database preserves the category', () async {
      for (final c in ActivityCategory.values) {
        await db.into(db.dailyEntries).insert(DailyEntriesCompanion.insert(
              occurredAt: DateTime.utc(2026, 7, 6, 12),
              localDate: '2026-07-06',
              category: c,
              value: 10,
            ));
      }
      final rows = await db.select(db.dailyEntries).get();
      expect(rows.map((r) => r.category).toList(), ActivityCategory.values);
    });

    test('the stored integer is the ordinal', () async {
      await db.into(db.dailyEntries).insert(DailyEntriesCompanion.insert(
            occurredAt: DateTime.utc(2026, 7, 6, 12),
            localDate: '2026-07-06',
            category: ActivityCategory.socializing,
            value: 2,
          ));
      final raw = await db
          .customSelect('SELECT category FROM daily_entries')
          .getSingle();
      expect(raw.read<int>('category'), ActivityCategory.socializing.index);
    });
  });

  group('weekly snapshots', () {
    Future<int> insertSnapshot(DateTime weekStart) =>
        db.into(db.weeklySnapshots).insert(WeeklySnapshotsCompanion.insert(
              weekStartDate: weekStart,
              compositeScore: 84.77,
              scoreModPA: 7.4,
              scoreVigPA: 0,
              scoreRes: 10,
              scoreFlex: 10,
              scoreNat: 10,
              scoreSoc: 10,
              scoreSleep: 9.9,
            ));

    test('weekStartDate is unique', () async {
      await insertSnapshot(DateTime(2026, 7, 6));
      await expectLater(
        insertSnapshot(DateTime(2026, 7, 6)),
        throwsA(isA<SqliteException>()),
      );
    });

    test('defaults to unsealed and records the week start day', () async {
      await insertSnapshot(DateTime(2026, 7, 6));
      final row = await db.select(db.weeklySnapshots).getSingle();
      expect(row.isSealed, isFalse);
      expect(row.weekStartDay, DateTime.monday);
    });
  });
}
