import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggevity/data/database.dart';
import 'package:loggevity/data/metrics_repository.dart';
import 'package:loggevity/data/week_sealer.dart';
import 'package:loggevity/providers.dart';
import 'package:loggevity/screens/analytics_page.dart';
import 'package:loggevity/scoring/scoring.dart';
import 'package:loggevity/widgets/charts/category_contribution_chart.dart';
import 'package:loggevity/widgets/charts/score_trend_chart.dart';

void main() {
  late AppDatabase db;
  late MetricsRepository repo;
  late WeekSealer sealer;
  var now = DateTime(2026, 9, 2, 12);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = MetricsRepository(db, clock: () => now);
    sealer = WeekSealer(db, repo);
  });
  tearDown(() => db.close());

  Widget harness() => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          metricsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: AnalyticsPage()),
      );

  Future<void> withAnalytics(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await body();

    // See dashboard_test.dart: the tree has to come down while pumps are
    // still available, so drift's deferred stream close can fire.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  }

  /// Logs [weeks] consecutive weeks of socializing, then seals them.
  Future<void> seedWeeks(int weeks) async {
    for (var w = 0; w < weeks; w++) {
      for (var d = 0; d < 7; d++) {
        await repo.log(
          category: ActivityCategory.socializing,
          value: 3,
          occurredAt: DateTime(2026, 7, 6 + w * 7 + d, 19),
        );
      }
    }
    await sealer.sealCompletedWeeks();
  }

  group('empty states', () {
    testWidgets('invites the user to finish a week first', (tester) async {
      await withAnalytics(tester, () async {
        expect(find.text('Trends appear once your first week is complete.'),
            findsOneWidget);
        expect(find.byType(ScoreTrendChart), findsNothing);
      });
    });
  });

  group('with sealed history', () {
    testWidgets('renders both charts and the legend', (tester) async {
      await seedWeeks(4);
      await withAnalytics(tester, () async {
        expect(find.byType(ScoreTrendChart), findsOneWidget);
        expect(find.byType(CategoryContributionChart), findsOneWidget);
        expect(find.byType(CategoryLegend), findsOneWidget);
        for (final c in ActivityCategory.values) {
          expect(find.text(c.label), findsOneWidget);
        }
      });
    });

    testWidgets('summarises weeks, average and best', (tester) async {
      await seedWeeks(4);
      await withAnalytics(tester, () async {
        expect(find.text('logged'), findsOneWidget);
        expect(find.text('Average'), findsOneWidget);
        expect(find.text('Best'), findsOneWidget);
        // 21h socializing a week is a full 10/10: 500/1690 = 29.6%. The chart
        // axis can also carry a 30% label, so this is not an exact count.
        expect(find.text('30%'), findsWidgets);
      });
    });

    testWidgets('the window selector narrows the range', (tester) async {
      await seedWeeks(8);
      await withAnalytics(tester, () async {
        expect(find.text('8 weeks'), findsOneWidget);

        await tester.tap(find.text('4 weeks'));
        await tester.pumpAndSettle();

        // The stat now reports the narrowed count, not the full history.
        expect(find.text('4 weeks'), findsNWidgets(2)); // segment + stat
        expect(find.text('8 weeks'), findsNothing);
      });
    });

    testWidgets('defaults to the 12-week window', (tester) async {
      // Far enough ahead that all twenty weeks have completed and sealed.
      now = DateTime(2027, 1, 6);
      await seedWeeks(20);
      await withAnalytics(tester, () async {
        expect(find.text('12 weeks'), findsNWidgets(2));
      });
    });
  });

  group('trend data', () {
    testWidgets('passes one point per sealed week, in order', (tester) async {
      await seedWeeks(3);
      await withAnalytics(tester, () async {
        final chart =
            tester.widget<ScoreTrendChart>(find.byType(ScoreTrendChart));
        expect(chart.points, hasLength(3));
        expect(chart.points.first.weekStart, DateTime(2026, 7, 6));
        expect(chart.points.last.weekStart, DateTime(2026, 7, 20));
        expect(chart.points.first.compositePercent, closeTo(29.59, 0.01));
      });
    });

    testWidgets('contribution bars carry weighted points, not sub-scores',
        (tester) async {
      await seedWeeks(1);
      await withAnalytics(tester, () async {
        final chart = tester.widget<CategoryContributionChart>(
            find.byType(CategoryContributionChart));
        final points = chart.weeks.single.pointsByCategory;
        // 10/10 socializing at weight 50 = 500 points.
        expect(points[ActivityCategory.socializing], 500);
        expect(points[ActivityCategory.nature], 0);
      });
    });

    testWidgets('a negative week keeps its sign', (tester) async {
      // A week of zero-hour nights: sleep bottoms out at -10.
      for (var d = 0; d < 7; d++) {
        await repo.log(
          category: ActivityCategory.sleep,
          value: 0,
          occurredAt: DateTime(2026, 7, 6 + d, 7),
        );
      }
      await sealer.sealCompletedWeeks();

      await withAnalytics(tester, () async {
        final chart = tester.widget<CategoryContributionChart>(
            find.byType(CategoryContributionChart));
        expect(chart.weeks.single.pointsByCategory[ActivityCategory.sleep],
            closeTo(-340, 1e-6));

        final trend =
            tester.widget<ScoreTrendChart>(find.byType(ScoreTrendChart));
        expect(trend.points.single.compositePercent, lessThan(0));
      });
    });
  });
}
