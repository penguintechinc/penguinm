import 'package:penguin_core/penguin_core.dart';

/// A single cached API response: [collection]/[id] identify the record,
/// [data] is its last-known JSON body, and [fetchedAt] records when it was
/// fetched so [age] can tell callers (e.g. [StaleDataChip]) how stale it is.
class CachedEntry {
  /// Creates an entry read from or about to be written to [OfflineStore].
  const CachedEntry({
    required this.collection,
    required this.id,
    required this.data,
    required this.fetchedAt,
  });

  /// Logical grouping of records, e.g. `'users'` or `'posts'`.
  final String collection;

  /// Record identifier, unique within [collection].
  final String id;

  /// The cached JSON-serializable payload.
  final Map<String, Object?> data;

  /// When this payload was fetched from the server.
  final DateTime fetchedAt;

  /// How long ago [fetchedAt] was, as measured by [clock].
  Duration age(Clock clock) => clock.now().difference(fetchedAt);
}
