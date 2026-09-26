import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:penguin_core/penguin_core.dart';
import 'client_version_info.dart';
import 'failure_mapper.dart';
import 'retry_policy.dart';
import 'middleware/auth_client.dart';
import 'middleware/retry_client.dart';
import 'middleware/sanitized_log_client.dart';
import 'middleware/trace_client.dart';

/// Shared product-API client for every penguinm app: a `package:http`
/// middleware chain (auth with refresh-and-replay, retry with exponential
/// backoff, tracing, sanitized logging) returning [Result]-typed responses.
/// Observes requests through [MetricsSink] and [TraceSink] without depending
/// on telemetry directly.
class PenguinApiClient {
  /// Creates a client wrapping [inner] (defaults to `http.Client()`) with
  /// middleware layers: [AuthClient] → [RetryClient] → [TraceClient] →
  /// [SanitizedLogClient]. All dependencies are injectable for testing.
  PenguinApiClient({
    required AppConfig config,
    required TokenProvider tokens,
    MetricsSink metrics = const NoopMetricsSink(),
    TraceSink traces = const NoopTraceSink(),
    PenguinLogger? log,
    RetryPolicy retry = const RetryPolicy(),
    http.Client? inner,
    this._timeout = const Duration(seconds: 15),
  }) : _baseUrl = config.apiBaseUrl {
    final effectiveInner = inner ?? http.Client();

    // Build middleware chain (outermost first, per spec §4.4):
    // SanitizedLogClient(TraceClient(RetryClient(AuthClient(inner)))).
    // Auth sits closest to the network so every retry attempt carries a
    // fresh token; retry wraps auth so a whole auth-refresh-replay cycle
    // counts as a single attempt; trace spans (and their traceparent)
    // wrap the full retry sequence; logging is outermost so it always
    // sees the final outcome.
    final authed = AuthClient(inner: effectiveInner, tokens: tokens);
    final retried = RetryClient(inner: authed, policy: retry);
    final traced = TraceClient(
      inner: retried,
      traces: traces,
      metrics: metrics,
    );
    _client = SanitizedLogClient(inner: traced, log: log);
  }

  /// How long to wait for a response before treating the request as a
  /// [NetworkFailure] (via [TimeoutException]).
  final Duration _timeout;
  late Uri _baseUrl;
  late http.Client _client;

  /// The composed middleware chain.
  http.Client get client => _client;

  /// Updates the API base URL (e.g., for Gazer's domain switcher), affecting
  /// all subsequent requests.
  void setBaseUrl(Uri url) {
    _baseUrl = url;
  }

  /// Sends a `GET` request to [path], decoding the JSON response via [decode].
  /// [query] parameters are included in the URL.
  Future<Result<T>> get<T>(
    String path, {
    Map<String, Object?>? query,
    required T Function(Object? json) decode,
  }) async {
    return _request<T>('GET', path, query: query, decode: decode);
  }

  /// Sends a `POST` request to [path] with [body], decoding the response via
  /// [decode]. [idempotencyKey] (if provided) enables retry safety.
  Future<Result<T>> post<T>(
    String path, {
    Object? body,
    String? idempotencyKey,
    required T Function(Object? json) decode,
  }) async {
    return _request<T>(
      'POST',
      path,
      body: body,
      idempotencyKey: idempotencyKey,
      decode: decode,
    );
  }

  /// Sends a `PUT` request to [path] with [body], decoding the response via
  /// [decode]. [idempotencyKey] (if provided) enables retry safety.
  Future<Result<T>> put<T>(
    String path, {
    Object? body,
    String? idempotencyKey,
    required T Function(Object? json) decode,
  }) async {
    return _request<T>(
      'PUT',
      path,
      body: body,
      idempotencyKey: idempotencyKey,
      decode: decode,
    );
  }

  /// Sends a `PATCH` request to [path] with [body], decoding the response
  /// via [decode]. [idempotencyKey] (if provided) enables retry safety —
  /// like POST/PUT, [RetryPolicy] treats PATCH as non-idempotent by default
  /// and never retries it without one.
  Future<Result<T>> patch<T>(
    String path, {
    Object? body,
    String? idempotencyKey,
    required T Function(Object? json) decode,
  }) async {
    return _request<T>(
      'PATCH',
      path,
      body: body,
      idempotencyKey: idempotencyKey,
      decode: decode,
    );
  }

  /// Sends a `DELETE` request to [path], decoding the response via [decode].
  /// [idempotencyKey] (if provided) enables retry safety.
  Future<Result<T>> delete<T>(
    String path, {
    String? idempotencyKey,
    required T Function(Object? json) decode,
  }) async {
    return _request<T>(
      'DELETE',
      path,
      idempotencyKey: idempotencyKey,
      decode: decode,
    );
  }

  /// Fetches client version info from `GET /api/v1/client/version`,
  /// typically used for in-app update checks.
  Future<Result<ClientVersionInfo>> fetchClientVersion() async {
    return get(
      '/api/v1/client/version',
      decode: (json) {
        if (json is! Map<String, Object?>) {
          throw FormatException('Expected a JSON object');
        }
        return ClientVersionInfo.fromJson(json);
      },
    );
  }

  /// Internal request handler for all HTTP methods.
  Future<Result<T>> _request<T>(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    String? idempotencyKey,
    required T Function(Object? json) decode,
  }) async {
    try {
      // Build URL
      var url = _baseUrl.resolve(path);
      if (query != null && query.isNotEmpty) {
        url = url.replace(
          queryParameters: query
              .map((k, v) => MapEntry(k, v?.toString() ?? ''))
              .cast<String, String>(),
        );
      }

      // Build request
      late http.Request request;
      request = http.Request(method, url);

      // Add headers
      if (idempotencyKey != null) {
        request.headers['idempotency-key'] = idempotencyKey;
      }
      request.headers['content-type'] = 'application/json';

      // Add body (JSON-encoded)
      if (body != null) {
        request.body = jsonEncode(body);
      }

      // Send with timeout
      final response = await _client
          .send(request)
          .timeout(
            _timeout,
            onTimeout: () {
              throw TimeoutException('Request timeout');
            },
          );

      // Decode response body
      final responseBody = await response.stream.bytesToString();
      Object? json;
      if (responseBody.isNotEmpty) {
        try {
          json = jsonDecode(responseBody);
        } catch (_) {
          // If body is not JSON, just use the raw string
          json = responseBody;
        }
      }

      // Non-2xx responses are errors
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final failure = mapFailure(
          Exception('HTTP ${response.statusCode}'),
          response: response,
        );
        return Result.err(failure);
      }

      // Decode the response with the user's decoder
      try {
        final decoded = decode(json);
        return Result.ok(decoded);
      } catch (e, st) {
        // Never interpolate the raw exception into the failure: a decode
        // error (e.g. FormatException) commonly echoes a snippet of the
        // response body, which can carry PII or secrets. Surface only a
        // fixed message plus the exception's type; the original exception
        // stays reachable via `cause.original` for callers that need it
        // (never through `cause.toString()`/`Failure.message`, both of
        // which stay safe).
        return Result.err(UnknownFailure(_UndecodableResponse(e), st));
      }
    } catch (e, st) {
      final failure = mapFailure(e, stackTrace: st);
      return Result.err(failure);
    }
  }
}

/// Wraps a `decode` callback failure so [UnknownFailure.message] (derived
/// from `cause.toString()` in `penguin_core`) never embeds the original
/// exception's text — only its type. The real exception is kept on
/// [original] for callers that explicitly want it, but is never surfaced
/// through [toString].
class _UndecodableResponse {
  const _UndecodableResponse(this.original);

  /// The original exception thrown by the `decode` callback.
  final Object original;

  @override
  String toString() =>
      'Response could not be decoded (${original.runtimeType})';
}
