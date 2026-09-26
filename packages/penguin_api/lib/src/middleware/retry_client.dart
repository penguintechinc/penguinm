import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../retry_policy.dart';
import 'request_replay.dart';

/// Middleware that retries requests following [RetryPolicy]: exponential
/// backoff, respects `Retry-After` headers (in seconds), and honors the
/// policy's logic for non-retryable cases (401/403, non-idempotent writes,
/// max attempts exceeded). Every attempt sends an independent copy of the
/// request (via [copyRequestForReplay]) — `BaseRequest.finalize()` marks a
/// request finalized on first send, so reusing the same instance across
/// attempts throws `StateError` against any real client.
class RetryClient extends http.BaseClient {
  /// Creates a retry middleware wrapping [inner]. `inner`/`policy` are
  /// initializing formals bound to private fields (`_inner`/`_policy`) —
  /// Dart exposes the underscore-stripped name as the external label, so
  /// the public constructor call site (`RetryClient(inner: ..., policy:
  /// ...)`) is unchanged.
  RetryClient({required this._inner, this._policy = const RetryPolicy()})
    : _rng = Random();

  final http.Client _inner;
  final RetryPolicy _policy;
  final Random _rng;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    http.StreamedResponse? response;
    Object? lastError;

    for (int attempt = 1; attempt <= _policy.maxAttempts; attempt++) {
      try {
        // Every attempt gets its own fresh copy — the original `request` is
        // never itself sent, so it never gets marked finalized and can be
        // copied again on the next attempt.
        final attemptRequest = copyRequestForReplay(request);
        response = await _inner.send(attemptRequest);

        // Check if we should retry this response
        if (!_policy.shouldRetry(attemptRequest, response, null, attempt)) {
          return response;
        }

        // Compute retry delay
        final retryAfter = _parseRetryAfter(response);
        final delay = retryAfter ?? _policy.delayFor(attempt, _rng);

        // Don't retry on the last attempt
        if (attempt >= _policy.maxAttempts) {
          return response;
        }

        // Wait before retrying
        await Future<void>.delayed(delay);
      } on Object catch (e) {
        lastError = e;

        // Check if we should retry this error
        if (!_policy.shouldRetry(request, null, e, attempt)) {
          rethrow;
        }

        // Don't retry on the last attempt
        if (attempt >= _policy.maxAttempts) {
          rethrow;
        }

        // Wait before retrying
        final delay = _policy.delayFor(attempt, _rng);
        await Future<void>.delayed(delay);
      }
    }

    // Return last response or throw last error
    if (response != null) {
      return response;
    }
    throw lastError ??
        StateError('No response after ${_policy.maxAttempts} attempts');
  }

  /// Parses `Retry-After` header value (seconds) if present.
  Duration? _parseRetryAfter(http.BaseResponse response) {
    final retryAfter = response.headers['retry-after'];
    if (retryAfter == null) return null;

    // Parse as integer (seconds)
    try {
      final seconds = int.parse(retryAfter);
      return Duration(seconds: seconds);
    } catch (_) {
      // Could also be an HTTP-date, but we only support seconds
      return null;
    }
  }
}
