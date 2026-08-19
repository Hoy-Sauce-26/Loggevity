import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens the on-device database file.
///
/// This is the single seam where encryption-at-rest will be introduced: §1 of
/// the plan calls for an encrypted store, which means swapping [NativeDatabase]
/// for a SQLCipher-backed executor and sourcing the key from the platform
/// keychain. That needs the native platform directories, which this project
/// does not have yet, so the file is currently unencrypted. Nothing outside
/// this function needs to change when it lands.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'loggevity.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
