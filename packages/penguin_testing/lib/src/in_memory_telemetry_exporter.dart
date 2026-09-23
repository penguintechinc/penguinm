import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_telemetry/penguin_telemetry.dart';

/// In-memory [TelemetryExporter] fake: every exported log record, metric,
/// and span is appended to a list instead of leaving the process, so tests
/// can assert exactly what `Telemetry` emitted.
class InMemoryTelemetryExporter implements TelemetryExporter {
  /// Every log record accepted by [exportLogs] so far, in order.
  final List<LogRecordData> logs = <LogRecordData>[];

  /// Every metric snapshot accepted by [exportMetrics] so far, in order
  /// (one [MetricData] per instrument per export call).
  final List<MetricData> metrics = <MetricData>[];

  /// Every span accepted by [exportSpans] so far, in order.
  final List<SpanData> spans = <SpanData>[];

  @override
  Future<ExportResult> exportLogs(List<LogRecordData> records) async {
    logs.addAll(records);
    return ExportResult(ok: true, accepted: records.length);
  }

  @override
  Future<ExportResult> exportMetrics(List<MetricData> metrics) async {
    this.metrics.addAll(metrics);
    return ExportResult(ok: true, accepted: metrics.length);
  }

  @override
  Future<ExportResult> exportSpans(List<SpanData> spans) async {
    this.spans.addAll(spans);
    return ExportResult(ok: true, accepted: spans.length);
  }

  /// Asserts a histogram metric named [name] was exported, returning it for
  /// further assertions (bucket counts, sum). Fails with a message listing
  /// every metric name/kind actually recorded when none matches, per the
  /// "a check must prove it ran" verification standard.
  MetricData expectHistogram(String name) {
    for (final metric in metrics) {
      if (metric.kind == MetricKind.histogram && metric.name == name) {
        return metric;
      }
    }
    final seen = metrics
        .map((metric) => '${metric.name} (${metric.kind.name})')
        .toList();
    fail(
      'Expected an exported histogram named "$name" but recorded metrics '
      'were: $seen',
    );
  }

  /// Clears every recorded log, metric, and span.
  void reset() {
    logs.clear();
    metrics.clear();
    spans.clear();
  }
}
