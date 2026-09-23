import 'dart:math';
import 'package:http/http.dart' as http;

/// Configuration for exponential backoff retry logic: delays, max attempts,
/// retryable status codes, and whether to apply random jitter.
class RetryPolicy {
  /// Creates a retry policy with exponential backoff configuration.
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 500),
    this.multiplier = 2.0,
    this.maxDelay = const Duration(seconds: 8),
    this.jitter = true,
    this.retryStatuses = const {408, 429, 500, 502, 503, 504},
  });

  /// Maximum number of attempts (including the initial request).
  final int maxAttempts;

  /// Base delay for the first retry (attempt 2).
  final Duration baseDelay;

  /// Multiplier applied to delay for each subsequent attempt.
  final double multiplier;

  /// Maximum delay between retries.
  final Duration maxDelay;

  /// Whether to add random jitter (±20%) to delays.
  final bool jitter;

  /// HTTP status codes that trigger a retry.
  final Set<int> retryStatuses;

  /// Calculates the delay for [attempt] (1-indexed), with exponential
  /// backoff formula: `min(maxDelay, baseDelay * multiplier^(attempt-1))`,
  /// plus optional ±20% jitter. Deterministic given a seeded [Random]; never
  /// negative, never exceeds [maxDelay]. Attempt 1 resolves to [baseDelay]
  /// before jitter (multiplier^0 == 1).
  Duration delayFor(int attempt, Random rng) {
    final effectiveAttempt = attempt < 1 ? 1 : attempt;
    final exponent = effectiveAttempt - 1;
    final factor = multiplier == 1.0
        ? 1.0
        : pow(multiplier, exponent).toDouble();
    final maxMs = maxDelay.inMilliseconds.toDouble();
    final rawMs = (baseDelay.inMilliseconds * factor).clamp(0.0, maxMs);

    if (!jitter) {
      return Duration(milliseconds: rawMs.round());
    }

    // Apply ±20% jitter, then re-clamp so jitter can never push the delay
    // above maxDelay or below zero.
    final jitterFactor = 0.8 + (rng.nextDouble() * 0.4); // 0.8 to 1.2
    final jitteredMs = (rawMs * jitterFactor).clamp(0.0, maxMs);
    return Duration(milliseconds: jitteredMs.round());
  }

  /// Returns true if the request should be retried based on the [request]
  /// method, the [response] status code (if any), or the [error] (if any).
  /// Never retries 401/403, POST/PUT/PATCH without `Idempotency-Key`, or
  /// attempts beyond [maxAttempts].
  bool shouldRetry(
    http.BaseRequest request,
    http.BaseResponse? response,
    Object? error,
    int attempt,
  ) {
    // Respect maxAttempts
    if (attempt >= maxAttempts) return false;

    // Never retry 401 or 403
    if (response != null &&
        (response.statusCode == 401 || response.statusCode == 403)) {
      return false;
    }

    // POST/PUT/PATCH require Idempotency-Key to retry
    final isWriteMethod = ['POST', 'PUT', 'PATCH'].contains(request.method);
    if (isWriteMethod && !request.headers.containsKey('idempotency-key')) {
      return false;
    }

    // Check response status
    if (response != null) {
      return retryStatuses.contains(response.statusCode);
    }

    // Network errors are retryable
    return true;
  }
}
