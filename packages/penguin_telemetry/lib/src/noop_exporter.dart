import 'exporter.dart';
import 'otlp_json.dart';

/// [TelemetryExporter] used when no OTLP endpoint is configured — every
/// call reports success with zero accepted items so callers never treat a
/// disabled exporter as a failure.
class NoopExporter implements TelemetryExporter {
  /// Creates a no-op exporter.
  const NoopExporter();

  @override
  Future<ExportResult> exportLogs(List<LogRecordData> records) async =>
      const ExportResult(ok: true, accepted: 0);

  @override
  Future<ExportResult> exportMetrics(List<MetricData> metrics) async =>
      const ExportResult(ok: true, accepted: 0);

  @override
  Future<ExportResult> exportSpans(List<SpanData> spans) async =>
      const ExportResult(ok: true, accepted: 0);
}
