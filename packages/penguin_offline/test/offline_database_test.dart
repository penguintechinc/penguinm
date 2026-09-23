import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:penguin_offline/src/offline_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// The same channel `path_provider`'s `MethodChannelPathProvider` uses
/// internally. Mocking it here (rather than depending on
/// `path_provider_platform_interface`, which this package doesn't declare
/// directly) lets [openAppDatabase] run for real under `flutter_test`,
/// which has no platform implementation of its own.
const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  group('OfflineDatabase.inMemory', () {
    late OfflineDatabase db;

    setUp(() => db = OfflineDatabase.inMemory());
    tearDown(() => db.close());

    test('migrates a fresh database straight to schema version 2', () {
      final rows = db.select('PRAGMA user_version');
      expect(rows.first['user_version'], 2);
    });

    test('creates cache_entries, pending_writes, and dead_letters tables', () {
      final tables = db
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toSet();
      expect(
        tables,
        containsAll(<String>[
          'cache_entries',
          'pending_writes',
          'dead_letters',
        ]),
      );
    });

    test('reopening an in-memory database does not error on re-migration', () {
      // Simulates the guard in _migrate: userVersion already >= 2, so the
      // CREATE TABLE statements must not run again.
      expect(() => db.execute('PRAGMA user_version = 2'), returnsNormally);
    });

    test('execute/select bind parameters instead of interpolating them', () {
      // A value containing SQL metacharacters must be stored and returned
      // verbatim, never executed as SQL.
      const maliciousJson = "'); DROP TABLE cache_entries; --";
      db.execute(
        'INSERT INTO cache_entries (collection, id, json, fetched_at) VALUES (?, ?, ?, ?)',
        ['users', 'u1', maliciousJson, 1000],
      );

      final rows = db.select(
        'SELECT json FROM cache_entries WHERE collection = ? AND id = ?',
        ['users', 'u1'],
      );
      expect(rows, hasLength(1));
      expect(rows.first['json'], maliciousJson);

      // The table must still exist — the payload was never executed as SQL.
      final tables = db
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toSet();
      expect(tables, contains('cache_entries'));
    });

    test('select returns no rows for a miss', () {
      final rows = db.select(
        'SELECT * FROM cache_entries WHERE collection = ? AND id = ?',
        ['missing', 'missing'],
      );
      expect(rows, isEmpty);
    });

    test('lastInsertRowId advances after an insert into a rowid table', () {
      final before = db.lastInsertRowId;
      db.execute(
        '''
        INSERT INTO pending_writes (id, created_at, method, path, attempts)
        VALUES (?, ?, ?, ?, ?)
        ''',
        ['w1', 1000, 'POST', '/x', 0],
      );
      expect(db.lastInsertRowId, isNot(before));
    });

    test('transaction() commits every statement when action succeeds', () {
      db.transaction(() {
        db.execute(
          'INSERT INTO cache_entries (collection, id, json, fetched_at) VALUES (?, ?, ?, ?)',
          ['users', 'u1', '{}', 0],
        );
        db.execute(
          'INSERT INTO cache_entries (collection, id, json, fetched_at) VALUES (?, ?, ?, ?)',
          ['users', 'u2', '{}', 0],
        );
      });

      expect(db.select('SELECT * FROM cache_entries'), hasLength(2));
    });

    test('transaction() rolls back every statement when action throws', () {
      expect(
        () => db.transaction(() {
          db.execute(
            'INSERT INTO cache_entries (collection, id, json, fetched_at) VALUES (?, ?, ?, ?)',
            ['users', 'u1', '{}', 0],
          );
          throw StateError('boom');
        }),
        throwsStateError,
      );

      // The insert above must not have survived the rollback.
      expect(db.select('SELECT * FROM cache_entries'), isEmpty);
    });

    test('close() is safe to call and further use throws', () {
      db.close();
      expect(() => db.select('SELECT 1'), throwsA(anything));
      // Re-assign so tearDown's db.close() doesn't double-close.
      db = OfflineDatabase.inMemory();
    });

    test('a nested transaction() rolls back only its own savepoint, preserving '
        'the outer transaction\'s writes', () {
      db.transaction(() {
        db.execute(
          'INSERT INTO cache_entries (collection, id, json, fetched_at) VALUES (?, ?, ?, ?)',
          ['users', 'outer', '{}', 0],
        );

        // The nested call must not raise SQLite's "cannot start a
        // transaction within a transaction" error (a second BEGIN) and
        // must not abort the outer BEGIN — only its own SAVEPOINT.
        expect(
          () => db.transaction(() {
            db.execute(
              'INSERT INTO cache_entries (collection, id, json, fetched_at) VALUES (?, ?, ?, ?)',
              ['users', 'inner', '{}', 0],
            );
            throw StateError('inner boom');
          }),
          throwsStateError,
        );

        // Still mid-outer-transaction: the outer write must have
        // survived the inner rollback, and the inner write must be gone.
        expect(
          db
              .select('SELECT id FROM cache_entries ORDER BY id')
              .map((r) => r['id'] as String),
          ['outer'],
        );
      });

      // After the outer transaction commits, only its own write persists.
      expect(
        db
            .select('SELECT id FROM cache_entries ORDER BY id')
            .map((r) => r['id'] as String),
        ['outer'],
      );
    });

    test('the outer transaction rolling back also undoes a nested '
        'transaction\'s already-released savepoint', () {
      expect(
        () => db.transaction(() {
          db.execute(
            'INSERT INTO cache_entries (collection, id, json, fetched_at) VALUES (?, ?, ?, ?)',
            ['users', 'outer', '{}', 0],
          );
          db.transaction(() {
            db.execute(
              'INSERT INTO cache_entries (collection, id, json, fetched_at) VALUES (?, ?, ?, ?)',
              ['users', 'inner', '{}', 0],
            );
          });
          // The nested transaction released its savepoint successfully,
          // but the outer transaction now fails — both writes must be
          // undone, since a released savepoint is not a commit.
          throw StateError('outer boom');
        }),
        throwsStateError,
      );

      expect(db.select('SELECT * FROM cache_entries'), isEmpty);
    });
  });

  group('OfflineDatabase.open (file-backed)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('penguin_offline_db_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('data written before close() is readable after reopening the same file', () {
      final path = p.join(tempDir.path, 'offline.sqlite');

      final first = OfflineDatabase.open(path);
      first.execute(
        'INSERT INTO cache_entries (collection, id, json, fetched_at) VALUES (?, ?, ?, ?)',
        ['users', 'u1', '{"name":"Alice"}', 1000],
      );
      first.execute(
        '''
        INSERT INTO pending_writes (id, created_at, method, path, body, idempotency_key, attempts, last_error)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        ['w1', 2000, 'POST', '/users', '{"name":"Bob"}', 'idem-1', 0, null],
      );
      first.close();

      final reopened = OfflineDatabase.open(path);
      final cacheRows = reopened.select(
        'SELECT json, fetched_at FROM cache_entries WHERE collection = ? AND id = ?',
        ['users', 'u1'],
      );
      expect(cacheRows, hasLength(1));
      expect(cacheRows.first['json'], '{"name":"Alice"}');
      expect(cacheRows.first['fetched_at'], 1000);

      final pendingRows = reopened.select(
        'SELECT method, path, body, idempotency_key, attempts FROM pending_writes WHERE id = ?',
        ['w1'],
      );
      expect(pendingRows, hasLength(1));
      expect(pendingRows.first['method'], 'POST');
      expect(pendingRows.first['path'], '/users');
      expect(pendingRows.first['idempotency_key'], 'idem-1');

      reopened.close();
    });

    test(
      'schema migration persists — reopening does not re-run CREATE TABLE',
      () {
        final path = p.join(tempDir.path, 'offline2.sqlite');

        final first = OfflineDatabase.open(path);
        expect(first.select('PRAGMA user_version').first['user_version'], 2);
        first.close();

        final reopened = OfflineDatabase.open(path);
        expect(reopened.select('PRAGMA user_version').first['user_version'], 2);
        // Should not throw even though the tables already exist.
        expect(
          () => reopened.execute(
            'INSERT INTO cache_entries (collection, id, json, fetched_at) VALUES (?, ?, ?, ?)',
            ['c', 'i', '{}', 0],
          ),
          returnsNormally,
        );
        reopened.close();
      },
    );

    test(
      'v1 -> v2 migration on a file-backed database preserves existing pending writes',
      () {
        final path = p.join(tempDir.path, 'v1_upgrade.sqlite');

        // Build a v1-shaped database by hand (bypassing OfflineDatabase, which
        // always migrates straight to the latest version) to simulate an app
        // upgrading from before dead_letters existed.
        final raw = sqlite.sqlite3.open(path);
        raw.execute('''
        CREATE TABLE cache_entries (
          collection TEXT NOT NULL,
          id TEXT NOT NULL,
          json TEXT NOT NULL,
          fetched_at INTEGER NOT NULL,
          PRIMARY KEY (collection, id)
        )
      ''');
        raw.execute('''
        CREATE TABLE pending_writes (
          id TEXT PRIMARY KEY,
          created_at INTEGER NOT NULL,
          method TEXT NOT NULL,
          path TEXT NOT NULL,
          body TEXT,
          idempotency_key TEXT,
          attempts INTEGER NOT NULL DEFAULT 0,
          last_error TEXT
        )
      ''');
        raw.execute(
          '''
        INSERT INTO pending_writes (id, created_at, method, path, body, idempotency_key, attempts, last_error)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
          [
            'pre-existing',
            500,
            'POST',
            '/legacy',
            '{"a":1}',
            'idem-legacy',
            0,
            null,
          ],
        );
        raw.userVersion = 1;
        raw.close();

        // Reopening through OfflineDatabase must upgrade v1 -> v2 without
        // touching the pre-existing row.
        final upgraded = OfflineDatabase.open(path);
        expect(upgraded.select('PRAGMA user_version').first['user_version'], 2);

        final tables = upgraded
            .select("SELECT name FROM sqlite_master WHERE type = 'table'")
            .map((r) => r['name'] as String)
            .toSet();
        expect(tables, contains('dead_letters'));

        final preserved = upgraded.select(
          'SELECT * FROM pending_writes WHERE id = ?',
          ['pre-existing'],
        );
        expect(preserved, hasLength(1));
        expect(preserved.first['method'], 'POST');
        expect(preserved.first['path'], '/legacy');
        expect(preserved.first['idempotency_key'], 'idem-legacy');

        upgraded.close();
      },
    );

    test('a migration step that throws leaves the schema version unadvanced '
        'and the DB unchanged', () {
      final path = p.join(tempDir.path, 'migration_failure.sqlite');

      // Sabotage the v0 -> v1 step's SECOND statement by pre-creating an
      // index named `pending_writes` — SQLite's `IF NOT EXISTS` only
      // no-ops past an existing table/view of the same name, not an
      // index, so the migration's own
      // `CREATE TABLE IF NOT EXISTS pending_writes` genuinely throws,
      // immediately after its `cache_entries` statement has already run.
      // A migration that isn't wrapped in its own transaction would
      // leave `cache_entries` behind despite `user_version` staying at
      // 0 — the exact partial-apply this fix prevents.
      final raw = sqlite.sqlite3.open(path);
      raw.execute('CREATE TABLE decoy (id INTEGER)');
      raw.execute('CREATE INDEX pending_writes ON decoy (id)');
      raw.close();

      expect(
        () => OfflineDatabase.open(path),
        throwsA(isA<sqlite.SqliteException>()),
      );

      // OfflineDatabase.open's constructor never returned a usable
      // instance, so reopen the file directly to inspect what persisted.
      final verify = sqlite.sqlite3.open(path);
      expect(verify.select('PRAGMA user_version').first['user_version'], 0);
      final tables = verify
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((r) => r['name'] as String)
          .toSet();
      expect(
        tables,
        isNot(contains('cache_entries')),
        reason:
            'the cache_entries CREATE TABLE that ran before the failing '
            'pending_writes statement must be rolled back with it',
      );
      expect(tables, contains('decoy'));
      verify.close();
    });

    test('deletes made before close() are absent after reopening', () {
      final path = p.join(tempDir.path, 'offline3.sqlite');

      final first = OfflineDatabase.open(path);
      first.execute(
        'INSERT INTO cache_entries (collection, id, json, fetched_at) VALUES (?, ?, ?, ?)',
        ['users', 'u1', '{}', 0],
      );
      first.execute(
        'DELETE FROM cache_entries WHERE collection = ? AND id = ?',
        ['users', 'u1'],
      );
      first.close();

      final reopened = OfflineDatabase.open(path);
      expect(
        reopened.select(
          'SELECT * FROM cache_entries WHERE collection = ? AND id = ?',
          ['users', 'u1'],
        ),
        isEmpty,
      );
      reopened.close();
    });
  });

  group('openAppDatabase', () {
    late Directory tempDir;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      tempDir = Directory.systemTemp.createTempSync(
        'penguin_offline_app_db_test_',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            _pathProviderChannel,
            (call) async => call.method == 'getApplicationSupportDirectory'
                ? tempDir.path
                : null,
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathProviderChannel, null);
      tempDir.deleteSync(recursive: true);
    });

    test(
      'creates penguin_offline/ under the support dir and opens <productKey>.sqlite there',
      () async {
        final db = await openAppDatabase(productKey: 'myproduct');
        expect(db.select('PRAGMA user_version').first['user_version'], 2);
        db.close();

        final dbFile = File(
          p.join(tempDir.path, 'penguin_offline', 'myproduct.sqlite'),
        );
        expect(dbFile.existsSync(), isTrue);
      },
    );

    test(
      'reuses the penguin_offline directory on a second call rather than failing',
      () async {
        final first = await openAppDatabase(productKey: 'a');
        first.close();
        final second = await openAppDatabase(productKey: 'b');
        second.close();

        expect(
          File(
            p.join(tempDir.path, 'penguin_offline', 'a.sqlite'),
          ).existsSync(),
          isTrue,
        );
        expect(
          File(
            p.join(tempDir.path, 'penguin_offline', 'b.sqlite'),
          ).existsSync(),
          isTrue,
        );
      },
    );
  });
}
