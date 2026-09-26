import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_offline/penguin_offline.dart';

void main() {
  test('exports the connectivity API', () {
    expect(ConnectivityStatus.values, hasLength(3));
    expect(ConnectivityMonitor.new, isNotNull);
    expect(ConnectivityBanner.new, isNotNull);
  });

  test('exports the offline cache API', () {
    expect(OfflineDatabase.inMemory, isNotNull);
    expect(SqliteOfflineStore.new, isNotNull);
    final entry = CachedEntry(
      collection: 'c',
      id: 'i',
      data: const {},
      fetchedAt: DateTime(2026),
    );
    expect(entry.collection, 'c');
    final OfflineStore store = SqliteOfflineStore(OfflineDatabase.inMemory());
    expect(store, isA<OfflineStore>());
  });

  test('exports the sync queue API', () {
    expect(SyncQueue.new, isNotNull);
    expect(const SyncReport(), isA<SyncReport>());
    final write = PendingWrite(
      id: 'w',
      method: 'POST',
      path: '/x',
      createdAt: DateTime(2026),
    );
    expect(write.id, 'w');
  });

  test('exports the widgets and providers', () {
    expect(StaleDataChip.new, isNotNull);
    expect(connectivityProvider, isNotNull);
    expect(offlineStoreProvider, isNotNull);
    expect(syncQueueProvider, isNotNull);
  });
}
