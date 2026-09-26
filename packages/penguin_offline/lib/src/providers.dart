import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';

import 'connectivity_monitor.dart';
import 'connectivity_status.dart';
import 'offline_database.dart';
import 'offline_store.dart';
import 'sqlite_offline_store.dart';
import 'sync_queue.dart';

/// Internal [ConnectivityMonitor] singleton, disposed when the provider
/// scope is torn down. Bootstrap (spec §4.10) is responsible for calling
/// [ConnectivityMonitor.start] explicitly — the provider itself never
/// starts it, so reading this provider never touches a platform channel
/// (important for tests that don't care about real connectivity).
final connectivityMonitorProvider = Provider<ConnectivityMonitor>((ref) {
  final monitor = ConnectivityMonitor();
  ref.onDispose(() => unawaited(monitor.dispose()));
  return monitor;
});

/// Stream of device connectivity status changes, per spec §4.7.
final connectivityProvider = StreamProvider<ConnectivityStatus>((ref) {
  final monitor = ref.watch(connectivityMonitorProvider);
  return monitor.status;
});

/// The app's [OfflineDatabase]. Apps MUST override this at bootstrap with
/// [openAppDatabase] (a file-backed database); the default here is an
/// in-memory database so the provider graph is usable in isolation (e.g.
/// widget tests) without every test overriding it explicitly.
final offlineDatabaseProvider = Provider<OfflineDatabase>((ref) {
  final db = OfflineDatabase.inMemory();
  ref.onDispose(db.close);
  return db;
});

/// Offline read cache, per spec §4.7.
final offlineStoreProvider = Provider<OfflineStore>((ref) {
  final db = ref.watch(offlineDatabaseProvider);
  return SqliteOfflineStore(db);
});

/// Sync queue for pending writes, per spec §4.7. Reuses `penguin_api`'s
/// [apiClientProvider] rather than declaring a second one — a duplicate
/// provider of the same name in this package would silently diverge from
/// the one the rest of the app overrides.
final syncQueueProvider = Provider<SyncQueue>((ref) {
  final db = ref.watch(offlineDatabaseProvider);
  final connectivity = ref.watch(connectivityMonitorProvider);
  final log = ref.watch(loggerProvider);
  final metrics = ref.watch(metricsSinkProvider);
  final api = ref.watch(apiClientProvider);

  final queue = SyncQueue(
    db: db,
    connectivity: connectivity,
    api: api,
    log: log,
    metrics: metrics,
  );
  ref.onDispose(() => unawaited(queue.dispose()));
  return queue;
});
