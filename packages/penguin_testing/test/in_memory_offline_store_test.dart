import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_testing/penguin_testing.dart';

void main() {
  group('InMemoryOfflineStore', () {
    test('get returns null for an absent entry', () async {
      final store = InMemoryOfflineStore();
      expect(await store.get('users', 'user-0001'), isNull);
    });

    test('put then get round-trips the entry', () async {
      final store = InMemoryOfflineStore();
      await store.put('users', 'user-0001', const {'name': 'Penny Waddle'});

      final entry = await store.get('users', 'user-0001');
      expect(entry, isNotNull);
      expect(entry!.collection, 'users');
      expect(entry.id, 'user-0001');
      expect(entry.data, const {'name': 'Penny Waddle'});
    });

    test('put stamps fetchedAt with the injected clock by default', () async {
      final clock = FakeClock(DateTime.utc(2026, 5));
      final store = InMemoryOfflineStore(clock: clock);
      await store.put('users', 'user-0001', const {});
      final entry = await store.get('users', 'user-0001');
      expect(entry!.fetchedAt, DateTime.utc(2026, 5));
    });

    test('put honours an explicit fetchedAt', () async {
      final store = InMemoryOfflineStore();
      final fetchedAt = DateTime.utc(2020);
      await store.put('users', 'user-0001', const {}, fetchedAt: fetchedAt);
      final entry = await store.get('users', 'user-0001');
      expect(entry!.fetchedAt, fetchedAt);
    });

    test('put replaces an existing entry for the same id', () async {
      final store = InMemoryOfflineStore();
      await store.put('users', 'user-0001', const {'v': 1});
      await store.put('users', 'user-0001', const {'v': 2});
      final entry = await store.get('users', 'user-0001');
      expect(entry!.data, const {'v': 2});
    });

    test('list returns every entry in a collection ordered by id', () async {
      final store = InMemoryOfflineStore();
      await store.put('users', 'user-0002', const {});
      await store.put('users', 'user-0001', const {});
      final entries = await store.list('users');
      expect(entries.map((e) => e.id), ['user-0001', 'user-0002']);
    });

    test('list returns empty for an unknown collection', () async {
      final store = InMemoryOfflineStore();
      expect(await store.list('unknown'), isEmpty);
    });

    test('remove deletes a single entry', () async {
      final store = InMemoryOfflineStore();
      await store.put('users', 'user-0001', const {});
      await store.remove('users', 'user-0001');
      expect(await store.get('users', 'user-0001'), isNull);
    });

    test('remove on a missing entry does not throw', () async {
      final store = InMemoryOfflineStore();
      await store.remove('users', 'missing');
    });

    test('clear deletes every entry in a collection', () async {
      final store = InMemoryOfflineStore();
      await store.put('users', 'user-0001', const {});
      await store.put('users', 'user-0002', const {});
      await store.clear('users');
      expect(await store.list('users'), isEmpty);
    });
  });
}
