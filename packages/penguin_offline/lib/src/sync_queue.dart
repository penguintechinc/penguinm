import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:uuid/uuid.dart';

import 'connectivity_monitor.dart';
import 'connectivity_status.dart';
import 'offline_database.dart';
import 'pending_write.dart';
import 'sync_report.dart';

/// Terminal (or loop-continuing) classification of one send attempt against
/// [PenguinApiClient].
enum _Outcome {
  /// 2xx response — the write is done.
  sent,

  /// `401`/`403` — the whole drain stops; the write stays queued.
  authStopped,

  /// A non-retriable error (any 4xx other than 408/429, or an unsupported
  /// method) — the write is moved into the durable dead-letter backlog and
  /// surfaced via [SyncQueue.deadLetters].
  deadLettered,

  /// `408`/`429`/5xx/network/timeout — worth another attempt after backoff.
  retryable,
}

/// HTTP methods [PenguinApiClient] can send: `POST`, `PUT`, `PATCH`,
/// `DELETE` — the same set [PendingWrite.method] documents.
const _supportedMethods = {'POST', 'PUT', 'PATCH', 'DELETE'};

/// Persists writes made while offline and replays them through
/// [PenguinApiClient] in FIFO order once connectivity returns (or whenever
/// [drain] is called explicitly): `2xx` removes the write; `401`/`403`
/// stops the whole drain without touching the write (the auth layer is
/// expected to recover the session); any other `4xx` (except `408`/`429`)
/// dead-letters the write immediately; `408`/`429`/`5xx`/timeout/network
/// failures are retried with [RetryPolicy] backoff up to `retry.maxAttempts`
/// before also being dead-lettered. Every write carries a uuid
/// `Idempotency-Key`, assigned at [enqueue] time if the caller didn't
/// already set one.
///
/// Dead letters are moved atomically (see [OfflineDatabase.transaction])
/// out of `pending_writes` and into a durable `dead_letters` table before
/// [deadLetters] is notified, so a dead letter is never lost even if
/// nothing is listening at that instant (spec §4.7: "surfaced to the user,
/// never silently dropped") — [deadLetterBacklog], [acknowledgeDeadLetter],
/// and [retryDeadLetter] manage that backlog.
///
/// Note: [PenguinApiClient] applies its own internal [RetryPolicy] to
/// transient failures (408/429/5xx) before ever returning a [Result] here,
/// so a single [drain] attempt may already reflect several HTTP attempts.
/// [SyncQueue]'s own retry loop is a second, coarser layer on top — durable
/// across process restarts via the `attempts` column — for failures that
/// persist beyond the client's internal retry budget.
class SyncQueue {
  /// Creates a queue backed by [db], sending through [api], and draining
  /// automatically whenever [connectivity] transitions from offline to
  /// online. [retry] governs this queue's own attempt budget (separate
  /// from [api]'s internal retry policy) — defaults to 5 attempts, matching
  /// spec §4.7.
  SyncQueue({
    required this._db,
    required this._api,
    required this._connectivity,
    required this._log,
    this._metrics = const NoopMetricsSink(),
    this._retry = const RetryPolicy(maxAttempts: 5),
    Random? random,
  }) : _rng = random ?? Random(),
       _lastStatus = _connectivity.current {
    _connectivitySubscription = _connectivity.status.listen(
      _onConnectivityChanged,
    );
  }

  final OfflineDatabase _db;
  final PenguinApiClient _api;
  final ConnectivityMonitor _connectivity;
  final PenguinLogger _log;
  final MetricsSink _metrics;
  final RetryPolicy _retry;
  final Random _rng;
  late final StreamSubscription<ConnectivityStatus> _connectivitySubscription;
  ConnectivityStatus _lastStatus;
  bool _draining = false;

  final StreamController<int> _depthController =
      StreamController<int>.broadcast();
  final StreamController<PendingWrite> _deadLettersController =
      StreamController<PendingWrite>.broadcast();

  /// Emits the current queue depth after every enqueue, successful send, or
  /// dead-letter.
  Stream<int> get depth => _depthController.stream;

  /// Emits every [PendingWrite] that was dead-lettered — surfaced to the
  /// user, never silently dropped.
  Stream<PendingWrite> get deadLetters => _deadLettersController.stream;

  /// Persists [write] durably, assigning a fresh uuid `Idempotency-Key`
  /// when it doesn't already have one, then emits the updated [depth].
  Future<void> enqueue(PendingWrite write) async {
    final toStore = write.idempotencyKey == null
        ? write.copyWith(idempotencyKey: const Uuid().v4())
        : write;
    _db.execute(
      '''
      INSERT INTO pending_writes
        (id, created_at, method, path, body, idempotency_key, attempts, last_error)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        toStore.id,
        toStore.createdAt.millisecondsSinceEpoch,
        toStore.method,
        toStore.path,
        toStore.body == null ? null : jsonEncode(toStore.body),
        toStore.idempotencyKey,
        toStore.attempts,
        toStore.lastError,
      ],
    );
    _log.debug(
      'sync_queue.enqueued',
      attributes: {'method': toStore.method, 'path': toStore.path},
    );
    _emitDepth();
  }

  /// Sends every queued write in FIFO order (oldest `created_at` first).
  /// Re-entrant calls (e.g. the connectivity listener firing while a manual
  /// drain is already in flight) are ignored and return an empty report.
  Future<SyncReport> drain() async {
    if (_draining) return const SyncReport();
    _draining = true;
    var sent = 0;
    var failed = 0;
    var deadLettered = 0;
    try {
      while (true) {
        final rows = _db.select(
          'SELECT * FROM pending_writes ORDER BY created_at ASC LIMIT 1',
        );
        if (rows.isEmpty) break;
        final write = _rowToPendingWrite(rows.first);
        final (outcome, finalWrite) = await _sendWithRetry(write);
        switch (outcome) {
          case _Outcome.sent:
            _removeWrite(write.id);
            sent++;
            _emitDepth();
          case _Outcome.deadLettered:
            // Already moved from pending_writes into dead_letters
            // atomically inside _sendWithRetry — nothing left to delete
            // here, just count it and notify listeners.
            deadLettered++;
            _deadLettersController.add(finalWrite);
            _emitDepth();
          case _Outcome.authStopped:
            failed++;
            return SyncReport(
              sent: sent,
              failed: failed,
              deadLettered: deadLettered,
            );
          case _Outcome.retryable:
            // _sendWithRetry only returns a terminal outcome; reaching this
            // would be a logic error. Fail safe rather than loop forever.
            throw StateError('SyncQueue._sendWithRetry returned retryable');
        }
      }
    } finally {
      _draining = false;
    }
    return SyncReport(sent: sent, failed: failed, deadLettered: deadLettered);
  }

  /// Sends [write], retrying retryable failures with [_retry] backoff until
  /// a terminal outcome (sent/authStopped/deadLettered) or [_retry.maxAttempts]
  /// is reached — starting the attempt count from [write.attempts] so a
  /// write that already failed on a previous drain (e.g. before a process
  /// restart) resumes rather than getting a fresh budget. Returns the
  /// terminal [_Outcome] alongside the write as last persisted (so a
  /// dead-lettered write carries its final `attempts`/`lastError` when
  /// surfaced via [deadLetters], not the stale copy read at drain-start).
  Future<(_Outcome, PendingWrite)> _sendWithRetry(PendingWrite write) async {
    final method = write.method.toUpperCase();
    if (!_supportedMethods.contains(method)) {
      final message = 'Unsupported method: ${write.method}';
      final updated = write.copyWith(
        attempts: write.attempts + 1,
        lastError: message,
      );
      _moveToDeadLetters(
        updated,
        statusCode: null,
        reason: 'unsupported_method',
      );
      _log.error(
        'sync_queue.unsupported_method',
        attributes: {'method': write.method, 'path': write.path},
      );
      return (_Outcome.deadLettered, updated);
    }

    var current = write;
    var attempt = write.attempts;
    while (true) {
      attempt++;
      final result = await _sendOnce(current, method);
      final (outcome, failure) = result.fold<(_Outcome, Failure?)>(
        (_) => (_Outcome.sent, null),
        (f) => (_classify(f), f),
      );
      final message = failure?.message;
      final statusCode = failure is ServerFailure ? failure.statusCode : null;

      switch (outcome) {
        case _Outcome.sent:
          return (_Outcome.sent, current);
        case _Outcome.authStopped:
          _log.warn(
            'sync_queue.auth_stopped',
            attributes: {'path': write.path},
          );
          return (_Outcome.authStopped, current);
        case _Outcome.deadLettered:
          current = current.copyWith(attempts: attempt, lastError: message);
          _moveToDeadLetters(
            current,
            statusCode: statusCode,
            reason: failure is ServerFailure
                ? 'http_4xx'
                : 'unclassified_failure',
          );
          _log.warn(
            'sync_queue.dead_lettered',
            attributes: {
              'path': write.path,
              'attempt': attempt,
              'status': statusCode,
            },
          );
          return (_Outcome.deadLettered, current);
        case _Outcome.retryable:
          current = current.copyWith(attempts: attempt, lastError: message);
          if (attempt >= _retry.maxAttempts) {
            _moveToDeadLetters(
              current,
              statusCode: statusCode,
              reason: 'retries_exhausted',
            );
            _log.warn(
              'sync_queue.retries_exhausted',
              attributes: {'path': write.path, 'attempts': attempt},
            );
            return (_Outcome.deadLettered, current);
          }
          _persistAttempt(current.id, attempt, message);
          await Future<void>.delayed(_retry.delayFor(attempt, _rng));
      }
    }
  }

  /// Sends [write] once through [_api], dispatching to the matching
  /// [PenguinApiClient] method for each of the four [_supportedMethods].
  Future<Result<Object?>> _sendOnce(PendingWrite write, String method) {
    Object? decode(Object? _) => null;
    return switch (method) {
      'POST' => _api.post<Object?>(
        write.path,
        body: write.body,
        idempotencyKey: write.idempotencyKey,
        decode: decode,
      ),
      'PUT' => _api.put<Object?>(
        write.path,
        body: write.body,
        idempotencyKey: write.idempotencyKey,
        decode: decode,
      ),
      'PATCH' => _api.patch<Object?>(
        write.path,
        body: write.body,
        idempotencyKey: write.idempotencyKey,
        decode: decode,
      ),
      'DELETE' => _api.delete<Object?>(
        write.path,
        idempotencyKey: write.idempotencyKey,
        decode: decode,
      ),
      _ => throw StateError('Unsupported method: $method'),
    };
  }

  /// Classifies a [Failure] into an [_Outcome] using the exact HTTP status
  /// `penguin_api`'s `mapFailure` (spec §4.4) attaches: `401`/`403` →
  /// [AuthFailure] (stop draining); [ServerFailure] carries the status for
  /// every other non-2xx response, so `408`/`429`/`5xx` → retryable and any
  /// other 4xx (400/404/409/422/...) → dead-letter immediately;
  /// [NetworkFailure] (timeout/connectivity) → retryable. The remaining
  /// sealed-class members ([UnknownFailure], [ValidationFailure],
  /// [StorageFailure]) never come out of `mapFailure` for an HTTP response,
  /// but dead-letter rather than retry forever if one somehow does.
  _Outcome _classify(Failure failure) {
    return switch (failure) {
      AuthFailure() => _Outcome.authStopped,
      ServerFailure(:final statusCode) =>
        (statusCode == 408 || statusCode == 429 || statusCode >= 500)
            ? _Outcome.retryable
            : _Outcome.deadLettered,
      NetworkFailure() => _Outcome.retryable,
      UnknownFailure() => _Outcome.deadLettered,
      ValidationFailure() => _Outcome.deadLettered,
      StorageFailure() => _Outcome.deadLettered,
    };
  }

  void _removeWrite(String id) {
    _db.execute('DELETE FROM pending_writes WHERE id = ?', [id]);
  }

  void _persistAttempt(String id, int attempts, String? lastError) {
    _db.execute(
      'UPDATE pending_writes SET attempts = ?, last_error = ? WHERE id = ?',
      [attempts, lastError, id],
    );
  }

  /// Atomically moves [write] out of `pending_writes` and into the durable
  /// `dead_letters` table (migration v2) so it survives even if nothing is
  /// listening on [deadLetters] at this instant. [statusCode] is the HTTP
  /// status that caused it, when known; [reason] is a short machine cause
  /// (`'http_4xx'`, `'retries_exhausted'`, `'unsupported_method'`,
  /// `'unclassified_failure'`).
  void _moveToDeadLetters(
    PendingWrite write, {
    required int? statusCode,
    required String reason,
  }) {
    _db.transaction(() {
      _db.execute('DELETE FROM pending_writes WHERE id = ?', [write.id]);
      _db.execute(
        '''
        INSERT INTO dead_letters
          (id, created_at, method, path, body, idempotency_key, attempts, last_error, failed_at, status, reason)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          write.id,
          write.createdAt.millisecondsSinceEpoch,
          write.method,
          write.path,
          write.body == null ? null : jsonEncode(write.body),
          write.idempotencyKey,
          write.attempts,
          write.lastError,
          DateTime.now().millisecondsSinceEpoch,
          statusCode,
          reason,
        ],
      );
    });
  }

  /// Every dead letter not yet acknowledged or retried, oldest-failed
  /// first. The durable backlog behind [deadLetters] — a UI can page
  /// through this at any time to show what needs the user's attention,
  /// independent of whether it was listening when a write was dead-lettered
  /// (spec §4.7: "surfaced to the user, never silently dropped").
  Future<List<PendingWrite>> deadLetterBacklog() async {
    final rows = _db.select(
      'SELECT * FROM dead_letters ORDER BY failed_at ASC',
    );
    return [for (final row in rows) _rowToPendingWrite(row)];
  }

  /// Permanently discards the dead letter [id] — the user has seen it and
  /// chosen not to retry it. A no-op if [id] isn't in the backlog.
  Future<void> acknowledgeDeadLetter(String id) async {
    _db.execute('DELETE FROM dead_letters WHERE id = ?', [id]);
  }

  /// Moves the dead letter [id] back onto the pending queue with a fresh
  /// attempt budget (`attempts` reset to 0) and its original
  /// `Idempotency-Key` preserved (so a retry can never be double-applied if
  /// the original request actually reached the server), then emits the
  /// updated [depth]. A no-op if [id] isn't in the backlog.
  Future<void> retryDeadLetter(String id) async {
    final rows = _db.select('SELECT * FROM dead_letters WHERE id = ?', [id]);
    if (rows.isEmpty) return;
    final row = rows.first;
    _db.transaction(() {
      _db.execute('DELETE FROM dead_letters WHERE id = ?', [id]);
      _db.execute(
        '''
        INSERT INTO pending_writes
          (id, created_at, method, path, body, idempotency_key, attempts, last_error)
        VALUES (?, ?, ?, ?, ?, ?, 0, NULL)
        ''',
        [
          row['id'],
          DateTime.now().millisecondsSinceEpoch,
          row['method'],
          row['path'],
          row['body'],
          row['idempotency_key'],
        ],
      );
    });
    _emitDepth();
  }

  void _emitDepth() {
    final rows = _db.select('SELECT COUNT(*) AS c FROM pending_writes');
    final count = rows.first['c'] as int;
    if (!_depthController.isClosed) {
      _depthController.add(count);
    }
    _metrics.gauge('sync.queue.depth', count);
  }

  void _onConnectivityChanged(ConnectivityStatus status) {
    final wasOffline = _lastStatus != ConnectivityStatus.online;
    _lastStatus = status;
    if (wasOffline && status == ConnectivityStatus.online) {
      unawaited(drain());
    }
  }

  PendingWrite _rowToPendingWrite(Map<String, dynamic> row) {
    final bodyJson = row['body'] as String?;
    return PendingWrite(
      id: row['id'] as String,
      method: row['method'] as String,
      path: row['path'] as String,
      body: bodyJson == null
          ? null
          : jsonDecode(bodyJson) as Map<String, Object?>,
      idempotencyKey: row['idempotency_key'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      attempts: row['attempts'] as int,
      lastError: row['last_error'] as String?,
    );
  }

  /// Cancels the connectivity listener and closes the [depth]/[deadLetters]
  /// streams. Not part of spec §4.7's listed API, but necessary to avoid
  /// leaking the connectivity subscription once the owning scope (app
  /// shutdown, a Riverpod provider's `onDispose`, test teardown) is done
  /// with this queue.
  Future<void> dispose() async {
    await _connectivitySubscription.cancel();
    await _depthController.close();
    await _deadLettersController.close();
  }
}
