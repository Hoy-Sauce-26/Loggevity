import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggevity/data/database.dart';
import 'package:loggevity/data/metrics_repository.dart';
import 'package:loggevity/data/portability.dart';
import 'package:loggevity/scoring/scoring.dart';

void main() {
  late AppDatabase db;
  late MetricsRepository repo;
  final now = DateTime(2026, 7, 8, 20);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = MetricsRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  Future<void> seed() async {
    await repo.log(
      category: ActivityCategory.moderatePA,
      value: 50,
      occurredAt: DateTime(2026, 7, 6, 12),
      note: 'walk to the shops',
    );
    await repo.log(
      category: ActivityCategory.sleep,
      value: 7.5,
      occurredAt: DateTime(2026, 7, 7, 7),
    );
  }

  group('JSON export', () {
    test('carries the entries and its own schema version', () async {
      await seed();
      final json = jsonDecode(exportJson(await repo.allEntries()))
          as Map<String, dynamic>;

      expect(json['app'], 'loggevity');
      expect(json['schemaVersion'], kExportSchemaVersion);
      expect(json['entries'], hasLength(2));

      final first = (json['entries'] as List).first as Map<String, dynamic>;
      expect(first['category'], 'moderatePA');
      expect(first['value'], 50);
      expect(first['unit'], 'minutes');
      expect(first['localDate'], '2026-07-06');
      expect(first['note'], 'walk to the shops');
    });

    test('writes the category by name, never by ordinal', () async {
      await seed();
      final text = exportJson(await repo.allEntries());
      // An ordinal would survive a reorder of the enum and silently
      // recategorise every entry on the way back in.
      expect(text, contains('"category": "moderatePA"'));
      expect(text, isNot(contains('"category": 0')));
    });
  });

  group('CSV export', () {
    test('has a header and one row per entry', () async {
      await seed();
      final lines = const LineSplitter()
          .convert(exportCsv(await repo.allEntries()))
        ..removeWhere((l) => l.isEmpty);
      expect(lines.first, kCsvHeader.join(','));
      expect(lines, hasLength(3));
      expect(lines[1], startsWith('2026-07-06,moderatePA,50,minutes,'));
    });

    test('quotes a note containing a comma', () async {
      await repo.log(
        category: ActivityCategory.nature,
        value: 30,
        occurredAt: DateTime(2026, 7, 6, 9),
        note: 'park, then river',
      );
      final csv = exportCsv(await repo.allEntries());
      expect(csv, contains('"park, then river"'));
      // And it survives the round trip as one field.
      expect(parseCsv(csv).entries.single.note, 'park, then river');
    });
  });

  group('round trip', () {
    test('JSON preserves every field', () async {
      await seed();
      final original = await repo.allEntries();
      final parsed = parseJson(exportJson(original));

      expect(parsed.errors, isEmpty);
      expect(parsed.entries, hasLength(2));
      expect(parsed.entries.first.category, ActivityCategory.moderatePA);
      expect(parsed.entries.first.value, 50);
      expect(parsed.entries.first.localDate, '2026-07-06');
      expect(parsed.entries.first.note, 'walk to the shops');
      expect(parsed.entries.last.value, 7.5);
    });

    test('CSV preserves every field', () async {
      await seed();
      final parsed = parseCsv(exportCsv(await repo.allEntries()));
      expect(parsed.errors, isEmpty);
      expect(parsed.entries.map((e) => e.category).toList(),
          [ActivityCategory.moderatePA, ActivityCategory.sleep]);
      expect(parsed.entries.last.value, 7.5);
      expect(parsed.entries.last.note, isNull);
    });

    test('a full export-import cycle reproduces the same score', () async {
      await seed();
      final exported = exportJson(await repo.allEntries());
      final before = await repo.loadWeek(await repo.currentWeek());

      // Import into a completely fresh database.
      final fresh = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(fresh.close);
      final freshRepo = MetricsRepository(fresh, clock: () => now);
      await freshRepo.importEntries(parseJson(exported).entries);

      final after = await freshRepo.loadWeek(await freshRepo.currentWeek());
      expect(after.full.compositePercent,
          closeTo(before.full.compositePercent, 1e-9));
      expect(after.totals.moderateMinutes, before.totals.moderateMinutes);
      expect(after.totals.sleepHoursPerNight, before.totals.sleepHoursPerNight);
    });
  });

  group('import is additive and idempotent', () {
    test('re-importing the same file adds nothing', () async {
      await seed();
      final exported = exportJson(await repo.allEntries());

      expect(await repo.importEntries(parseJson(exported).entries), 0);
      expect(await repo.allEntries(), hasLength(2));
    });

    test('merges new entries without touching existing ones', () async {
      await seed();
      final donor = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(donor.close);
      final donorRepo = MetricsRepository(donor, clock: () => now);
      await donorRepo.log(
        category: ActivityCategory.socializing,
        value: 3,
        occurredAt: DateTime(2026, 7, 9, 19),
      );

      final added = await repo.importEntries(
          parseJson(exportJson(await donorRepo.allEntries())).entries);

      expect(added, 1);
      expect(await repo.allEntries(), hasLength(3));
    });

    test('an entry differing only in value is kept as distinct', () async {
      await seed();
      final at = DateTime(2026, 7, 6, 12).toUtc();
      final added = await repo.importEntries([
        PortableEntry(
          localDate: '2026-07-06',
          category: ActivityCategory.moderatePA,
          value: 51, // one minute more
          occurredAt: at,
        ),
      ]);
      expect(added, 1);
    });
  });

  group('rejecting bad input', () {
    test('refuses a file that is not a Loggevity export', () {
      expect(() => parseJson('{"app":"something-else"}'),
          throwsA(isA<ImportFormatException>()));
      expect(() => parseJson('not json at all'),
          throwsA(isA<ImportFormatException>()));
      expect(() => parseJson('[]'), throwsA(isA<ImportFormatException>()));
    });

    test('refuses an export newer than this app understands', () {
      final future = jsonEncode({
        'app': 'loggevity',
        'schemaVersion': kExportSchemaVersion + 1,
        'entries': <dynamic>[],
      });
      expect(() => parseJson(future), throwsA(isA<ImportFormatException>()));
    });

    test('refuses a CSV missing a required column', () {
      expect(() => parseCsv('category,value\nsleep,8'),
          throwsA(isA<ImportFormatException>()));
      expect(() => parseCsv(''), throwsA(isA<ImportFormatException>()));
    });

    test('reports bad rows individually and keeps the good ones', () {
      final result = parseCsv([
        kCsvHeader.join(','),
        '2026-07-06,moderatePA,50,minutes,2026-07-06T12:00:00Z,',
        '2026-07-06,teleportation,50,minutes,2026-07-06T12:00:00Z,',
        '2026-07-06,sleep,abc,hours,2026-07-06T12:00:00Z,',
        '2026-07-06,sleep,8,hours,not-a-date,',
      ].join('\n'));

      expect(result.entries, hasLength(1));
      expect(result.errors, hasLength(3));
      expect(result.errors[0], contains('teleportation'));
      expect(result.errors[1], contains('not a number'));
      expect(result.errors[2], contains('not a date'));
    });

    test('recovers a missing day key from the timestamp', () {
      final result = parseJson(jsonEncode({
        'app': 'loggevity',
        'schemaVersion': 1,
        'entries': [
          {
            'category': 'nature',
            'value': 30,
            'occurredAt': '2026-07-06T12:00:00Z',
          },
        ],
      }));
      expect(result.errors, isEmpty);
      expect(result.entries.single.localDate, isNotEmpty);
      expect(result.entries.single.category, ActivityCategory.nature);
    });
  });
}
