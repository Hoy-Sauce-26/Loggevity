import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Length of the database key in bytes. SQLCipher uses 256-bit keys.
const int kDatabaseKeyBytes = 32;

/// Name the key is filed under in the platform keychain.
const String kDatabaseKeyName = 'loggevity.database.key';

/// Generates a fresh random key, hex encoded.
///
/// Hex rather than a passphrase because it is handed to SQLCipher as a raw
/// key (`PRAGMA key = "x'...'"`), skipping the PBKDF2 derivation a passphrase
/// would go through - there is no human-memorable secret here to stretch.
String generateDatabaseKey([Random? random]) {
  final rng = random ?? Random.secure();
  return [
    for (var i = 0; i < kDatabaseKeyBytes; i++)
      rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

bool isValidDatabaseKey(String key) {
  if (key.length != kDatabaseKeyBytes * 2) return false;
  return RegExp(r'^[0-9a-f]+$').hasMatch(key);
}

/// Thrown when the database file exists but its key does not.
///
/// Generating a replacement key here would produce a database that cannot be
/// opened and would silently discard the user's history, so this is surfaced
/// instead. With no account and no backend there is no recovery path: the key
/// only ever lived in this device's keychain.
class MissingDatabaseKeyException implements Exception {
  const MissingDatabaseKeyException(this.databasePath);

  final String databasePath;

  @override
  String toString() =>
      'MissingDatabaseKeyException: an encrypted database exists at '
      '$databasePath but its key is not in the keychain. The data cannot be '
      'decrypted. Deleting the database file will start a fresh one.';
}

/// Minimal secure key/value abstraction, so key handling is testable without
/// a platform keychain.
abstract interface class SecureKeyValueStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
}

class KeychainStore implements SecureKeyValueStore {
  KeychainStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              // Back the store with Android's EncryptedSharedPreferences
              // rather than plain SharedPreferences.
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> write(String name, String value) =>
      _storage.write(key: name, value: value);
}

/// Loads the database key from the keychain, minting one on first run.
class DatabaseKeyManager {
  const DatabaseKeyManager(this._store);

  final SecureKeyValueStore _store;

  /// The stored key, or null if this device has never created one.
  ///
  /// A stored value that is not a well-formed key is treated as absent rather
  /// than passed to SQLCipher, where it would fail far less legibly.
  Future<String?> read() async {
    final stored = await _store.read(kDatabaseKeyName);
    if (stored == null || !isValidDatabaseKey(stored)) return null;
    return stored;
  }

  Future<String> create() async {
    final key = generateDatabaseKey();
    await _store.write(kDatabaseKeyName, key);
    return key;
  }

  /// Returns the existing key, or creates one when [databaseExists] is false.
  ///
  /// Throws [MissingDatabaseKeyException] when a database is present without
  /// its key, rather than minting a new one on top of undecryptable data.
  Future<String> resolve({
    required bool databaseExists,
    required String databasePath,
  }) async {
    final existing = await read();
    if (existing != null) return existing;
    if (databaseExists) throw MissingDatabaseKeyException(databasePath);
    return create();
  }
}
