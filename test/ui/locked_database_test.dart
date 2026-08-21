import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggevity/data/connection.dart';
import 'package:loggevity/data/database_key.dart';
import 'package:loggevity/data/metrics_repository.dart';
import 'package:loggevity/providers.dart';
import 'package:loggevity/screens/dashboard_page.dart';
import 'package:loggevity/widgets/locked_database_view.dart';

/// An encrypted database with no key is unrecoverable, so the app has to say
/// so in words the user can act on rather than printing the exception.
void main() {
  test('the key failure is recognised however it is wrapped', () {
    const e = MissingDatabaseKeyException('/tmp/loggevity.sqlite');
    expect(isMissingDatabaseKey(e), isTrue);
    // Drift can re-wrap what its lazy opener throws.
    expect(isMissingDatabaseKey('Bad state: $e'), isTrue);
    expect(isMissingDatabaseKey(Exception('network down')), isFalse);
  });

  test('an empty file is not treated as an existing database', () async {
    final dir = Directory.systemTemp.createTempSync('loggevity_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/loggevity.sqlite');

    expect(holdsData(file), isFalse);
    file.writeAsBytesSync([]);
    expect(holdsData(file), isFalse);
    file.writeAsBytesSync([1, 2, 3]);
    expect(holdsData(file), isTrue);
  });

  Widget lockedHarness() => ProviderScope(
        overrides: [
          currentWeekProvider.overrideWith(
            (ref) => Stream<WeeklyMetrics>.error(
              const MissingDatabaseKeyException('/tmp/loggevity.sqlite'),
            ),
          ),
          sealOnLaunchProvider.overrideWith((ref) async => 0),
        ],
        child: const MaterialApp(home: DashboardPage()),
      );

  testWidgets('a locked database explains itself instead of showing the error',
      (tester) async {
    await tester.pumpWidget(lockedHarness());
    await tester.pumpAndSettle();

    expect(find.byType(LockedDatabaseView), findsOneWidget);
    expect(find.text('This database is locked'), findsOneWidget);
    expect(find.textContaining('MissingDatabaseKeyException'), findsNothing);

    // Nothing to log into, export or chart, so those controls are withheld
    // rather than left to fail on tap.
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Your data'), findsNothing);
    expect(find.byTooltip('Trends'), findsNothing);
  });

  testWidgets('starting fresh asks before deleting anything', (tester) async {
    await tester.pumpWidget(lockedHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start fresh'));
    await tester.pumpAndSettle();

    expect(find.text('Start a fresh database?'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(LockedDatabaseView), findsOneWidget);
  });
}
