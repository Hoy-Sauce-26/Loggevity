import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:loggevity/data/database_key.dart';

/// In-memory stand-in for the platform keychain.
class FakeSecureStore implements SecureKeyValueStore {
  final Map<String, String> values = {};
  int writes = 0;

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<void> write(String name, String value) async {
    writes++;
    values[name] = value;
  }
}

void main() {
  group('key generation', () {
    test('produces 256 bits as 64 lowercase hex characters', () {
      final key = generateDatabaseKey();
      expect(key, hasLength(64));
      expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(isValidDatabaseKey(key), isTrue);
    });

    test('does not repeat itself', () {
      final keys = {for (var i = 0; i < 200; i++) generateDatabaseKey()};
      expect(keys, hasLength(200));
    });

    test('covers the full byte range, including leading zeros', () {
      // A seeded generator that always yields 0 must still produce 32 zero
      // bytes rather than a short string - padding bugs here would silently
      // shorten the key.
      final key = generateDatabaseKey(_ConstantRandom(0));
      expect(key, '0' * 64);
      expect(isValidDatabaseKey(key), isTrue);
    });

    test('rejects malformed keys', () {
      expect(isValidDatabaseKey(''), isFalse);
      expect(isValidDatabaseKey('abc'), isFalse);
      expect(isValidDatabaseKey('g' * 64), isFalse);
      expect(isValidDatabaseKey('A' * 64), isFalse); // uppercase
      expect(isValidDatabaseKey('a' * 63), isFalse);
      expect(isValidDatabaseKey('a' * 65), isFalse);
    });
  });

  group('DatabaseKeyManager', () {
    late FakeSecureStore store;
    late DatabaseKeyManager manager;

    setUp(() {
      store = FakeSecureStore();
      manager = DatabaseKeyManager(store);
    });

    test('mints a key on first run and files it in the keychain', () async {
      expect(await manager.read(), isNull);

      final key = await manager.resolve(
          databaseExists: false, databasePath: '/tmp/x.sqlite');

      expect(isValidDatabaseKey(key), isTrue);
      expect(store.values[kDatabaseKeyName], key);
    });

    test('reuses the stored key on later runs', () async {
      final first = await manager.resolve(
          databaseExists: false, databasePath: '/tmp/x.sqlite');
      final second = await manager.resolve(
          databaseExists: true, databasePath: '/tmp/x.sqlite');

      expect(second, first);
      expect(store.writes, 1, reason: 'must not re-key an existing database');
    });

    test('refuses to mint a new key over an existing database', () async {
      // The data-loss case: a database on disk with no key in the keychain.
      // Generating a replacement would leave the file permanently unreadable.
      expect(
        () => manager.resolve(
            databaseExists: true, databasePath: '/tmp/loggevity.sqlite'),
        throwsA(isA<MissingDatabaseKeyException>()),
      );
      expect(store.writes, 0);
    });

    test('the missing-key error names the file and the way out', () async {
      final message =
          const MissingDatabaseKeyException('/tmp/loggevity.sqlite').toString();
      expect(message, contains('/tmp/loggevity.sqlite'));
      expect(message, contains('Deleting the database file'));
    });

    test('treats a corrupted stored value as no key at all', () async {
      store.values[kDatabaseKeyName] = 'not-a-key';
      expect(await manager.read(), isNull);

      // Still refuses to overwrite a database it cannot decrypt.
      expect(
        () => manager.resolve(
            databaseExists: true, databasePath: '/tmp/x.sqlite'),
        throwsA(isA<MissingDatabaseKeyException>()),
      );
    });

    test('replaces a corrupted value when there is no database yet', () async {
      store.values[kDatabaseKeyName] = 'not-a-key';
      final key = await manager.resolve(
          databaseExists: false, databasePath: '/tmp/x.sqlite');
      expect(isValidDatabaseKey(key), isTrue);
      expect(store.values[kDatabaseKeyName], key);
    });
  });
}

class _ConstantRandom implements Random {
  _ConstantRandom(this.value);
  final int value;

  @override
  int nextInt(int max) => value;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}
