import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_offline/src/connectivity_monitor.dart';
import 'package:penguin_offline/src/connectivity_status.dart';
import 'package:penguin_offline/src/offline_database.dart';
import 'package:penguin_offline/src/offline_store.dart';
import 'package:penguin_offline/src/providers.dart';
import 'package:penguin_offline/src/sqlite_offline_store.dart';
import 'package:penguin_offline/src/sync_queue.dart';

import 'support/api_test_support.dart';

PenguinApiClient _fakeApi() => PenguinApiClient(
  config: testAppConfig(),
  tokens: FakeTokenProvider(),
  inner: MockClient((_) async => throw StateError('unused in this test')),
);

void main() {
  test('offlineDatabaseProvider defaults to a usable in-memory database', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final db = container.read(offlineDatabaseProvider);
    expect(db, isA<OfflineDatabase>());
    expect(db.select('PRAGMA user_version').first['user_version'], 2);
  });

  test(
    'offlineStoreProvider builds a SqliteOfflineStore over offlineDatabaseProvider',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final store = container.read(offlineStoreProvider);
      expect(store, isA<OfflineStore>());
      expect(store, isA<SqliteOfflineStore>());

      await store.put('users', 'u1', {'name': 'Alice'});
      expect(await store.get('users', 'u1'), isNotNull);
    },
  );

  test('connectivityMonitorProvider does not start the monitor by itself', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final monitor = container.read(connectivityMonitorProvider);
    expect(monitor, isA<ConnectivityMonitor>());
    expect(monitor.current, ConnectivityStatus.unknown);
  });

  test('connectivityProvider exposes the monitor\'s status stream', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final sub = container.listen(connectivityProvider, (previous, next) {});
    expect(sub.read(), isA<AsyncValue<ConnectivityStatus>>());
  });

  test(
    'syncQueueProvider wires db/connectivity/logger/metrics/api into a SyncQueue',
    () {
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(_fakeApi())],
      );
      addTearDown(container.dispose);

      final queue = container.read(syncQueueProvider);
      expect(queue, isA<SyncQueue>());
    },
  );

  test(
    'reuses penguin_api\'s apiClientProvider rather than declaring a second one',
    () {
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(_fakeApi())],
      );
      addTearDown(container.dispose);

      // syncQueueProvider must build successfully purely from overriding
      // penguin_api's apiClientProvider — proving there is no shadow
      // "apiClientProvider" declared inside penguin_offline that would need
      // its own, separate override.
      expect(() => container.read(syncQueueProvider), returnsNormally);
    },
  );
}
