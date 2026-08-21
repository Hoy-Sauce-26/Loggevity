import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggevity/data/database.dart';
import 'package:loggevity/data/metrics_repository.dart';
import 'package:loggevity/providers.dart';
import 'package:loggevity/screens/dashboard_page.dart';
import 'package:loggevity/scoring/scoring.dart';
import 'package:loggevity/widgets/day_selector.dart';

/// Logging something that happened on an earlier day.
///
/// Without this, a night's sleep remembered the next afternoon has to go on
/// today - which both credits the wrong day and leaves the night it actually
/// happened scored as missing.
void main() {
  late AppDatabase db;
  late MetricsRepository repo;
  // Wednesday of the week beginning Mon 2026-07-06.
  final now = DateTime(2026, 7, 8, 20, 15);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = MetricsRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  group('repository', () {
    test('moving an entry to another day keeps its time of day', () async {
      final id = await repo.log(
        category: ActivityCategory.sleep,
        value: 8,
        occurredAt: DateTime(2026, 7, 8, 9, 30),
      );

      await repo.updateEntry(id, value: 7.5, day: DateTime(2026, 7, 7));

      final row = await (db.select(db.dailyEntries)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(row.localDate, '2026-07-07');
      expect(row.value, 7.5);
      final local = row.occurredAt.toLocal();
      expect(local.hour, 9);
      expect(local.minute, 30);
    });

    test('a back-dated night counts as its own night, not as today', () async {
      await repo.log(
        category: ActivityCategory.sleep,
        value: 8,
        occurredAt: DateTime(2026, 7, 7, 7),
      );
      await repo.log(
        category: ActivityCategory.sleep,
        value: 7,
        occurredAt: DateTime(2026, 7, 8, 7),
      );

      final metrics = await repo.loadWeek(await repo.currentWeek());
      expect(metrics.totals.sleepHoursPerNight, [8, 7]);
    });
  });

  group('detail sheet', () {
    Widget harness() => ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            metricsRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: DashboardPage()),
        );

    testWidgets('an entry logged against the wrong day can be moved',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final id = await repo.log(
        category: ActivityCategory.sleep,
        value: 8,
        occurredAt: DateTime(2026, 7, 8, 7),
      );

      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sleep'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit').first);
      await tester.pumpAndSettle();

      // The dialog's own day picker, not the sheet's.
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.descendant(
          of: find.byType(DaySelector),
          matching: find.text('7'),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final row = await (db.select(db.dailyEntries)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(row.localDate, '2026-07-07');
      expect(row.value, 8);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });
  });

  group('quick log sheet', () {
    Widget harness() => ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            metricsRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: DashboardPage()),
        );

    testWidgets('logs to the selected earlier day', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('Logging to Today'), findsOneWidget);

      // Tuesday the 7th - yesterday.
      await tester.tap(find.descendant(
        of: find.byType(DaySelector),
        matching: find.text('7'),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Logging to Yesterday'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'hours').last,
        '8',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add Sleep'));
      await tester.pumpAndSettle();

      final rows = await repo.allEntries();
      expect(rows, hasLength(1));
      expect(rows.single.category, ActivityCategory.sleep);
      expect(rows.single.localDate, '2026-07-07');
      expect(find.textContaining('on Yesterday'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });

    testWidgets('future days cannot be chosen', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Thursday the 9th is still ahead; tapping it must not move the day.
      await tester.tap(find.descendant(
        of: find.byType(DaySelector),
        matching: find.text('9'),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Logging to Today'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    });
  });
}
