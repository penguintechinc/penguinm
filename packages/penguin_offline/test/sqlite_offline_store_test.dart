import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:penguin_offline/src/offline_database.dart';
import 'package:penguin_offline/src/sqlite_offline_store.dart';

void main() {
  group('SqliteOfflineStore (in-memory)', () {
    late OfflineDatabase db;
    late SqliteOfflineStore store;

    setUp(() {
      db = OfflineDatabase.inMemory();
      store = SqliteOfflineStore(db);
    });

    tearDown(() => db.close());

    test('get returns null for a record that was never put', () async {
      expect(await store.get('users', 'missing'), isNull);
    });

    test('put then get round-trips collection/id/data/fetchedAt', () async {
      final fetchedAt = DateTime(2026, 9, 14, 8);
      await store.put('users', 'u1', {
        'name': 'Alice',
        'age': 30,
      }, fetchedAt: fetchedAt);

      final entry = await store.get('users', 'u1');
      expect(entry, isNotNull);
      expect(entry!.collection, 'users');
      expect(entry.id, 'u1');
      expect(entry.data, {'name': 'Alice', 'age': 30});
      expect(entry.fetchedAt, fetchedAt);
    });

    test('put without fetchedAt defaults to approximately now', () async {
      final before = DateTime.now();
      await store.put('users', 'u1', {'name': 'Alice'});
      final after = DateTime.now();

      final entry = await store.get('users', 'u1');
      expect(
        entry!.fetchedAt.isBefore(before.subtract(const Duration(seconds: 2))),
        isFalse,
      );
      expect(
        entry.fetchedAt.isAfter(after.add(const Duration(seconds: 2))),
        isFalse,
      );
    });

    test(
      'put upserts an existing collection/id pair rather than duplicating',
      () async {
        await store.put('users', 'u1', {'name': 'Alice'});
        await store.put('users', 'u1', {'name': 'Alice Updated'});

        final all = await store.list('users');
        expect(all, hasLength(1));
        expect(all.single.data, {'name': 'Alice Updated'});
      },
    );

    test(
      'list returns entries for the requested collection only, ordered by id',
      () async {
        await store.put('users', 'u2', {'name': 'Bob'});
        await store.put('users', 'u1', {'name': 'Alice'});
        await store.put('posts', 'p1', {'title': 'Hello'});

        final users = await store.list('users');
        expect(users.map((e) => e.id).toList(), ['u1', 'u2']);
        expect(users.every((e) => e.collection == 'users'), isTrue);
      },
    );

    test(
      'list returns an empty list for a collection with no entries',
      () async {
        expect(await store.list('nothing'), isEmpty);
      },
    );

    test('remove deletes only the targeted id', () async {
      await store.put('users', 'u1', {'name': 'Alice'});
      await store.put('users', 'u2', {'name': 'Bob'});

      await store.remove('users', 'u1');

      expect(await store.get('users', 'u1'), isNull);
      expect(await store.get('users', 'u2'), isNotNull);
    });

    test('remove on a missing id is a no-op, not an error', () async {
      await store.remove('users', 'missing');
    });

    test(
      'clear deletes every entry in a collection but leaves others intact',
      () async {
        await store.put('users', 'u1', {'name': 'Alice'});
        await store.put('users', 'u2', {'name': 'Bob'});
        await store.put('posts', 'p1', {'title': 'Hello'});

        await store.clear('users');

        expect(await store.list('users'), isEmpty);
        expect(await store.list('posts'), hasLength(1));
      },
    );

    test(
      'data survives a value containing quotes and SQL metacharacters',
      () async {
        await store.put('notes', 'n1', {
          'text': "O'Brien's; DROP TABLE cache_entries; --",
        });
        final entry = await store.get('notes', 'n1');
        expect(entry!.data['text'], "O'Brien's; DROP TABLE cache_entries; --");
      },
    );
  });

  group('SqliteOfflineStore (file-backed persistence)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'penguin_offline_store_test_',
      );
    });

    tearDown(() => tempDir.deleteSync(recursive: true));

    test(
      'entries written before close() are readable through a fresh store after reopening',
      () async {
        final path = p.join(tempDir.path, 'store.sqlite');
        final fetchedAt = DateTime(2026, 9, 14, 9);

        final firstDb = OfflineDatabase.open(path);
        final firstStore = SqliteOfflineStore(firstDb);
        await firstStore.put('users', 'u1', {
          'name': 'Alice',
        }, fetchedAt: fetchedAt);
        firstDb.close();

        final secondDb = OfflineDatabase.open(path);
        final secondStore = SqliteOfflineStore(secondDb);
        final entry = await secondStore.get('users', 'u1');

        expect(entry, isNotNull);
        expect(entry!.data, {'name': 'Alice'});
        expect(entry.fetchedAt, fetchedAt);
        secondDb.close();
      },
    );
  });
}
