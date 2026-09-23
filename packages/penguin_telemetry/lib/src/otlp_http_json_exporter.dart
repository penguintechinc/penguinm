import 'dart:convert';

import 'package:http/http.dart' as http;

import 'exporter.dart';
import 'otlp_json.dart';

/// Exports buffered telemetry as OTLP/HTTP JSON POSTs to
/// `<endpoint>/v1/{logs,metrics,traces}`. Every method catches network
/// failures, timeouts, and non-2xx responses and reports them via
/// [ExportResult] instead of throwing, so a dead collector never breaks the
/// app.
///
/// The spec's constructor list (`endpoint`, `headers`, `client`, `timeout`)
/// has no room for the OTLP resource identity (`service.name`,
/// `service.version`, extra resource attributes) that the JSON body must
/// carry, since `exportLogs`/`exportMetrics`/`exportSpans` only take the raw
/// record lists. [serviceName]/[serviceVersion]/[resourceAttributes] are
/// therefore added here — the only place that identity can live — and
/// `Telemetry.start` supplies them from `TelemetryConfig` when it builds
/// this exporter itself.
class OtlpHttpJsonExporter implements TelemetryExporter {
  /// Creates an exporter posting to [endpoint] with the given [headers] on
  /// every request; [client] is injectable for tests, [timeout] bounds each
  /// request.
  OtlpHttpJsonExporter({
    required this.endpoint,
    required this.serviceName,
    required this.serviceVersion,
    this.resourceAttributes = const <String, Object?>{},
    this.headers = const <String, String>{},
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
  }) : _client = client ?? http.Client();

  /// Base OTLP collector URL (e.g. `http://127.0.0.1:4318`).
  final Uri endpoint;

  /// Resource `service.name` attached to every exported batch.
  final String serviceName;

  /// Resource `service.version` attached to every exported batch.
  final String serviceVersion;

  /// Extra OTLP resource attributes (e.g. `deployment.environment`).
  final Map<String, Object?> resourceAttributes;

  /// Extra headers sent with every request (e.g. auth).
  final Map<String, String> headers;

  /// Per-request timeout.
  final Duration timeout;

  final http.Client _client;

  @override
  Future<ExportResult> exportLogs(List<LogRecordData> records) => _post(
    'v1/logs',
    encodeLogs(
      serviceName: serviceName,
      serviceVersion: serviceVersion,
      resourceAttributes: resourceAttributes,
      records: records,
    ),
    records.length,
  );

  @override
  Future<ExportResult> exportMetrics(List<MetricData> metrics) => _post(
    'v1/metrics',
    encodeMetrics(
      serviceName: serviceName,
      serviceVersion: serviceVersion,
      resourceAttributes: resourceAttributes,
      metrics: metrics,
    ),
    metrics.length,
  );

  @override
  Future<ExportResult> exportSpans(List<SpanData> spans) => _post(
    'v1/traces',
    encodeSpans(
      serviceName: serviceName,
      serviceVersion: serviceVersion,
      resourceAttributes: resourceAttributes,
      spans: spans,
    ),
    spans.length,
  );

  Future<ExportResult> _post(
    String path,
    Map<String, Object?> body,
    int itemCount,
  ) async {
    try {
      final uri = _resolve(path);
      final response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              ...headers,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ExportResult(ok: true, accepted: itemCount);
      }
      return ExportResult(
        ok: false,
        accepted: 0,
        error: 'HTTP ${response.statusCode}',
      );
    } on Object catch (error) {
      return ExportResult(ok: false, accepted: 0, error: error.toString());
    }
  }

  Uri _resolve(String path) {
    final basePath = endpoint.path.endsWith('/')
        ? endpoint.path.substring(0, endpoint.path.length - 1)
        : endpoint.path;
    return endpoint.replace(path: '$basePath/$path');
  }
}
