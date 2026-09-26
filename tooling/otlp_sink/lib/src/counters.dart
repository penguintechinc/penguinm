/// Mutable OTLP/HTTP record counters shared by the sink's HTTP server,
/// covering the exact aggregation rules `telemetry-validate.sh` asserts
/// against.
library;

/// Accumulates counts of log records, metric data points, histogram
/// metrics, and spans decoded from OTLP/HTTP JSON payloads. One instance is
/// shared across every request handled by a running sink.
class Counters {
  /// Total `logRecords` entries seen across every `resourceLogs[].scopeLogs[]`.
  int logRecords = 0;

  /// Total data points seen across every metric's `sum`/`gauge`/`histogram`
  /// aggregation, summed regardless of aggregation type.
  int metricDataPoints = 0;

  /// Total metrics that carried a `histogram` aggregation (counts metrics,
  /// not data points).
  int histograms = 0;

  /// Total spans seen across every `resourceSpans[].scopeSpans[]`.
  int spans = 0;

  /// Zeroes every counter, as served by `POST /reset`.
  void reset() {
    logRecords = 0;
    metricDataPoints = 0;
    histograms = 0;
    spans = 0;
  }

  /// Serializes current counts into the `/summary` response shape.
  Map<String, int> toJson() => {
    'logRecords': logRecords,
    'metricDataPoints': metricDataPoints,
    'histograms': histograms,
    'spans': spans,
  };

  /// Adds `logRecords` counts from a decoded OTLP `/v1/logs` payload:
  /// `resourceLogs[].scopeLogs[].logRecords[]`. Any missing or malformed
  /// shape is skipped rather than throwing, so a partially-shaped payload
  /// still counts whatever is well-formed.
  void addLogs(Map<String, dynamic> body) {
    final resourceLogs = body['resourceLogs'];
    if (resourceLogs is! List<dynamic>) return;
    for (final resourceLog in resourceLogs) {
      if (resourceLog is! Map<String, dynamic>) continue;
      final scopeLogs = resourceLog['scopeLogs'];
      if (scopeLogs is! List<dynamic>) continue;
      for (final scopeLog in scopeLogs) {
        if (scopeLog is! Map<String, dynamic>) continue;
        final records = scopeLog['logRecords'];
        if (records is List<dynamic>) {
          logRecords += records.length;
        }
      }
    }
  }

  /// Adds `metricDataPoints`/`histograms` counts from a decoded OTLP
  /// `/v1/metrics` payload: `resourceMetrics[].scopeMetrics[].metrics[]`,
  /// summing `dataPoints` under each metric's `sum`, `gauge`, and
  /// `histogram` aggregation, and counting metrics carrying a `histogram`
  /// key separately.
  void addMetrics(Map<String, dynamic> body) {
    final resourceMetrics = body['resourceMetrics'];
    if (resourceMetrics is! List<dynamic>) return;
    for (final resourceMetric in resourceMetrics) {
      if (resourceMetric is! Map<String, dynamic>) continue;
      final scopeMetrics = resourceMetric['scopeMetrics'];
      if (scopeMetrics is! List<dynamic>) continue;
      for (final scopeMetric in scopeMetrics) {
        if (scopeMetric is! Map<String, dynamic>) continue;
        final metrics = scopeMetric['metrics'];
        if (metrics is! List<dynamic>) continue;
        for (final metric in metrics) {
          if (metric is! Map<String, dynamic>) continue;
          _addMetricDataPoints(metric);
        }
      }
    }
  }

  void _addMetricDataPoints(Map<String, dynamic> metric) {
    for (final key in const ['sum', 'gauge', 'histogram']) {
      final aggregation = metric[key];
      if (aggregation is! Map<String, dynamic>) continue;
      if (key == 'histogram') histograms += 1;
      final dataPoints = aggregation['dataPoints'];
      if (dataPoints is List<dynamic>) {
        metricDataPoints += dataPoints.length;
      }
    }
  }

  /// Adds `spans` counts from a decoded OTLP `/v1/traces` payload:
  /// `resourceSpans[].scopeSpans[].spans[]`.
  void addSpans(Map<String, dynamic> body) {
    final resourceSpans = body['resourceSpans'];
    if (resourceSpans is! List<dynamic>) return;
    for (final resourceSpan in resourceSpans) {
      if (resourceSpan is! Map<String, dynamic>) continue;
      final scopeSpans = resourceSpan['scopeSpans'];
      if (scopeSpans is! List<dynamic>) continue;
      for (final scopeSpan in scopeSpans) {
        if (scopeSpan is! Map<String, dynamic>) continue;
        final spanList = scopeSpan['spans'];
        if (spanList is List<dynamic>) {
          spans += spanList.length;
        }
      }
    }
  }
}
