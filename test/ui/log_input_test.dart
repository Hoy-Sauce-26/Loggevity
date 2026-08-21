import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loggevity/scoring/scoring.dart';
import 'package:loggevity/widgets/category_log_input.dart';

void main() {
  Widget harness(ActivityCategory category) => MaterialApp(
        home: Scaffold(
          body: CategoryLogInput(category: category, onLog: (_, __) {}),
        ),
      );

  testWidgets('the unit hint clears as soon as the field is focused',
      (tester) async {
    await tester.pumpWidget(harness(ActivityCategory.moderatePA));

    // The box is narrow, so hint and suffix sit side by side: leaving the hint
    // up while typing would read as "min min".
    expect(find.text('min'), findsNWidgets(2)); // hint + suffix

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.text('min'), findsOneWidget); // suffix only
  });

  testWidgets('hours categories hint in hours', (tester) async {
    await tester.pumpWidget(harness(ActivityCategory.sleep));
    expect(find.text('hours'), findsOneWidget);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    // Hint gone, and the suffix spells the unit out now that it has the field
    // to itself.
    expect(find.text('h'), findsNothing);
    expect(find.text('hours'), findsOneWidget);
  });
}
