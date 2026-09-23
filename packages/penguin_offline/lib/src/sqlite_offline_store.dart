import 'dart:convert';

import 'cached_entry.dart';
import 'offline_database.dart';
import 'offline_store.dart';

/// [OfflineStore] backed by [OfflineDatabase]'s `cache_entries` table.
/// Every statement binds `collection`/`id`/`json` as parameters — none of
/// them are ever interpolated into SQL text.
class SqliteOfflineStore implements OfflineStore {
  /// Creates a store reading and writing through [db].
  const SqliteOfflineStore(this.db);

  /// The underlying database connection.
  final OfflineDatabase db;

  @override
  Future<void> put(
    String collection,
    String id,
    Map<String, Object?> data, {
    DateTime? fetchedAt,
  }) async {
    final effectiveFetchedAt = fetchedAt ?? DateTime.now();
    db.execute(
      '''
      INSERT INTO cache_entries (collection, id, json, fetched_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT (collection, id) DO UPDATE SET
        json = excluded.json,
        fetched_at = excluded.fetched_at
      ''',
      [
        collection,
        id,
        jsonEncode(data),
        effectiveFetchedAt.millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<CachedEntry?> get(String collection, String id) async {
    final rows = db.select(
      'SELECT json, fetched_at FROM cache_entries WHERE collection = ? AND id = ?',
      [collection, id],
    );
    if (rows.isEmpty) return null;
    return _toEntry(collection, id, rows.first);
  }

  @override
  Future<List<CachedEntry>> list(String collection) async {
    final rows = db.select(
      'SELECT id, json, fetched_at FROM cache_entries WHERE collection = ? ORDER BY id',
      [collection],
    );
    return [
      for (final row in rows) _toEntry(collection, row['id'] as String, row),
    ];
  }

  @override
  Future<void> remove(String collection, String id) async {
    db.execute('DELETE FROM cache_entries WHERE collection = ? AND id = ?', [
      collection,
      id,
    ]);
  }

  @override
  Future<void> clear(String collection) async {
    db.execute('DELETE FROM cache_entries WHERE collection = ?', [collection]);
  }

  /// Builds a [CachedEntry] from a raw `cache_entries` row.
  CachedEntry _toEntry(String collection, String id, Map<String, dynamic> row) {
    return CachedEntry(
      collection: collection,
      id: id,
      data: jsonDecode(row['json'] as String) as Map<String, Object?>,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(row['fetched_at'] as int),
    );
  }
}
