import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/src/retry_policy.dart';

void main() {
  group('RetryPolicy', () {
    group('delayFor', () {
      test('calculates exponential backoff with correct formula', () {
        const policy = RetryPolicy(
          baseDelay: Duration(milliseconds: 100),
          multiplier: 2.0,
          maxDelay: Duration(seconds: 10),
          jitter: false,
        );
        final rng = Random(42);

        expect(policy.delayFor(1, rng).inMilliseconds, equals(100));
        expect(policy.delayFor(2, rng).inMilliseconds, equals(200));
        expect(policy.delayFor(3, rng).inMilliseconds, equals(400));
        expect(policy.delayFor(4, rng).inMilliseconds, equals(800));
      });

      test('respects maxDelay cap', () {
        const policy = RetryPolicy(
          baseDelay: Duration(milliseconds: 500),
          multiplier: 2.0,
          maxDelay: Duration(milliseconds: 1000),
          jitter: false,
        );
        final rng = Random(42);

        expect(policy.delayFor(5, rng).inMilliseconds, equals(1000));
      });

      test('adds jitter when enabled', () {
        const policy = RetryPolicy(
          baseDelay: Duration(milliseconds: 1000),
          multiplier: 1.0,
          maxDelay: Duration(seconds: 10),
          jitter: true,
        );
        final rng = Random(42);

        final delays = <int>[
          policy.delayFor(1, rng).inMilliseconds,
          policy.delayFor(1, Random(43)).inMilliseconds,
          policy.delayFor(1, Random(44)).inMilliseconds,
        ];

        // All should be within ±20% of base delay
        expect(delays[0], greaterThanOrEqualTo(800));
        expect(delays[0], lessThanOrEqualTo(1200));

        // But they should not all be the same due to jitter
        expect(delays.toSet().length, greaterThan(1));
      });
    });

    group('shouldRetry', () {
      test('does not retry 401 Unauthorized', () {
        const policy = RetryPolicy();
        final request = _FakeRequest('GET', Uri.parse('http://example.com'));
        final response = _FakeResponse(401);

        expect(policy.shouldRetry(request, response, null, 1), isFalse);
      });

      test('does not retry 403 Forbidden', () {
        const policy = RetryPolicy();
        final request = _FakeRequest('GET', Uri.parse('http://example.com'));
        final response = _FakeResponse(403);

        expect(policy.shouldRetry(request, response, null, 1), isFalse);
      });

      test('does not retry POST without Idempotency-Key', () {
        const policy = RetryPolicy();
        final request = _FakeRequest('POST', Uri.parse('http://example.com'));
        final response = _FakeResponse(500);

        expect(policy.shouldRetry(request, response, null, 1), isFalse);
      });

      test('retries POST with Idempotency-Key', () {
        const policy = RetryPolicy();
        final request = _FakeRequest(
          'POST',
          Uri.parse('http://example.com'),
          headers: {'idempotency-key': 'test-key'},
        );
        final response = _FakeResponse(500);

        expect(policy.shouldRetry(request, response, null, 1), isTrue);
      });

      test('retries retryable status codes', () {
        const policy = RetryPolicy(
          retryStatuses: {408, 429, 500, 502, 503, 504},
        );
        final request = _FakeRequest('GET', Uri.parse('http://example.com'));

        for (final status in [408, 429, 500, 502, 503, 504]) {
          final response = _FakeResponse(status);
          expect(
            policy.shouldRetry(request, response, null, 1),
            isTrue,
            reason: 'Should retry $status',
          );
        }
      });

      test('does not retry non-retryable status codes', () {
        const policy = RetryPolicy(
          retryStatuses: {408, 429, 500, 502, 503, 504},
        );
        final request = _FakeRequest('GET', Uri.parse('http://example.com'));

        for (final status in [400, 404, 409]) {
          final response = _FakeResponse(status);
          expect(
            policy.shouldRetry(request, response, null, 1),
            isFalse,
            reason: 'Should not retry $status',
          );
        }
      });

      test('respects maxAttempts', () {
        const policy = RetryPolicy(maxAttempts: 3);
        final request = _FakeRequest('GET', Uri.parse('http://example.com'));
        final response = _FakeResponse(503);

        expect(policy.shouldRetry(request, response, null, 1), isTrue);
        expect(policy.shouldRetry(request, response, null, 2), isTrue);
        expect(policy.shouldRetry(request, response, null, 3), isFalse);
      });

      test('retries ClientException', () {
        const policy = RetryPolicy();
        final request = _FakeRequest('GET', Uri.parse('http://example.com'));
        final error = Exception('Connection failed');

        expect(policy.shouldRetry(request, null, error, 1), isTrue);
      });

      test('respects maxAttempts for exceptions', () {
        const policy = RetryPolicy(maxAttempts: 2);
        final request = _FakeRequest('GET', Uri.parse('http://example.com'));
        final error = Exception('Connection failed');

        expect(policy.shouldRetry(request, null, error, 1), isTrue);
        expect(policy.shouldRetry(request, null, error, 2), isFalse);
      });
    });
  });
}

class _FakeRequest extends http.BaseRequest {
  _FakeRequest(super.method, super.url, {Map<String, String>? headers}) {
    if (headers != null) this.headers.addAll(headers);
  }

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream.fromBytes([]);
  }
}

class _FakeResponse extends http.BaseResponse {
  _FakeResponse(super.statusCode) : super(contentLength: 0, headers: const {});
}
