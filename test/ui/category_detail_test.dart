import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggevity/data/database.dart';
import 'package:loggevity/data/metrics_repository.dart';
import 'package:loggevity/data/week.dart';
import 'package:loggevity/providers.dart';
import 'package:loggevity/screens/dashboard_page.dart';
import 'package:loggevity/scoring/scoring.dart';
import 'package:loggevity/widgets/category_detail_sheet.dart';
import 'package:loggevity/widgets/score_ring.dart';

void main() {
  late AppDatabase db;
  late MetricsRepository repo;
  // Wednesday of the week beginning Mon 2026-07-06.
  final now = DateTime(2026, 7, 8, 20);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = MetricsRepository(db, clock: () => now);
  });
  tearDown(() => db.close());

  Widget harness() => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          metricsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: DashboardPage()),
      );

  Future<void> withDashboard(
    WidgetTester tester,
    Future<void> Function() body, {
    Size size = const Size(1000, 2200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await body();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// Opens one category's detail sheet from the dashboard, runs [body], then
  /// dismisses it.
  Future<void> withSheet(
    WidgetTester tester,
    ActivityCategory category,
    Future<void> Function() body,
  ) async {
    await withDashboard(tester, () async {
      await tester.tap(find.text(category.label));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryDetailSheet), findsOneWidget);
      await body();
      await tester.tapAt(const Offset(500, 20));
      await tester.pumpAndSettle();
    });
  }

  group('day-by-day breakdown', () {
    testWidgets('tapping a category opens its week, grouped by day',
        (tester) async {
      await repo.log(
        category: ActivityCategory.moderatePA,
        value: 30,
        occurredAt: DateTime(2026, 7, 6, 9),
      );
      await repo.log(
        category: ActivityCategory.moderatePA,
        value: 45,
        occurredAt: DateTime(2026, 7, 8, 17),
      );

      await withDashboard(tester, () async {
        await tester.tap(find.text('Moderate Activity'));
        await tester.pumpAndSettle();

        expect(find.byType(CategoryDetailSheet), findsOneWidget);
        expect(find.text('This week, day by day · minutes'), findsOneWidget);
        // The bars need a scale to mean anything: gridlines plus a labelled
        // y-axis, with the top label on a round number.
        // A 45-minute peak rounds to a 0-60 axis in steps of 10, so the top
        // gridline sits on a round number rather than on the tallest bar.
        expect(find.text('0'), findsOneWidget);
        expect(find.text('30'), findsOneWidget);
        expect(find.text('60'), findsOneWidget);
        // The top label needs a rule of its own: gridlines are not drawn at
        // maxY, so without a top border the axis ends in mid-air.
        final chart = tester.widget<BarChart>(find.byType(BarChart));
        expect(chart.data.borderData.border.top.style, BorderStyle.solid);
        expect(chart.data.gridData.horizontalInterval, 10);
        // Day headings for the two days that have entries, and not the others.
        expect(find.text('Mon Jul 6'), findsOneWidget);
        expect(find.text('Wed Jul 8'), findsOneWidget);
        expect(find.text('Tue Jul 7'), findsNothing);
      });
    });

    testWidgets('every category gets a daily breakdown, not just sleep',
        (tester) async {
      for (final category in ActivityCategory.values) {
        await repo.log(
          category: category,
          value: 5,
          occurredAt: DateTime(2026, 7, 7, 10),
        );
      }

      await withDashboard(tester, () async {
        for (final category in ActivityCategory.values) {
          await tester.tap(find.text(category.label));
          await tester.pumpAndSettle();
          expect(find.byType(CategoryDetailSheet), findsOneWidget,
              reason: '${category.label} should open a breakdown');
          expect(find.text('Tue Jul 7'), findsOneWidget);
          await tester.tapAt(const Offset(500, 20));
          await tester.pumpAndSettle();
        }
      });
    });

    test('daily totals align to the days of the week', () async {
      await repo.log(
        category: ActivityCategory.nature,
        value: 30,
        occurredAt: DateTime(2026, 7, 6, 9),
      );
      await repo.log(
        category: ActivityCategory.nature,
        value: 15,
        occurredAt: DateTime(2026, 7, 6, 18), // same day, should sum
      );
      await repo.log(
        category: ActivityCategory.nature,
        value: 20,
        occurredAt: DateTime(2026, 7, 10, 9),
      );

      final week = WeekRange.containing(now);
      final entries =
          await repo.watchCategoryEntries(week, ActivityCategory.nature).first;
      expect(MetricsRepository.dailyTotals(week, entries),
          [45.0, 0.0, 0.0, 0.0, 20.0, 0.0, 0.0]);
    });
  });

  group('correcting a mis-logged entry', () {
    testWidgets('an amount can be edited and the score follows',
        (tester) async {
      // The classic slip: 15 minutes added by accident.
      await repo.log(
        category: ActivityCategory.socializing,
        value: 15,
        occurredAt: DateTime(2026, 7, 7, 19),
      );

      await withDashboard(tester, () async {
        await tester.tap(find.text('Socializing'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.edit_outlined).first);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).last, '3');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        final rows = await db.select(db.dailyEntries).get();
        expect(rows, hasLength(1));
        expect(rows.single.value, 3);
      });
    });

    testWidgets('an entry can be deleted outright', (tester) async {
      await repo.log(
        category: ActivityCategory.resistance,
        value: 15,
        occurredAt: DateTime(2026, 7, 7, 8),
      );

      await withDashboard(tester, () async {
        await tester.tap(find.text('Resistance Training'));
        await tester.pumpAndSettle();

        expect(await db.select(db.dailyEntries).get(), hasLength(1));
        await tester.tap(find.byIcon(Icons.delete_outline).first);
        await tester.pumpAndSettle();

        expect(await db.select(db.dailyEntries).get(), isEmpty);
        expect(
            find.text('Nothing logged for this category yet.'), findsOneWidget);
      });
    });

    testWidgets('cancelling an edit changes nothing', (tester) async {
      await repo.log(
        category: ActivityCategory.flexibility,
        value: 20,
        occurredAt: DateTime(2026, 7, 7, 8),
      );

      await withDashboard(tester, () async {
        await tester.tap(find.text('Flexibility / Balance'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.edit_outlined).first);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).last, '99');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect((await db.select(db.dailyEntries).get()).single.value, 20);
      });
    });

    testWidgets('a zero or empty amount cannot be saved', (tester) async {
      await repo.log(
        category: ActivityCategory.nature,
        value: 30,
        occurredAt: DateTime(2026, 7, 7, 8),
      );

      await withDashboard(tester, () async {
        await tester.tap(find.text('Time in Nature'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.edit_outlined).first);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).last, '0');
        await tester.pumpAndSettle();
        final save = tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'));
        expect(save.onPressed, isNull);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      });
    });
  });

  group('ring projection toggle', () {
    ScoreRing ringOf(WidgetTester tester) =>
        tester.widget<ScoreRing>(find.byType(ScoreRing));

    testWidgets('switches between pace and banked, and persists the choice',
        (tester) async {
      // Three days of on-pace socializing: 500/1690 on pace, 3/7 of that
      // banked.
      for (var d = 6; d <= 8; d++) {
        await repo.log(
          category: ActivityCategory.socializing,
          value: 3,
          occurredAt: DateTime(2026, 7, d, 19),
        );
      }

      await withDashboard(tester, () async {
        expect(ringOf(tester).caption, startsWith('On pace'));
        expect(find.text('30%'), findsOneWidget);
        expect(find.text('13% banked'), findsOneWidget);

        await tester.tap(find.byType(ScoreRing));
        await tester.pumpAndSettle();

        expect(ringOf(tester).caption, startsWith('Banked'));
        expect(find.text('13%'), findsOneWidget);
        expect(find.text('30% on pace'), findsOneWidget);
        // Persisted, not just held in the widget.
        expect((await db.loadSettings()).ringShowsPace, isFalse);
      });
    });

    testWidgets('a stored preference is honoured on launch', (tester) async {
      await db.setRingShowsPace(false);
      await repo.log(
        category: ActivityCategory.socializing,
        value: 21,
        occurredAt: DateTime(2026, 7, 7, 19),
      );

      await withDashboard(tester, () async {
        expect(ringOf(tester).caption, startsWith('Banked'));
      });
    });
  });

  group('logging from the detail sheet', () {
    testWidgets('shows an input for this category only', (tester) async {
      await withSheet(tester, ActivityCategory.sleep, () async {
        // One text box, not one per category as on the main log sheet.
        expect(find.byType(TextField), findsOneWidget);
        // Sleep's own presets and unit, not another category's.
        expect(find.widgetWithText(ActionChip, '7h'), findsOneWidget);
        expect(find.widgetWithText(ActionChip, '9h'), findsOneWidget);
        expect(find.widgetWithText(ActionChip, '+15m'), findsNothing);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.decoration!.suffixText, 'h');
      });
    });

    testWidgets('a typed amount is logged to this category', (tester) async {
      await withSheet(tester, ActivityCategory.sleep, () async {
        await tester.enterText(find.byType(TextField), '7.5');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
        await tester.pumpAndSettle();

        final entries = await db.select(db.dailyEntries).get();
        expect(entries.where((e) => e.category == ActivityCategory.sleep),
            hasLength(1));
        expect(
          entries.firstWhere((e) => e.category == ActivityCategory.sleep).value,
          7.5,
        );
      });
    });

    testWidgets('a preset logs and the list updates in place', (tester) async {
      await withSheet(tester, ActivityCategory.moderatePA, () async {
        final before = (await db.select(db.dailyEntries).get()).length;
        await tester.tap(find.widgetWithText(ActionChip, '+30m'));
        await tester.pumpAndSettle();

        expect(await db.select(db.dailyEntries).get(), hasLength(before + 1));
        // The new entry appears in the day list without leaving the sheet.
        expect(find.text('30 min'), findsWidgets);
      });
    });
  });
}
