/// Pure Dart scoring engine for Loggevity.
///
/// Nothing under `lib/scoring/` may import `package:flutter`. This is enforced
/// by `test/scoring/purity_test.dart` so the engine stays runnable, testable
/// and portable independently of the UI.
library;

export 'calculator.dart';
export 'curves.dart';
export 'interpolation.dart';
export 'models.dart';
