import 'cached_entry.dart';

/// Local cache for API read data, keyed by an app-chosen `collection` name
/// plus a record `id`, so screens can render the last-known payload
/// (paired with [CachedEntry.age]/[StaleDataChip]) while offline or while a
/// fresh fetch is in flight. [SqliteOfflineStore] is the production
/// implementation; tests may substitute an in-memory fake.
abstract interface class OfflineStore {
  /// Inserts or replaces the entry for `collection`/`id` with [data],
  /// stamped with [fetchedAt] (defaults to now).
  Future<void> put(
    String collection,
    String id,
    Map<String, Object?> data, {
    DateTime? fetchedAt,
  });

  /// Returns the cached entry for `collection`/`id`, or null if absent.
  Future<CachedEntry?> get(String collection, String id);

  /// Returns every cached entry in `collection`, ordered by `id`.
  Future<List<CachedEntry>> list(String collection);

  /// Deletes the entry for `collection`/`id`, if present.
  Future<void> remove(String collection, String id);

  /// Deletes every entry in `collection`.
  Future<void> clear(String collection);
}
