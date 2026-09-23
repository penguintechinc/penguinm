/// A write made while offline (or speculatively, before the response comes
/// back), durably queued by [SyncQueue] until it can be replayed against
/// the real API. `method` is one of `POST`/`PUT`/`PATCH`/`DELETE` — the
/// verbs [PenguinApiClient] exposes; see `SyncQueue`'s dartdoc for how an
/// unsupported verb is handled.
class PendingWrite {
  /// Creates a pending write. Callers (a feature's `data/` layer) supply
  /// [id]; [idempotencyKey] may be left null and [SyncQueue.enqueue] will
  /// assign a fresh uuid before persisting.
  const PendingWrite({
    required this.id,
    required this.method,
    required this.path,
    this.body,
    this.idempotencyKey,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  /// Unique write identifier (uuid) — the `pending_writes` primary key.
  final String id;

  /// HTTP method: `POST`, `PUT`, `PATCH`, or `DELETE`.
  final String method;

  /// API path passed to [PenguinApiClient], e.g. `/users/123`.
  final String path;

  /// Request body as a JSON-serializable map; null for methods that don't
  /// carry one (typically `DELETE`).
  final Map<String, Object?>? body;

  /// `Idempotency-Key` header value sent with every retry of this write.
  final String? idempotencyKey;

  /// When this write was enqueued; drives FIFO ordering in [SyncQueue].
  final DateTime createdAt;

  /// Number of sync attempts made so far.
  final int attempts;

  /// Message from the most recent failed attempt, if any.
  final String? lastError;

  /// Returns a copy with [idempotencyKey], [attempts], and [lastError]
  /// overridden where provided; all other fields are carried over.
  PendingWrite copyWith({
    String? idempotencyKey,
    int? attempts,
    String? lastError,
  }) {
    return PendingWrite(
      id: id,
      method: method,
      path: path,
      body: body,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      createdAt: createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }
}
