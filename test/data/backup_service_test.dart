import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggevity/data/backup_service.dart';
import 'package:loggevity/data/database.dart';
import 'package:loggevity/data/metrics_repository.dart';
import 'package:loggevity/data/portability.dart';
import 'package:loggevity/scoring/scoring.dart';

void main() {
  late AppDatabase db;
  late BackupService service;
  final now = DateTime(2026, 7, 8, 20);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = BackupService(db, MetricsRepository(db, clock: () => now));
  });
  tearDown(() => db.close());

  test('names the file by format and date', () {
    expect(service.fileName(BackupFormat.json, DateTime(2026, 7, 6)),
        'loggevity-2026-07-06.json');
    expect(service.fileName(BackupFormat.csv, DateTime(2026, 12, 31)),
        'loggevity-2026-12-31.csv');
  });

  test('renders JSON including the stored week start', () async {
    await db.setWeekStartDay(DateTime.sunday);
    final rendered = await service.render(BackupFormat.json);
    expect(rendered, contains('"weekStartDay": ${DateTime.sunday}'));
    expect(parseJson(rendered).errors, isEmpty);
  });

  test('renders CSV that parses back', () async {
    await MetricsRepository(db, clock: () => now).log(
      category: ActivityCategory.nature,
      value: 45,
      occurredAt: DateTime(2026, 7, 7, 10),
    );
    final parsed = parseCsv(await service.render(BackupFormat.csv));
    expect(parsed.errors, isEmpty);
    expect(parsed.entries.single.category, ActivityCategory.nature);
    expect(parsed.entries.single.value, 45);
  });

  test('a cancelled import changes nothing', () {
    const outcome = ImportOutcome.cancelled();
    expect(outcome.added, 0);
    expect(outcome.changedAnything, isFalse);
    expect(outcome.errors, isEmpty);
  });
}
