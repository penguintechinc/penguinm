import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_offline/src/connectivity_monitor.dart';
import 'package:penguin_offline/src/offline_database.dart';
import 'package:penguin_offline/src/pending_write.dart';
import 'package:penguin_offline/src/sync_queue.dart';

import 'support/api_test_support.dart';

class _MockConnectivity extends Mock implements Connectivity {}

class _RecordingMetricsSink implements MetricsSink {
  final List<num> gauges = [];

  @override
  void gauge(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  }) {
    if (name == 'sync.queue.depth') gauges.add(value);
  }

  @override
  void counter(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  }) {}

  @override
  void histogram(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  }) {}
}

PendingWrite _write({
  required String id,
  String method = 'POST',
  String path = '/x',
  Map<String, Object?>? body,
  DateTime? createdAt,
  String? idempotencyKey,
  int attempts = 0,
  String? lastError,
}) {
  return PendingWrite(
    id: id,
    method: method,
    path: path,
    body: body,
    idempotencyKey: idempotencyKey,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    attempts: attempts,
    lastError: lastError,
  );
}

/// Builds a [PenguinApiClient] whose own internal retry is disabled
/// (`maxAttempts: 1`) so every [SyncQueue]-level attempt consumes exactly
/// one scripted response, isolating [SyncQueue]'s own retry loop.
PenguinApiClient _apiClient(
  ScriptedResponses scripted, {
  FakeTokenProvider? tokens,
}) {
  return PenguinApiClient(
    config: testAppConfig(),
    tokens: tokens ?? FakeTokenProvider(),
    inner: MockClient(scripted.handle),
    retry: const RetryPolicy(maxAttempts: 1),
  );
}

void main() {
  group('SyncQueue.enqueue', () {
    late OfflineDatabase db;
    late ConnectivityMonitor connectivity;

    setUp(() {
      db = OfflineDatabase.inMemory();
      connectivity = ConnectivityMonitor();
    });

    tearDown(() => db.close());

    test('persists the write and emits the new depth', () async {
      final scripted = ScriptedResponses([]);
      final queue = SyncQueue(
        db: db,
        api: _apiClient(scripted),
        connectivity: connectivity,
        log: ConsoleLogger(),
      );
      addTearDown(queue.dispose);

      final depths = <int>[];
      queue.depth.listen(depths.add);

      await queue.enqueue(_write(id: 'w1'));
      await pumpEventQueue();

      expect(depths, [1]);
      final rows = db.select('SELECT * FROM pending_writes WHERE id = ?', [
        'w1',
      ]);
      expect(rows, hasLength(1));
    });

    test('assigns a fresh idempotency key when the write has none', () async {
      final scripted = ScriptedResponses([]);
      final queue = SyncQueue(
        db: db,
        api: _apiClient(scripted),
        connectivity: connectivity,
        log: ConsoleLogger(),
      );
      addTearDown(queue.dispose);

      await queue.enqueue(_write(id: 'w1'));

      final row = db.select(
        'SELECT idempotency_key FROM pending_writes WHERE id = ?',
        ['w1'],
      ).first;
      final key = row['idempotency_key'] as String?;
      expect(key, isNotNull);
      expect(key, matches(RegExp(r'^[0-9a-f-]{36}$')));
    });

    test('preserves a caller-supplied idempotency key', () async {
      final scripted = ScriptedResponses([]);
      final queue = SyncQueue(
        db: db,
        api: _apiClient(scripted),
        connectivity: connectivity,
        log: ConsoleLogger(),
      );
      addTearDown(queue.dispose);

      await queue.enqueue(_write(id: 'w1', idempotencyKey: 'caller-key'));

      final row = db.select(
        'SELECT idempotency_key FROM pending_writes WHERE id = ?',
        ['w1'],
      ).first;
      expect(row['idempotency_key'], 'caller-key');
    });
  });

  group('SyncQueue.drain', () {
    late OfflineDatabase db;
    late ConnectivityMonitor connectivity;

    setUp(() {
      db = OfflineDatabase.inMemory();
      connectivity = ConnectivityMonitor();
    });

    tearDown(() => db.close());

    test('a successful 2xx removes the write and reports it sent', () async {
      final scripted = ScriptedResponses([jsonResponse(201)]);
      final metrics = _RecordingMetricsSink();
      final queue = SyncQueue(
        db: db,
        api: _apiClient(scripted),
        connectivity: connectivity,
        log: ConsoleLogger(),
        metrics: metrics,
      );
      addTearDown(queue.dispose);

      await queue.enqueue(_write(id: 'w1', path: '/users'));
      final report = await queue.drain();

      expect(report.sent, 1);
      expect(report.deadLettered, 0);
      expect(report.failed, 0);
      expect(db.select('SELECT * FROM pending_writes'), isEmpty);
      expect(scripted.seen, hasLength(1));
      expect(scripted.seen.single.method, 'POST');
      expect(scripted.seen.single.url.path, '/users');
      expect(metrics.gauges.last, 0);
    });

    test('sends the write\'s Idempotency-Key header', () async {
      final scripted = ScriptedResponses([jsonResponse(200)]);
      final queue = SyncQueue(
        db: db,
        api: _apiClient(scripted),
        connectivity: connectivity,
        log: ConsoleLogger(),
      );
      addTearDown(queue.dispose);

      await queue.enqueue(_write(id: 'w1', idempotencyKey: 'idem-123'));
      await queue.drain();

      expect(scripted.seen.single.headers['idempotency-key'], 'idem-123');
    });

    test(
      'a write\'s body round-trips through persistence and onto the wire',
      () async {
        final scripted = ScriptedResponses([jsonResponse(200)]);
        final queue = SyncQueue(
          db: db,
          api: _apiClient(scripted),
          connectivity: connectivity,
          log: ConsoleLogger(),
        );
        addTearDown(queue.dispose);

        await queue.enqueue(
          _write(id: 'w1', body: const {'name': 'Alice', 'age': 30}),
        );
        await queue.drain();

        expect(scripted.seen.single.body, '{"name":"Alice","age":30}');
      },
    );

    test('PUT writes are sent as PUT with their body', () async {
      final scripted = ScriptedResponses([jsonResponse(200)]);
      final queue = SyncQueue(
        db: db,
        api: _apiClient(scripted),
        connectivity: connectivity,
        log: ConsoleLogger(),
      );
      addTearDown(queue.dispose);

      await queue.enqueue(
        _write(
          id: 'w1',
          method: 'PUT',
          path: '/users/1',
          body: const {'name': 'Bob'},
        ),
      );
      final report = await queue.drain();

      expect(report.sent, 1);
      expect(scripted.seen.single.method, 'PUT');
      expect(scripted.seen.single.url.path, '/users/1');
      expect(scripted.seen.single.body, '{"name":"Bob"}');
    });

    test('DELETE writes are sent as DELETE with no body', () async {
      final scripted = ScriptedResponses([jsonResponse(204)]);
      final queue = SyncQueue(
        db: db,
        api: _apiClient(scripted),
        connectivity: connectivity,
        log: ConsoleLogger(),
      );
      addTearDown(queue.dispose);

      await queue.enqueue(_write(id: 'w1', method: 'DELETE', path: '/users/1'));
      final report = await queue.drain();

      expect(report.sent, 1);
      expect(scripted.seen.single.method, 'DELETE');
      expect(scripted.seen.single.url.path, '/users/1');
    });

    test('processes writes in FIFO order by createdAt', () async {
      final scripted = ScriptedResponses([
        jsonResponse(200),
        jsonResponse(200),
      ]);
      final queue = SyncQueue(
        db: db,
        api: _apiClient(scripted),
        connectivity: connectivity,
        log: ConsoleLogger(),
      );
      addTearDown(queue.dispose);

      await queue.enqueue(
        _write(id: 'second', path: '/second', createdAt: DateTime(2026, 1, 2)),
      );
      await queue.enqueue(
        _write(id: 'first', path: '/first', createdAt: DateTime(2026, 1, 1)),
      );

      await queue.drain();

      expect(scripted.seen.map((r) => r.url.path).toList(), [
        '/first',
        '/second',
      ]);
    });

    for (final status in [400, 404, 409, 422]) {
      test(
        'a non-retriable 4xx ($status) dead-letters the write immediately',
        () async {
          final scripted = ScriptedResponses([jsonResponse(status)]);
          final queue = SyncQueue(
            db: db,
            api: _apiClient(scripted),
            connectivity: connectivity,
            log: ConsoleLogger(),
          );
          addTearDown(queue.dispose);

          final deadLettered = <PendingWrite>[];
          queue.deadLetters.listen(deadLettered.add);

          await queue.enqueue(_write(id: 'w1'));
          final report = await queue.drain();
          await pumpEventQueue();

          expect(report.deadLettered, 1, reason: 'status $status');
          expect(report.sent, 0);
          expect(
            scripted.seen,
            hasLength(1),
            reason: 'status $status must not be retried',
          );
          expect(deadLettered, hasLength(1));
          expect(deadLettered.single.id, 'w1');
          expect(db.select('SELECT * FROM pending_writes'), isEmpty);
          expect(db.select('SELECT * FROM dead_letters'), hasLength(1));
        },
      );
    }

    for (final status in [408, 429, 500, 503]) {
      test(
        'a retryable status ($status) is retried once then sent, not dead-lettered',
        () async {
          final scripted = ScriptedResponses([
            jsonResponse(status),
            jsonResponse(200),
          ]);
          final queue = SyncQueue(
            db: db,
            api: _apiClient(scripted),
            connectivity: connectivity,
            log: ConsoleLogger(),
            retry: const RetryPolicy(
              maxAttempts: 3,
              baseDelay: Duration.zero,
              jitter: false,
            ),
          );
          addTearDown(queue.dispose);

          await queue.enqueue(_write(id: 'w1'));
          final report = await queue.drain();

          expect(
            scripted.seen,
            hasLength(2),
            reason: 'status $status should be retried once then succeed',
          );
          expect(report.sent, 1);
          expect(report.deadLettered, 0);
        },
      );
    }

    test('401 stops the drain and leaves the write queued', () async {
      // AuthClient replays once after a failed refresh-triggering 401, so a
      // persistent 401 consumes two scripted responses per attempted write.
      final scripted = ScriptedResponses([
        jsonResponse(401),
        jsonResponse(401),
      ]);
      final queue = SyncQueue(
        db: db,
        api: _apiClient(scripted),
        connectivity: connectivity,
        log: ConsoleLogger(),
      );
      addTearDown(queue.dispose);

      await queue.enqueue(_write(id: 'w1'));
      final report = await queue.drain();

      expect(report.failed, 1);
      expect(report.sent, 0);
      expect(report.deadLettered, 0);
      expect(scripted.seen, hasLength(2));
      expect(db.select('SELECT * FROM pending_writes'), hasLength(1));
    });

    test('403 also stops the drain without dead-lettering', () async {
      final scripted = ScriptedResponses([
        jsonResponse(403),
        jsonResponse(403),
      ]);
      final queue = SyncQueue(
        db: db,
        api: _apiClient(scripted),
        connectivity: connectivity,
        log: ConsoleLogger(),
      );
      addTearDown(queue.dispose);

      await queue.enqueue(_write(id: 'w1'));
      final report = await queue.drain();

      expect(report.failed, 1);
      expect(db.select('SELECT * FROM pending_writes'), hasLength(1));
    });

    test('an auth stop does not touch writes after it in the queue', () async {
      final scripted = ScriptedResponses([
        jsonResponse(401),
        jsonResponse(401),
      ]);
      final queue = SyncQueue(
        db: db,
        api: _apiClient(scripted),
        connectivity: connectivity,
        log: ConsoleLogger(),
      );
      addTearDown(queue.dispose);

      await queue.enqueue(_write(id: 'first', createdAt: DateTime(2026, 1, 1)));
      await queue.enqueue(
        _write(id: 'second', createdAt: DateTime(2026, 1, 2)),
      );

      await queue.drain();

      // Only the first (oldest) write was attempted; both remain queued.
      expect(scripted.seen, hasLength(2));
      expect(db.select('SELECT * FROM pending_writes'), hasLength(2));
    });

    test(
      'repeated 503s retry with backoff, then dead-letter after maxAttempts',
      () async {
        final scripted = ScriptedResponses([
          jsonResponse(503),
          jsonResponse(503),
          jsonResponse(503),
        ]);
        final queue = SyncQueue(
          db: db,
          api: _apiClient(scripted),
          connectivity: connectivity,
          log: ConsoleLogger(),
          retry: const RetryPolicy(
            maxAttempts: 3,
            baseDelay: Duration.zero,
            jitter: false,
          ),
        );
        addTearDown(queue.dispose);

        final deadLettered = <PendingWrite>[];
        queue.deadLetters.listen(deadLettered.add);

        await queue.enqueue(_write(id: 'w1'));
        final report = await queue.drain();
        await pumpEventQueue();

        expect(scripted.seen, hasLength(3));
        expect(report.deadLettered, 1);
        expect(deadLettered.single.lastError, isNotNull);
        expect(db.select('SELECT * FROM pending_writes'), isEmpty);
      },
    );

    test(
      'a transient 503 followed by success is sent without dead-lettering',
      () async {
        final scripted = ScriptedResponses([
          jsonResponse(503),
          jsonResponse(200),
        ]);
        final queue = SyncQueue(
          db: db,
          api: _apiClient(scripted),
          connectivity: connectivity,
          log: ConsoleLogger(),
          retry: const RetryPolicy(
            maxAttempts: 3,
            baseDelay: Duration.zero,
            jitter: false,
          ),
        );
        addTearDown(queue.dispose);

        await queue.enqueue(_write(id: 'w1'));
        final report = await queue.drain();

        expect(scripted.seen, hasLength(2));
        expect(report.sent, 1);
        expect(report.deadLettered, 0);
      },
    );

    test(
      '408 and 429 are retried like 5xx, not dead-lettered on first failure',
      () async {
        final scripted = ScriptedResponses([
          jsonResponse(429),
          jsonResponse(408),
          jsonResponse(200),
        ]);
        final queue = SyncQueue(
          db: db,
          api: _apiClient(scripted),
          connectivity: connectivity,
          log: ConsoleLogger(),
          retry: const RetryPolicy(
            maxAttempts: 3,
            baseDelay: Duration.zero,
            jitter: false,
          ),
        );
        addTearDown(queue.dispose);

        await queue.enqueue(_write(id: 'w1'));
        final report = await queue.drain();

        expect(scripted.seen, hasLength(3));
        expect(report.sent, 1);
      },
    );

    test(
      'a write resumes its attempt count after a simulated restart',
      () async {
        // Persist a write that already used 2 of 3 attempts (as if the app
        // crashed mid-drain and reloaded the queue from disk).
        db.execute(
          '''
        INSERT INTO pending_writes (id, created_at, method, path, body, idempotency_key, attempts, last_error)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
          [
            'w1',
            DateTime(2026, 1, 1).millisecondsSinceEpoch,
            'POST',
            '/x',
            null,
            'k1',
            2,
            'HTTP 503',
          ],
        );

        final scripted = ScriptedResponses([jsonResponse(503)]);
        final queue = SyncQueue(
          db: db,
          api: _apiClient(scripted),
          connectivity: connectivity,
          log: ConsoleLogger(),
          retry: const RetryPolicy(
            maxAttempts: 3,
            baseDelay: Duration.zero,
            jitter: false,
          ),
        );
        addTearDown(queue.dispose);

        final report = await queue.drain();

        // Only one more attempt was available (2 already used, max 3) —
        // straight to dead-letter, not another 2 retries.
        expect(scripted.seen, hasLength(1));
        expect(report.deadLettered, 1);
      },
    );

    test(
      'an unsupported HTTP method (HEAD) is dead-lettered without a network call',
      () async {
        final scripted = ScriptedResponses([]);
        final queue = SyncQueue(
          db: db,
          api: _apiClient(scripted),
          connectivity: connectivity,
          log: ConsoleLogger(),
        );
        addTearDown(queue.dispose);

        final deadLettered = <PendingWrite>[];
        queue.deadLetters.listen(deadLettered.add);

        await queue.enqueue(_write(id: 'w1', method: 'HEAD'));
        final report = await queue.drain();
        await pumpEventQueue();

        expect(scripted.seen, isEmpty);
        expect(report.deadLettered, 1);
        expect(deadLettered.single.id, 'w1');
        expect(db.select('SELECT * FROM dead_letters'), hasLength(1));
      },
    );

    test(
      'PATCH writes are sent as PATCH and carry the Idempotency-Key',
      () async {
        final scripted = ScriptedResponses([jsonResponse(200)]);
        final queue = SyncQueue(
          db: db,
          api: _apiClient(scripted),
          connectivity: connectivity,
          log: ConsoleLogger(),
        );
        addTearDown(queue.dispose);

        await queue.enqueue(
          _write(
            id: 'w1',
            method: 'PATCH',
            path: '/users/1',
            body: const {'name': 'Carol'},
            idempotencyKey: 'idem-patch',
          ),
        );
        final report = await queue.drain();

        expect(report.sent, 1);
        expect(scripted.seen.single.method, 'PATCH');
        expect(scripted.seen.single.url.path, '/users/1');
        expect(scripted.seen.single.body, '{"name":"Carol"}');
        expect(scripted.seen.single.headers['idempotency-key'], 'idem-patch');
      },
    );

    test(
      'a PATCH write is retry-safe: a transient 503 is retried then sent',
      () async {
        final scripted = ScriptedResponses([
          jsonResponse(503),
          jsonResponse(200),
        ]);
        final queue = SyncQueue(
          db: db,
          api: _apiClient(scripted),
          connectivity: connectivity,
          log: ConsoleLogger(),
          retry: const RetryPolicy(
            maxAttempts: 3,
            baseDelay: Duration.zero,
            jitter: false,
          ),
        );
        addTearDown(queue.dispose);

        await queue.enqueue(
          _write(id: 'w1', method: 'PATCH', idempotencyKey: 'idem-patch-retry'),
        );
        final report = await queue.drain();

        expect(scripted.seen, hasLength(2));
        expect(
          scripted.seen.every(
            (r) => r.headers['idempotency-key'] == 'idem-patch-retry',
          ),
          isTrue,
        );
        expect(report.sent, 1);
      },
    );

    test(
      'a network error (thrown by the inner client) is retried like a 5xx',
      () async {
        var calls = 0;
        final client = MockClient((request) async {
          calls++;
          if (calls == 1) throw http.ClientException('boom');
          return http.Response('{}', 200);
        });
        final api = PenguinApiClient(
          config: testAppConfig(),
          tokens: FakeTokenProvider(),
          inner: client,
          retry: const RetryPolicy(maxAttempts: 1),
        );
        final queue = SyncQueue(
          db: db,
          api: api,
          connectivity: connectivity,
          log: ConsoleLogger(),
          retry: const RetryPolicy(
            maxAttempts: 3,
            baseDelay: Duration.zero,
            jitter: false,
          ),
        );
        addTearDown(queue.dispose);

        await queue.enqueue(_write(id: 'w1'));
        final report = await queue.drain();

        expect(calls, 2);
        expect(report.sent, 1);
      },
    );

    test(
      'an empty queue drains to a zero report without any request',
      () async {
        final scripted = ScriptedResponses([]);
        final queue = SyncQueue(
          db: db,
          api: _apiClient(scripted),
          connectivity: connectivity,
          log: ConsoleLogger(),
        );
        addTearDown(queue.dispose);

        final report = await queue.drain();

        expect(report.total, 0);
        expect(scripted.seen, isEmpty);
      },
    );

    test(
      'concurrent drain() calls are ignored while one is already running',
      () async {
        final scripted = ScriptedResponses([jsonResponse(200)]);
        final queue = SyncQueue(
          db: db,
          api: _apiClient(scripted),
          connectivity: connectivity,
          log: ConsoleLogger(),
        );
        addTearDown(queue.dispose);

        await queue.enqueue(_write(id: 'w1'));

        final first = queue.drain();
        final second = queue.drain();

        final results = await Future.wait([first, second]);
        expect(results.map((r) => r.total).toList(), containsAll([0, 1]));
      },
    );
  });

  group('SyncQueue auto-drain on reconnect', () {
    test(
      'drains automatically when connectivity transitions offline -> online',
      () async {
        final plugin = _MockConnectivity();
        final changes = StreamController<List<ConnectivityResult>>.broadcast();
        addTearDown(changes.close);
        when(
          () => plugin.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.none]);
        when(
          () => plugin.onConnectivityChanged,
        ).thenAnswer((_) => changes.stream);

        final connectivity = ConnectivityMonitor(plugin: plugin);
        await connectivity.start();

        final db = OfflineDatabase.inMemory();
        addTearDown(db.close);
        final scripted = ScriptedResponses([jsonResponse(200)]);
        final queue = SyncQueue(
          db: db,
          api: _apiClient(scripted),
          connectivity: connectivity,
          log: ConsoleLogger(),
        );
        addTearDown(queue.dispose);

        await queue.enqueue(_write(id: 'w1'));
        expect(scripted.seen, isEmpty); // not sent while still offline

        changes.add([ConnectivityResult.wifi]);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await pumpEventQueue();

        expect(scripted.seen, hasLength(1));
        expect(db.select('SELECT * FROM pending_writes'), isEmpty);

        await connectivity.dispose();
      },
    );

    test(
      'does not auto-drain on an online -> online duplicate notification',
      () async {
        final plugin = _MockConnectivity();
        final changes = StreamController<List<ConnectivityResult>>.broadcast();
        addTearDown(changes.close);
        when(
          () => plugin.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.wifi]);
        when(
          () => plugin.onConnectivityChanged,
        ).thenAnswer((_) => changes.stream);

        final connectivity = ConnectivityMonitor(plugin: plugin);
        await connectivity.start();

        final db = OfflineDatabase.inMemory();
        addTearDown(db.close);
        final scripted = ScriptedResponses([]);
        final queue = SyncQueue(
          db: db,
          api: _apiClient(scripted),
          connectivity: connectivity,
          log: ConsoleLogger(),
        );
        addTearDown(queue.dispose);

        await queue.enqueue(_write(id: 'w1'));
        // Already online at construction time; a same-status change must not
        // trigger a drain by itself (status dedupes identical values, so this
        // also confirms no ConnectivityMonitor event even fires).
        changes.add([ConnectivityResult.ethernet]);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(scripted.seen, isEmpty);

        await connectivity.dispose();
      },
    );
  });

  group('SyncQueue dead-letter persistence', () {
    test('a dead letter with no deadLetters listener survives and is returned '
        'by deadLetterBacklog() after reopening the database', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'penguin_offline_deadletter_test_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final path = p.join(tempDir.path, 'dl.sqlite');

      final db1 = OfflineDatabase.open(path);
      final connectivity1 = ConnectivityMonitor();
      final scripted = ScriptedResponses([jsonResponse(422)]);
      final queue1 = SyncQueue(
        db: db1,
        api: _apiClient(scripted),
        connectivity: connectivity1,
        log: ConsoleLogger(),
      );
      // Deliberately never subscribe to queue1.deadLetters.
      await queue1.enqueue(_write(id: 'w1', path: '/orders'));
      final report = await queue1.drain();
      expect(report.deadLettered, 1);
      await queue1.dispose();
      db1.close();

      final db2 = OfflineDatabase.open(path);
      final connectivity2 = ConnectivityMonitor();
      final queue2 = SyncQueue(
        db: db2,
        api: _apiClient(ScriptedResponses([])),
        connectivity: connectivity2,
        log: ConsoleLogger(),
      );
      addTearDown(queue2.dispose);

      final backlog = await queue2.deadLetterBacklog();
      expect(backlog, hasLength(1));
      expect(backlog.single.id, 'w1');
      expect(backlog.single.path, '/orders');

      db2.close();
    });

    test('acknowledgeDeadLetter removes it from the backlog', () async {
      final db = OfflineDatabase.inMemory();
      addTearDown(db.close);
      final connectivity = ConnectivityMonitor();
      final scripted = ScriptedResponses([jsonResponse(422)]);
      final queue = SyncQueue(
        db: db,
        api: _apiClient(scripted),
        connectivity: connectivity,
        log: ConsoleLogger(),
      );
      addTearDown(queue.dispose);

      await queue.enqueue(_write(id: 'w1'));
      await queue.drain();
      expect(await queue.deadLetterBacklog(), hasLength(1));

      await queue.acknowledgeDeadLetter('w1');

      expect(await queue.deadLetterBacklog(), isEmpty);
      expect(db.select('SELECT * FROM dead_letters'), isEmpty);
    });

    test('acknowledgeDeadLetter on an unknown id is a no-op', () async {
      final db = OfflineDatabase.inMemory();
      addTearDown(db.close);
      final queue = SyncQueue(
        db: db,
        api: _apiClient(ScriptedResponses([])),
        connectivity: ConnectivityMonitor(),
        log: ConsoleLogger(),
      );
      addTearDown(queue.dispose);

      await queue.acknowledgeDeadLetter('missing');
    });

    test('retryDeadLetter re-enqueues it with a fresh attempt budget and the '
        'same Idempotency-Key', () async {
      final db = OfflineDatabase.inMemory();
      addTearDown(db.close);
      final connectivity = ConnectivityMonitor();
      final scripted = ScriptedResponses([
        jsonResponse(422),
        jsonResponse(200),
      ]);
      final queue = SyncQueue(
        db: db,
        api: _apiClient(scripted),
        connectivity: connectivity,
        log: ConsoleLogger(),
      );
      addTearDown(queue.dispose);

      await queue.enqueue(
        _write(id: 'w1', idempotencyKey: 'idem-fixed', path: '/orders'),
      );
      final firstReport = await queue.drain(); // dead-lettered (422)
      expect(firstReport.deadLettered, 1);
      expect(await queue.deadLetterBacklog(), hasLength(1));

      await queue.retryDeadLetter('w1');

      expect(await queue.deadLetterBacklog(), isEmpty);
      final requeued = db.select('SELECT * FROM pending_writes WHERE id = ?', [
        'w1',
      ]);
      expect(requeued, hasLength(1));
      expect(requeued.single['attempts'], 0);
      expect(requeued.single['idempotency_key'], 'idem-fixed');

      final secondReport = await queue.drain(); // now succeeds (200)
      expect(secondReport.sent, 1);
      expect(scripted.seen, hasLength(2));
      expect(scripted.seen.last.headers['idempotency-key'], 'idem-fixed');
    });

    test('retryDeadLetter on an unknown id is a no-op', () async {
      final db = OfflineDatabase.inMemory();
      addTearDown(db.close);
      final queue = SyncQueue(
        db: db,
        api: _apiClient(ScriptedResponses([])),
        connectivity: ConnectivityMonitor(),
        log: ConsoleLogger(),
      );
      addTearDown(queue.dispose);

      await queue.retryDeadLetter('missing');

      expect(db.select('SELECT * FROM pending_writes'), isEmpty);
    });
  });
}
