import 'package:penguin_core/penguin_core.dart';

/// Default histogram bucket boundaries in milliseconds, used when a caller
/// doesn't supply its own via `Meter.histogram`'s `boundaries` parameter.
const List<double> defaultMsBoundaries = <double>[
  5,
  10,
  25,
  50,
  100,
  250,
  500,
  1000,
  2500,
  5000,
  10000,
];

/// One buffered, already-sanitized log record awaiting OTLP export.
class LogRecordData {
  /// Creates a log record snapshot ready for OTLP encoding.
  const LogRecordData({
    required this.timestamp,
    required this.level,
    required this.message,
    this.attributes = const <String, Object?>{},
    this.traceId,
    this.spanId,
  });

  /// Wall-clock time the record was emitted.
  final DateTime timestamp;

  /// Severity of this record.
  final LogLevel level;

  /// Human-readable log body.
  final String message;

  /// Sanitized structured attributes attached to this record.
  final Map<String, Object?> attributes;

  /// Trace ID of the span active when this record was emitted, if any.
  final String? traceId;

  /// Span ID of the span active when this record was emitted, if any.
  final String? spanId;
}

/// Which OTLP aggregation a [MetricData] carries.
enum MetricKind {
  /// A monotonic cumulative sum, from a counter.
  sum,

  /// A single current-value reading, from a gauge.
  gauge,

  /// A cumulative histogram.
  histogram,
}

/// One data point of a sum or gauge metric.
class MetricDataPoint {
  /// Creates a single sum/gauge data point.
  const MetricDataPoint({
    required this.startTime,
    required this.time,
    required this.value,
    this.attributes = const <String, Object?>{},
  });

  /// When this instrument's aggregation window started.
  final DateTime startTime;

  /// When this reading was taken.
  final DateTime time;

  /// The current cumulative sum, or current gauge reading.
  final double value;

  /// Attributes identifying this data point's series.
  final Map<String, Object?> attributes;
}

/// One data point of a histogram metric.
class HistogramDataPoint {
  /// Creates a single histogram data point.
  const HistogramDataPoint({
    required this.startTime,
    required this.time,
    required this.count,
    required this.sum,
    required this.bucketCounts,
    required this.explicitBounds,
    this.attributes = const <String, Object?>{},
  });

  /// When this instrument's aggregation window started.
  final DateTime startTime;

  /// When this reading was taken.
  final DateTime time;

  /// Total number of observations recorded so far.
  final int count;

  /// Sum of every observation recorded so far.
  final double sum;

  /// Cumulative count per bucket; one longer than [explicitBounds].
  final List<int> bucketCounts;

  /// Upper bound (inclusive) of every bucket except the implicit last.
  final List<double> explicitBounds;

  /// Attributes identifying this data point's series.
  final Map<String, Object?> attributes;
}

/// One buffered metric (all data points sharing a name/kind) awaiting OTLP
/// export.
class MetricData {
  /// Creates a monotonic sum metric snapshot.
  const MetricData.sum({
    required this.name,
    required List<MetricDataPoint> dataPoints,
    this.unit = '1',
    this.description = '',
  }) : kind = MetricKind.sum,
       sumPoints = dataPoints,
       histogramPoints = const <HistogramDataPoint>[];

  /// Creates a gauge metric snapshot.
  const MetricData.gauge({
    required this.name,
    required List<MetricDataPoint> dataPoints,
    this.unit = '1',
    this.description = '',
  }) : kind = MetricKind.gauge,
       sumPoints = dataPoints,
       histogramPoints = const <HistogramDataPoint>[];

  /// Creates a histogram metric snapshot.
  const MetricData.histogram({
    required this.name,
    required List<HistogramDataPoint> dataPoints,
    this.unit = 'ms',
    this.description = '',
  }) : kind = MetricKind.histogram,
       sumPoints = const <MetricDataPoint>[],
       histogramPoints = dataPoints;

  /// Instrument name (e.g. `http.client.request.duration`).
  final String name;

  /// Unit string (`1`, `ms`, `By`, ...).
  final String unit;

  /// Human-readable description.
  final String description;

  /// Which aggregation this metric carries.
  final MetricKind kind;

  /// Data points when [kind] is [MetricKind.sum] or [MetricKind.gauge].
  final List<MetricDataPoint> sumPoints;

  /// Data points when [kind] is [MetricKind.histogram].
  final List<HistogramDataPoint> histogramPoints;
}

/// OTel span kind, matching the proto `Span.SpanKind` wire values.
enum SpanKind {
  /// Default; no cross-process relationship implied.
  internal,

  /// Synchronous outbound request (e.g. an HTTP client call).
  client,

  /// Synchronous inbound request handler.
  server,

  /// Async message producer.
  producer,

  /// Async message consumer.
  consumer,
}

/// OTel span status code, matching the proto `Status.StatusCode` wire
/// values.
enum SpanStatusCode {
  /// Default; the operation's outcome wasn't set.
  unset,

  /// The operation completed successfully.
  ok,

  /// The operation failed.
  error,
}

/// A span's terminal status, set via `Span.setStatus` or implicitly by
/// `Span.recordError`.
class SpanStatus {
  /// Creates a span status with an optional human-readable [message].
  const SpanStatus(this.code, [this.message]);

  /// Status not yet set.
  static const SpanStatus unset = SpanStatus(SpanStatusCode.unset);

  /// Operation completed successfully.
  static const SpanStatus ok = SpanStatus(SpanStatusCode.ok);

  /// Operation failed.
  static const SpanStatus error = SpanStatus(SpanStatusCode.error);

  /// The status code.
  final SpanStatusCode code;

  /// Optional human-readable detail.
  final String? message;
}

/// One buffered, completed span awaiting OTLP export.
class SpanData {
  /// Creates a completed span snapshot ready for OTLP encoding.
  const SpanData({
    required this.traceId,
    required this.spanId,
    required this.name,
    required this.kind,
    required this.startTime,
    required this.endTime,
    this.parentSpanId,
    this.attributes = const <String, Object?>{},
    this.status = SpanStatus.unset,
  });

  /// 32-hex-character trace ID shared by every span in this trace.
  final String traceId;

  /// 16-hex-character span ID unique within [traceId].
  final String spanId;

  /// The parent span's ID, if this span was started with a parent.
  final String? parentSpanId;

  /// The operation name.
  final String name;

  /// The span kind.
  final SpanKind kind;

  /// When the span started.
  final DateTime startTime;

  /// When the span ended.
  final DateTime endTime;

  /// Sanitized attributes attached to the span.
  final Map<String, Object?> attributes;

  /// The span's terminal status.
  final SpanStatus status;
}

String _nanos(DateTime time) => (time.microsecondsSinceEpoch * 1000).toString();

List<Map<String, Object?>> _encodeAttributes(Map<String, Object?> attributes) {
  final encoded = <Map<String, Object?>>[];
  for (final entry in attributes.entries) {
    final value = _encodeAnyValue(entry.value);
    if (value == null) continue;
    encoded.add(<String, Object?>{'key': entry.key, 'value': value});
  }
  return encoded;
}

Map<String, Object?>? _encodeAnyValue(Object? value) {
  if (value == null) return null;
  if (value is String) return <String, Object?>{'stringValue': value};
  if (value is bool) return <String, Object?>{'boolValue': value};
  if (value is int) return <String, Object?>{'intValue': value.toString()};
  if (value is double) return <String, Object?>{'doubleValue': value};
  return <String, Object?>{'stringValue': value.toString()};
}

int _severityNumber(LogLevel level) => switch (level) {
  LogLevel.debug => 5,
  LogLevel.info => 9,
  LogLevel.warn => 13,
  LogLevel.error => 17,
};

String _severityText(LogLevel level) => level.name.toUpperCase();

int _spanKindNumber(SpanKind kind) => switch (kind) {
  SpanKind.internal => 1,
  SpanKind.server => 2,
  SpanKind.client => 3,
  SpanKind.producer => 4,
  SpanKind.consumer => 5,
};

int _statusCodeNumber(SpanStatusCode code) => switch (code) {
  SpanStatusCode.unset => 0,
  SpanStatusCode.ok => 1,
  SpanStatusCode.error => 2,
};

Map<String, Object?> _resource(
  String serviceName,
  String serviceVersion,
  Map<String, Object?> resourceAttributes,
) {
  return <String, Object?>{
    'attributes': _encodeAttributes(<String, Object?>{
      'service.name': serviceName,
      'service.version': serviceVersion,
      ...resourceAttributes,
    }),
  };
}

Map<String, Object?> _scope(String serviceVersion) => <String, Object?>{
  'name': 'penguin_telemetry',
  'version': serviceVersion,
};

/// Encodes buffered [records] into the OTLP/HTTP JSON `/v1/logs` request
/// body shape.
Map<String, Object?> encodeLogs({
  required String serviceName,
  required String serviceVersion,
  required Map<String, Object?> resourceAttributes,
  required List<LogRecordData> records,
}) {
  return <String, Object?>{
    'resourceLogs': <Object?>[
      <String, Object?>{
        'resource': _resource(serviceName, serviceVersion, resourceAttributes),
        'scopeLogs': <Object?>[
          <String, Object?>{
            'scope': _scope(serviceVersion),
            'logRecords': records.map(_encodeLogRecord).toList(),
          },
        ],
      },
    ],
  };
}

Map<String, Object?> _encodeLogRecord(LogRecordData record) {
  return <String, Object?>{
    'timeUnixNano': _nanos(record.timestamp),
    'severityNumber': _severityNumber(record.level),
    'severityText': _severityText(record.level),
    'body': <String, Object?>{'stringValue': record.message},
    'attributes': _encodeAttributes(record.attributes),
    if (record.traceId != null) 'traceId': record.traceId,
    if (record.spanId != null) 'spanId': record.spanId,
  };
}

/// Encodes buffered [metrics] into the OTLP/HTTP JSON `/v1/metrics` request
/// body shape.
Map<String, Object?> encodeMetrics({
  required String serviceName,
  required String serviceVersion,
  required Map<String, Object?> resourceAttributes,
  required List<MetricData> metrics,
}) {
  return <String, Object?>{
    'resourceMetrics': <Object?>[
      <String, Object?>{
        'resource': _resource(serviceName, serviceVersion, resourceAttributes),
        'scopeMetrics': <Object?>[
          <String, Object?>{
            'scope': _scope(serviceVersion),
            'metrics': metrics.map(_encodeMetric).toList(),
          },
        ],
      },
    ],
  };
}

Map<String, Object?> _encodeMetric(MetricData metric) {
  final aggregation = switch (metric.kind) {
    MetricKind.sum =>
      MapEntry<String, Map<String, Object?>>('sum', <String, Object?>{
        'dataPoints': metric.sumPoints.map(_encodeNumberDataPoint).toList(),
        'isMonotonic': true,
        'aggregationTemporality': 2,
      }),
    MetricKind.gauge => MapEntry<String, Map<String, Object?>>(
      'gauge',
      <String, Object?>{
        'dataPoints': metric.sumPoints.map(_encodeNumberDataPoint).toList(),
      },
    ),
    MetricKind.histogram =>
      MapEntry<String, Map<String, Object?>>('histogram', <String, Object?>{
        'dataPoints': metric.histogramPoints
            .map(_encodeHistogramDataPoint)
            .toList(),
        'aggregationTemporality': 2,
      }),
  };
  return <String, Object?>{
    'name': metric.name,
    'unit': metric.unit,
    'description': metric.description,
    aggregation.key: aggregation.value,
  };
}

Map<String, Object?> _encodeNumberDataPoint(MetricDataPoint point) {
  return <String, Object?>{
    'startTimeUnixNano': _nanos(point.startTime),
    'timeUnixNano': _nanos(point.time),
    'asDouble': point.value,
    'attributes': _encodeAttributes(point.attributes),
  };
}

Map<String, Object?> _encodeHistogramDataPoint(HistogramDataPoint point) {
  return <String, Object?>{
    'startTimeUnixNano': _nanos(point.startTime),
    'timeUnixNano': _nanos(point.time),
    'count': point.count,
    'sum': point.sum,
    'bucketCounts': point.bucketCounts,
    'explicitBounds': point.explicitBounds,
    'attributes': _encodeAttributes(point.attributes),
  };
}

/// Encodes buffered [spans] into the OTLP/HTTP JSON `/v1/traces` request
/// body shape.
Map<String, Object?> encodeSpans({
  required String serviceName,
  required String serviceVersion,
  required Map<String, Object?> resourceAttributes,
  required List<SpanData> spans,
}) {
  return <String, Object?>{
    'resourceSpans': <Object?>[
      <String, Object?>{
        'resource': _resource(serviceName, serviceVersion, resourceAttributes),
        'scopeSpans': <Object?>[
          <String, Object?>{
            'scope': _scope(serviceVersion),
            'spans': spans.map(_encodeSpan).toList(),
          },
        ],
      },
    ],
  };
}

Map<String, Object?> _encodeSpan(SpanData span) {
  return <String, Object?>{
    'traceId': span.traceId,
    'spanId': span.spanId,
    if (span.parentSpanId != null) 'parentSpanId': span.parentSpanId,
    'name': span.name,
    'kind': _spanKindNumber(span.kind),
    'startTimeUnixNano': _nanos(span.startTime),
    'endTimeUnixNano': _nanos(span.endTime),
    'attributes': _encodeAttributes(span.attributes),
    'status': <String, Object?>{'code': _statusCodeNumber(span.status.code)},
  };
}
