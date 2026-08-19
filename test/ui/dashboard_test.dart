import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggevity/data/database.dart';
import 'package:loggevity/data/metrics_repository.dart';
import 'package:loggevity/providers.dart';
import 'package:loggevity/screens/dashboard_page.dart';
import 'package:loggevity/scoring/scoring.dart';
import 'package:loggevity/widgets/category_progress_tile.dart';
import 'package:loggevity/widgets/quick_log_sheet.dart';
import 'package:loggevity/widgets/score_ring.dart';

void main() {
  late AppDatabase db;
  late MetricsRepository repo;
  // Wednesday of Baseline Week 1, so three of seven days have elapsed.
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

  /// Mounts the dashboard, runs [body], then unmounts cleanly.
  ///
  /// The surface is deliberately tall so the whole page lays out at once and
  /// finders don't miss widgets a phone viewport would push below the fold.
  ///
  /// Unmounting inside the test body is load-bearing: disposing the
  /// ProviderScope cancels the drift query streams, and drift defers their
  /// cleanup to a zero-duration timer. The framework checks for pending timers
  /// as soon as the body returns - before any addTearDown runs - so the tree
  /// has to come down while there are still pumps available to flush it.
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

    // One bounded pump, never pumpAndSettle: settling here would keep
    // pumping for as long as frames stay scheduled, and the teardown of the
    // drift streams keeps rescheduling them. A single timed pump is enough to
    // fire the zero-duration timer and is guaranteed to terminate.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  }

  group('dashboard', () {
    testWidgets('an empty week shows a zero ring and every category',
        (tester) async {
      await withDashboard(tester, () async {
        expect(find.byType(ScoreRing), findsOneWidget);
        expect(find.text('0%'), findsOneWidget);
        expect(find.text('Nothing logged yet this week.'), findsOneWidget);
        expect(find.byType(CategoryProgressTile), findsNWidgets(7));
        for (final c in ActivityCategory.values) {
          expect(find.text(c.label), findsOneWidget);
        }
      });
    });

    testWidgets('shows the pace caption and the week range', (tester) async {
      await withDashboard(tester, () async {
        expect(find.text('On pace · day 3 of 7'), findsOneWidget);
        expect(find.text('Jul 6 – 12'), findsOneWidget);
      });
    });

    testWidgets('a log updates the ring with no manual refresh',
        (tester) async {
      await withDashboard(tester, () async {
        expect(find.text('0%'), findsOneWidget);

        // Three days of on-pace socializing, worth 500/1690 of the composite.
        for (var d = 6; d <= 8; d++) {
          await repo.log(
            category: ActivityCategory.socializing,
            value: 3,
            occurredAt: DateTime(2026, 7, d, 19),
          );
        }
        await tester.pumpAndSettle();

        expect(find.text('30%'), findsOneWidget);
        expect(find.text('9h'), findsOneWidget);
      });
    });

    testWidgets('renders a negative score without drawing backwards',
        (tester) async {
      // Three nights of no sleep at all: the sleep sub-score bottoms at -10.
      for (var d = 6; d <= 8; d++) {
        await repo.log(
          category: ActivityCategory.sleep,
          value: 0,
          occurredAt: DateTime(2026, 7, d, 7),
        );
      }

      await withDashboard(tester, () async {
        expect(find.text('-20%'), findsOneWidget);
        expect(
          tester.widget<ScoreRing>(find.byType(ScoreRing)).percent,
          lessThan(0),
        );
        final indicator = tester.widget<CircularProgressIndicator>(
          find.descendant(
            of: find.byType(ScoreRing),
            matching: find.byType(CircularProgressIndicator),
          ),
        );
        expect(indicator.value, 0.0);
      });
    });
  });

  group('quick log sheet', () {
    testWidgets('opens from the FAB and offers every category', (tester) async {
      await withDashboard(tester, () async {
        await tester.tap(find.text('Log'));
        await tester.pumpAndSettle();

        expect(find.byType(QuickLogSheet), findsOneWidget);
        expect(find.text('Log activity'), findsOneWidget);
        expect(find.widgetWithText(ActionChip, '+15m'), findsWidgets);
        expect(find.widgetWithText(ActionChip, '8h'), findsOneWidget);
        // A text box per category, for anything the presets do not cover.
        expect(find.byType(TextField), findsNWidgets(7));

        await tester.tapAt(const Offset(500, 30)); // dismiss the sheet
        await tester.pumpAndSettle();
      });
    });

    testWidgets('one tap logs, and the sheet stays open', (tester) async {
      await withDashboard(tester, () async {
        await tester.tap(find.text('Log'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ActionChip, '+30m').first);
        await tester.pumpAndSettle();

        final entries = await db.select(db.dailyEntries).get();
        expect(entries, hasLength(1));
        expect(entries.single.category, ActivityCategory.moderatePA);
        expect(entries.single.value, 30);
        expect(entries.single.localDate, '2026-07-08');
        expect(find.byType(QuickLogSheet), findsOneWidget);

        await tester.tapAt(const Offset(500, 30));
        await tester.pumpAndSettle();
      });
    });

    testWidgets('undo removes the entry it just created', (tester) async {
      await withDashboard(tester, () async {
        await tester.tap(find.text('Log'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ActionChip, '+30m').first);
        await tester.pumpAndSettle();
        expect(await db.select(db.dailyEntries).get(), hasLength(1));

        // Undo must be reachable while the sheet is still open: a SnackBar
        // would sit behind the sheet's modal barrier and never receive the tap.
        expect(find.text('Added Moderate Activity +30m'), findsOneWidget);
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect(await db.select(db.dailyEntries).get(), isEmpty);
        expect(find.text('Undo'), findsNothing);

        await tester.tapAt(const Offset(500, 30));
        await tester.pumpAndSettle();
      });
    });

    testWidgets('a typed amount is logged in the category\'s own unit',
        (tester) async {
      await withDashboard(tester, () async {
        await tester.tap(find.text('Log'));
        await tester.pumpAndSettle();

        // Fourth field is Flexibility (minutes); last is Sleep (hours).
        await tester.enterText(find.byType(TextField).at(3), '25');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithIcon(IconButton, Icons.add).at(3));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).at(6), '7.5');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithIcon(IconButton, Icons.add).at(6));
        await tester.pumpAndSettle();

        final entries = await db.select(db.dailyEntries).get();
        expect(entries, hasLength(2));
        expect(entries.first.category, ActivityCategory.flexibility);
        expect(entries.first.value, 25);
        expect(entries.last.category, ActivityCategory.sleep);
        expect(entries.last.value, 7.5);
        expect(find.text('Added Sleep 7.5h'), findsOneWidget);

        await tester.tapAt(const Offset(500, 30));
        await tester.pumpAndSettle();
      });
    });

    testWidgets('rejects empty and non-positive input', (tester) async {
      await withDashboard(tester, () async {
        await tester.tap(find.text('Log'));
        await tester.pumpAndSettle();

        // Nothing typed: the add button is disabled.
        final button = tester.widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.add).first);
        expect(button.onPressed, isNull);

        await tester.enterText(find.byType(TextField).first, '0');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<IconButton>(
                  find.widgetWithIcon(IconButton, Icons.add).first)
              .onPressed,
          isNull,
        );
        expect(await db.select(db.dailyEntries).get(), isEmpty);

        await tester.tapAt(const Offset(500, 30));
        await tester.pumpAndSettle();
      });
    });

    testWidgets('reflects what has already been logged this week',
        (tester) async {
      await repo.log(
        category: ActivityCategory.sleep,
        value: 8,
        occurredAt: DateTime(2026, 7, 7, 7),
      );

      await withDashboard(tester, () async {
        await tester.tap(find.text('Log'));
        await tester.pumpAndSettle();

        expect(find.text('8h · 1 night'), findsOneWidget);

        await tester.tapAt(const Offset(500, 30));
        await tester.pumpAndSettle();
      });
    });
  });

  group('week start setting', () {
    testWidgets('changing the start day re-buckets the dashboard',
        (tester) async {
      // Sunday 2026-07-05 sits in the previous week under a Monday start, but
      // in the current one under a Sunday start.
      await repo.log(
        category: ActivityCategory.nature,
        value: 90,
        occurredAt: DateTime(2026, 7, 5, 11),
      );

      await withDashboard(tester, () async {
        expect(find.text('Jul 6 – 12'), findsOneWidget);
        expect(find.text('90 min'), findsNothing);

        await tester.tap(find.byIcon(Icons.calendar_today_outlined));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sunday'));
        await tester.pumpAndSettle();

        expect(find.text('Jul 5 – 11'), findsOneWidget);
        expect(find.text('90 min'), findsOneWidget);
      });
    });
  });

  group('adapts to the screen it is given', () {
    ScoreRing ringOf(WidgetTester tester) =>
        tester.widget<ScoreRing>(find.byType(ScoreRing));

    testWidgets('uses the full-size ring when there is room', (tester) async {
      await withDashboard(tester, () async {
        expect(ringOf(tester).diameter, 220);
        expect(find.byType(CategoryProgressTile), findsNWidgets(7));
      }, size: const Size(400, 1000));
    });

    testWidgets('shrinks the ring rather than the category rows',
        (tester) async {
      await withDashboard(tester, () async {
        // The rows are the content that has to survive; the ring gives way.
        expect(ringOf(tester).diameter, lessThan(220));
        expect(ringOf(tester).diameter, greaterThanOrEqualTo(120));
        expect(find.byType(CategoryProgressTile), findsNWidgets(7));
        for (final c in ActivityCategory.values) {
          expect(find.text(c.label), findsOneWidget);
        }
      }, size: const Size(400, 740));
    });

    testWidgets('never shrinks the ring past its floor', (tester) async {
      // Below this the page simply scrolls - the ring stays legible rather
      // than collapsing to nothing.
      await withDashboard(tester, () async {
        expect(ringOf(tester).diameter, 120);
      }, size: const Size(400, 480));
    });

    testWidgets('the log sheet lays out on a short screen without overflowing',
        (tester) async {
      await withDashboard(tester, () async {
        await tester.tap(find.text('Log'));
        await tester.pumpAndSettle();

        expect(find.byType(QuickLogSheet), findsOneWidget);
        expect(find.byType(TextField), findsNWidgets(7));

        await tester.tapAt(const Offset(200, 10));
        await tester.pumpAndSettle();
      }, size: const Size(400, 640));
    });
  });

  group('data portability menu', () {
    testWidgets('offers both export formats and import', (tester) async {
      await withDashboard(tester, () async {
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        expect(find.text('Export as JSON'), findsOneWidget);
        expect(find.text('Export as CSV'), findsOneWidget);
        expect(find.text('Import from file…'), findsOneWidget);

        await tester.tapAt(const Offset(200, 400));
        await tester.pumpAndSettle();
      });
    });
  });
}
