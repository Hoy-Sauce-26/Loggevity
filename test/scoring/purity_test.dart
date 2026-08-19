import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The scoring engine is the one part of Loggevity that must stay a pure,
/// deterministic Dart library: no Flutter, no I/O, no clock, no platform.
/// Task 1.1 calls for it to be standalone, and keeping it so is what lets the
/// whole model be verified against the source workbook without a device.
void main() {
  test('nothing in lib/scoring imports Flutter or dart:io', () {
    final dir = Directory('lib/scoring');
    expect(dir.existsSync(), isTrue, reason: 'run from the project root');

    final offenders = <String>[];
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('import ') && !trimmed.startsWith('export ')) {
          continue;
        }
        if (trimmed.contains('package:flutter') ||
            trimmed.contains('dart:io') ||
            trimmed.contains('dart:ui')) {
          offenders.add('${file.path}: $trimmed');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
