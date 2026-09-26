import 'otlp_json.dart';

/// Cross-cutting export interface for OTLP-shaped log/metric/span batches;
/// implemented by `OtlpHttpJsonExporter` for real export and [NoopExporter]
/// when no endpoint is configured.
abstract interface class TelemetryExporter {
  /// Sends buffered log records; never throws.
  Future<ExportResult> exportLogs(List<LogRecordData> records);

  /// Sends buffered metric snapshots; never throws.
  Future<ExportResult> exportMetrics(List<MetricData> metrics);

  /// Sends buffered completed spans; never throws.
  Future<ExportResult> exportSpans(List<SpanData> spans);
}

/// Outcome of a single export attempt.
class ExportResult {
  /// Creates an export outcome.
  const ExportResult({required this.ok, required this.accepted, this.error});

  /// Whether the destination accepted the batch.
  final bool ok;

  /// How many of the submitted items were accepted.
  final int accepted;

  /// Human-readable failure detail, present only when [ok] is false.
  final String? error;
}
