import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/src/middleware/retry_client.dart';
import 'package:penguin_api/src/retry_policy.dart';
import 'support/scripted_client.dart';

void main() {
  group('RetryClient', () {
    test('retries on 503 then succeeds', () async {
      final builder = ScriptedClientBuilder();
      builder
          .respond(method: 'GET', pathPattern: '/api', statusCode: 503)
          .respond(method: 'GET', pathPattern: '/api', statusCode: 200);

      final inner = builder.build();
      final client = RetryClient(
        inner: inner,
        policy: const RetryPolicy(maxAttempts: 2),
      );

      final response = await client.get(Uri.parse('http://example.com/api'));
      expect(response.statusCode, equals(200));
      expect(inner.seenRequests.length, equals(2));
    });

    test('does not retry 401', () async {
      final builder = ScriptedClientBuilder();
      builder.respond(method: 'GET', pathPattern: '/api', statusCode: 401);

      final inner = builder.build();
      final client = RetryClient(inner: inner);

      final response = await client.get(Uri.parse('http://example.com/api'));
      expect(response.statusCode, equals(401));
      expect(inner.seenRequests.length, equals(1));
    });

    test('does not retry POST without Idempotency-Key', () async {
      final builder = ScriptedClientBuilder();
      builder.respond(method: 'POST', pathPattern: '/api', statusCode: 500);

      final inner = builder.build();
      final client = RetryClient(inner: inner);

      final response = await client.post(
        Uri.parse('http://example.com/api'),
        body: 'data',
      );
      expect(response.statusCode, equals(500));
      expect(inner.seenRequests.length, equals(1));
    });

    test('honors Retry-After header in seconds', () async {
      final builder = ScriptedClientBuilder();
      builder
          .respondWhen(
            predicate: (req) => req.url.path.contains('/api'),
            statusCode: 503,
            headers: {'retry-after': '2'},
            description: 'First 503 with Retry-After: 2',
          )
          .respond(method: 'GET', pathPattern: '/api', statusCode: 200);

      final inner = builder.build();
      final client = RetryClient(
        inner: inner,
        policy: const RetryPolicy(
          baseDelay: Duration(milliseconds: 100),
          jitter: false,
        ),
      );

      final stopwatch = Stopwatch()..start();
      await client.get(Uri.parse('http://example.com/api'));
      stopwatch.stop();

      // Should delay at least 2 seconds due to Retry-After
      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(2000));
    });

    test('respects maxAttempts', () async {
      final builder = ScriptedClientBuilder();
      builder
          .respond(method: 'GET', pathPattern: '/api', statusCode: 503)
          .respond(method: 'GET', pathPattern: '/api', statusCode: 503)
          .respond(method: 'GET', pathPattern: '/api', statusCode: 503);

      final inner = builder.build();
      final client = RetryClient(
        inner: inner,
        policy: const RetryPolicy(maxAttempts: 2, jitter: false),
      );

      final response = await client.get(Uri.parse('http://example.com/api'));
      expect(response.statusCode, equals(503));
      expect(inner.seenRequests.length, equals(2));
    });

    test('throws StateError buffering a StreamedRequest for retry', () async {
      final builder = ScriptedClientBuilder();
      builder.respond(method: 'POST', pathPattern: '/api', statusCode: 503);

      final inner = builder.build();
      final client = RetryClient(inner: inner);

      // POST without an Idempotency-Key is never retried, so the buffering
      // StateError is thrown on the only attempt and rethrown immediately.
      final request = http.StreamedRequest(
        'POST',
        Uri.parse('http://example.com/api'),
      );
      unawaited(request.sink.close());

      await expectLater(client.send(request), throwsStateError);
    });

    test(
      'retries against a real HttpServer via a real IOClient (503 then 200)',
      () async {
        // The critical regression this proves: a real client's
        // `BaseRequest.finalize()` throws `StateError` if the same request
        // instance is sent twice. `flutter_test` intercepts real HTTP with
        // a fake client once the test binding initializes, so this must
        // run inside a real `HttpOverrides` per agent-rules.md.
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var hits = 0;
        unawaited(
          server.forEach((request) async {
            hits++;
            request.response.statusCode = hits == 1 ? 503 : 200;
            await request.response.close();
          }),
        );

        await HttpOverrides.runWithHttpOverrides(() async {
          final client = RetryClient(
            inner: IOClient(),
            policy: const RetryPolicy(
              baseDelay: Duration(milliseconds: 1),
              jitter: false,
            ),
          );

          final uri = Uri.parse(
            'http://${server.address.address}:${server.port}/test',
          );
          final response = await client.get(uri);
          expect(response.statusCode, equals(200));
        }, _RealHttp());

        expect(hits, equals(2));
        await server.close(force: true);
      },
    );
  });
}

/// Lets a test opt back into real sockets: `flutter_test` installs a fake
/// `HttpOverrides` (400 responses, no network) once the test binding is
/// initialized, so hitting a real local server needs the base
/// `HttpOverrides` — whose `createHttpClient` builds a genuine `HttpClient`
/// — active for the duration of the call. See agent-rules.md; do NOT use
/// `runZoned(createHttpClient: (ctx) => HttpClient(context: ctx))` instead —
/// that factory re-enters the override and recurses infinitely.
class _RealHttp extends HttpOverrides {}
