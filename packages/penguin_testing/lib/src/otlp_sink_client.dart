import 'dart:convert';
import 'dart:io';

/// Parsed `GET /summary` response from a running `tooling/otlp_sink`
/// process — the counters a smoke/contract test asserts `>= 1` against to
/// prove telemetry emission end-to-end.
class OtlpSinkSummary {
  /// Creates a summary snapshot.
  const OtlpSinkSummary({
    required this.logRecords,
    required this.metricDataPoints,
    required this.histograms,
    required this.spans,
  });

  /// Total log records received across every `/v1/logs` post.
  final int logRecords;

  /// Total metric data points received across every `/v1/metrics` post.
  final int metricDataPoints;

  /// Total histogram metrics (not data points) received.
  final int histograms;

  /// Total spans received across every `/v1/traces` post.
  final int spans;

  /// Parses a summary from the sink's `/summary` JSON body.
  factory OtlpSinkSummary.fromJson(Map<String, Object?> json) {
    return OtlpSinkSummary(
      logRecords: json['logRecords'] as int? ?? 0,
      metricDataPoints: json['metricDataPoints'] as int? ?? 0,
      histograms: json['histograms'] as int? ?? 0,
      spans: json['spans'] as int? ?? 0,
    );
  }
}

/// Thin client for a running `tooling/otlp_sink` process: reads `/summary`
/// and posts `/reset`. Built on `dart:io`'s [HttpClient] (not
/// `package:http`) so it needs no extra dependency; tests that use it must
/// run inside `HttpOverrides.runWithHttpOverrides(body, _RealHttp())` per
/// agent-rules, since `flutter_test` otherwise blocks real sockets.
class OtlpSinkClient {
  /// Creates a client pointed at [baseUrl] (e.g. `http://127.0.0.1:4318`),
  /// optionally injecting [httpClient] for tests.
  OtlpSinkClient({required this.baseUrl, HttpClient? httpClient})
    : _client = httpClient ?? HttpClient();

  /// Base URL of the running sink process.
  final Uri baseUrl;

  final HttpClient _client;

  /// Fetches and parses the sink's current counters.
  Future<OtlpSinkSummary> summary() async {
    final request = await _client.getUrl(baseUrl.resolve('/summary'));
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    return OtlpSinkSummary.fromJson(jsonDecode(body) as Map<String, Object?>);
  }

  /// Zeroes every counter on the sink, for isolating one test's emissions
  /// from another's within the same running process.
  Future<void> reset() async {
    final request = await _client.postUrl(baseUrl.resolve('/reset'));
    final response = await request.close();
    await response.drain<void>();
  }

  /// Releases the underlying [HttpClient]'s connections.
  void close() {
    _client.close(force: true);
  }
}
