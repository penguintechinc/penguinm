import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_offline/penguin_offline.dart';

/// In-memory [OfflineStore] fake: entries live in a nested map instead of
/// sqlite, so offline-read tests never touch the filesystem.
class InMemoryOfflineStore implements OfflineStore {
  /// Creates a fake store; the given clock stamps [CachedEntry.fetchedAt]
  /// when a caller omits it, defaulting to the real system clock.
  InMemoryOfflineStore({this._clock = const SystemClock()});

  final Clock _clock;
  final Map<String, Map<String, CachedEntry>> _store =
      <String, Map<String, CachedEntry>>{};

  @override
  Future<void> put(
    String collection,
    String id,
    Map<String, Object?> data, {
    DateTime? fetchedAt,
  }) async {
    final bucket = _store.putIfAbsent(
      collection,
      () => <String, CachedEntry>{},
    );
    bucket[id] = CachedEntry(
      collection: collection,
      id: id,
      data: data,
      fetchedAt: fetchedAt ?? _clock.now(),
    );
  }

  @override
  Future<CachedEntry?> get(String collection, String id) async {
    return _store[collection]?[id];
  }

  @override
  Future<List<CachedEntry>> list(String collection) async {
    final bucket = _store[collection];
    if (bucket == null) return const <CachedEntry>[];
    final entries = bucket.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return entries;
  }

  @override
  Future<void> remove(String collection, String id) async {
    _store[collection]?.remove(id);
  }

  @override
  Future<void> clear(String collection) async {
    _store.remove(collection);
  }
}
