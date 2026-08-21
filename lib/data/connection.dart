import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database_key.dart';

const String kDatabaseFileName = 'loggevity.sqlite';

/// Thrown when the loaded SQLite build is not SQLCipher.
///
/// This is the failure that matters most. On a plain SQLite library
/// `PRAGMA key` is an unrecognised no-op that reports success, so without this
/// check the app would run perfectly while writing every entry to disk in
/// plaintext. Refusing to open is the only safe response.
class DatabaseNotEncryptedException implements Exception {
  const DatabaseNotEncryptedException();

  @override
  String toString() =>
      'DatabaseNotEncryptedException: the loaded SQLite library is not '
      'SQLCipher, so the database would be written unencrypted. Check that '
      'sqlcipher_flutter_libs is installed and that sqlite3_flutter_libs is '
      'not also present - whichever loads first wins.';
}

/// Runs in drift's background isolate before the database is opened.
///
/// Must be a top-level function: it is sent to another isolate, where the
/// main isolate's `open` overrides do not apply.
Future<void> _setUpSqlCipher() async {
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  }
}

/// Applies the key and refuses to continue on a non-SQLCipher library.
///
/// Ordered deliberately: the library is verified *before* the key is set and
/// before any write can happen, so a misconfigured build fails closed rather
/// than leaking a plaintext file.
void applyEncryption(Database db, String key) {
  final cipherVersion = db.select('PRAGMA cipher_version;');
  if (cipherVersion.isEmpty) throw const DatabaseNotEncryptedException();

  // Hex form, so SQLCipher takes these bytes as the raw key instead of
  // running a passphrase through its key derivation.
  db.execute('PRAGMA key = "x\'$key\'";');
}

/// The on-device database file. Its directory may not exist yet.
Future<File> databaseFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, kDatabaseFileName));
}

/// Whether [file] holds real data.
///
/// A zero-length file is not a database - SQLite leaves one behind if it is
/// interrupted before the first page is written, and treating it as existing
/// would strand the app on a [MissingDatabaseKeyException] over a file with
/// nothing in it.
bool holdsData(File file) => file.existsSync() && file.lengthSync() > 0;

/// Deletes the database and its write-ahead sidecars.
///
/// The only escape from a database whose key is gone: without the key the
/// bytes are unreadable by anyone, so the choice is a fresh database or an app
/// that cannot start. Destructive, and never called without the user asking.
Future<void> deleteDatabaseFiles() async {
  final file = await databaseFile();
  for (final path in [file.path, '${file.path}-wal', '${file.path}-shm']) {
    final f = File(path);
    if (f.existsSync()) await f.delete();
  }
}

/// Opens the encrypted on-device database.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final file = await databaseFile();

    final key = await DatabaseKeyManager(KeychainStore()).resolve(
      databaseExists: holdsData(file),
      databasePath: file.path,
    );

    return NativeDatabase.createInBackground(
      file,
      isolateSetup: _setUpSqlCipher,
      // Captures only the key string, which is safe to send across isolates.
      // Every connection drift opens, including its read pool, goes through
      // this - each one needs the key.
      setup: (db) => applyEncryption(db, key),
    );
  });
}
