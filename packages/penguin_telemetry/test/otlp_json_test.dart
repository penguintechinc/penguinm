import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_telemetry/src/otlp_json.dart';

void main() {
  final startTime = DateTime.utc(2026, 1, 1);
  final endTime = startTime.add(const Duration(milliseconds: 42));
  final traceId = 'a'.padRight(32, 'a');
  final spanId = 'b'.padRight(16, 'b');
  final parentSpanId = 'c'.padRight(16, 'c');

  test('encodeLogs produces the OTLP/HTTP JSON log shape for one record', () {
    final body = encodeLogs(
      serviceName: 'gazer',
      serviceVersion: '1.2.3',
      resourceAttributes: const <String, Object?>{
        'deployment.environment': 'beta',
      },
      records: <LogRecordData>[
        LogRecordData(
          timestamp: startTime,
          level: LogLevel.info,
          message: 'user signed in',
          attributes: const <String, Object?>{'userId': 'u-1'},
        ),
      ],
    );

    final resourceLogs = body['resourceLogs']! as List<Object?>;
    expect(resourceLogs, hasLength(1));
    final resourceLog = resourceLogs.single! as Map<String, Object?>;
    final resource = resourceLog['resource']! as Map<String, Object?>;
    final resourceAttrs = resource['attributes']! as List<Object?>;
    expect(
      resourceAttrs,
      contains(
        equals(<String, Object?>{
          'key': 'service.name',
          'value': <String, Object?>{'stringValue': 'gazer'},
        }),
      ),
    );

    final scopeLogs = resourceLog['scopeLogs']! as List<Object?>;
    final scopeLog = scopeLogs.single! as Map<String, Object?>;
    final logRecords = scopeLog['logRecords']! as List<Object?>;
    final record = logRecords.single! as Map<String, Object?>;

    expect(record['severityNumber'], 9);
    expect(record['severityText'], 'INFO');
    expect(record['body'], <String, Object?>{'stringValue': 'user signed in'});
    expect(record['attributes'], <Object?>[
      <String, Object?>{
        'key': 'userId',
        'value': <String, Object?>{'stringValue': 'u-1'},
      },
    ]);
    expect(record.containsKey('timeUnixNano'), isTrue);
    expect(record.containsKey('traceId'), isFalse);
  });

  test('encodeLogs includes traceId/spanId only when present', () {
    final body = encodeLogs(
      serviceName: 's',
      serviceVersion: '1',
      resourceAttributes: const <String, Object?>{},
      records: <LogRecordData>[
        LogRecordData(
          timestamp: startTime,
          level: LogLevel.error,
          message: 'x',
          traceId: traceId,
          spanId: spanId,
        ),
      ],
    );

    final record = _firstLogRecord(body);
    expect(record['traceId'], traceId);
    expect(record['spanId'], spanId);
    expect(record['severityText'], 'ERROR');
  });

  test('encodeMetrics produces the OTLP/HTTP JSON sum shape for a counter', () {
    final body = encodeMetrics(
      serviceName: 'gazer',
      serviceVersion: '1.0.0',
      resourceAttributes: const <String, Object?>{},
      metrics: <MetricData>[
        MetricData.sum(
          name: 'requests.total',
          dataPoints: <MetricDataPoint>[
            MetricDataPoint(
              startTime: startTime,
              time: endTime,
              value: 3,
              attributes: const <String, Object?>{'route': '/x'},
            ),
          ],
        ),
      ],
    );

    final metric = _firstMetric(body);
    expect(metric['name'], 'requests.total');
    final sum = metric['sum']! as Map<String, Object?>;
    expect(sum['isMonotonic'], isTrue);
    expect(sum['aggregationTemporality'], 2);
    final dataPoints = sum['dataPoints']! as List<Object?>;
    final point = dataPoints.single! as Map<String, Object?>;
    expect(point['asDouble'], 3.0);
    expect(point.containsKey('startTimeUnixNano'), isTrue);
    expect(point.containsKey('timeUnixNano'), isTrue);
    expect(point['attributes'], <Object?>[
      <String, Object?>{
        'key': 'route',
        'value': <String, Object?>{'stringValue': '/x'},
      },
    ]);
  });

  test('encodeMetrics produces the OTLP/HTTP JSON gauge shape', () {
    final body = encodeMetrics(
      serviceName: 's',
      serviceVersion: '1',
      resourceAttributes: const <String, Object?>{},
      metrics: <MetricData>[
        MetricData.gauge(
          name: 'battery.level',
          dataPoints: <MetricDataPoint>[
            MetricDataPoint(startTime: startTime, time: endTime, value: 80),
          ],
        ),
      ],
    );

    final metric = _firstMetric(body);
    final gauge = metric['gauge']! as Map<String, Object?>;
    final point =
        (gauge['dataPoints']! as List<Object?>).single! as Map<String, Object?>;
    expect(point['asDouble'], 80.0);
    expect(gauge.containsKey('aggregationTemporality'), isFalse);
  });

  test('encodeMetrics produces the OTLP/HTTP JSON histogram shape', () {
    final body = encodeMetrics(
      serviceName: 'gazer',
      serviceVersion: '1.0.0',
      resourceAttributes: const <String, Object?>{},
      metrics: <MetricData>[
        MetricData.histogram(
          name: 'route.duration',
          dataPoints: <HistogramDataPoint>[
            HistogramDataPoint(
              startTime: startTime,
              time: endTime,
              count: 2,
              sum: 30,
              bucketCounts: const <int>[0, 2, 0],
              explicitBounds: const <double>[10, 100],
            ),
          ],
        ),
      ],
    );

    final metric = _firstMetric(body);
    final histogram = metric['histogram']! as Map<String, Object?>;
    expect(histogram['aggregationTemporality'], 2);
    final point =
        (histogram['dataPoints']! as List<Object?>).single!
            as Map<String, Object?>;
    expect(point['count'], 2);
    expect(point['sum'], 30.0);
    expect(point['bucketCounts'], <int>[0, 2, 0]);
    expect(point['explicitBounds'], <double>[10, 100]);
  });

  test('encodeSpans produces the OTLP/HTTP JSON span shape', () {
    final body = encodeSpans(
      serviceName: 'gazer',
      serviceVersion: '1.0.0',
      resourceAttributes: const <String, Object?>{},
      spans: <SpanData>[
        SpanData(
          traceId: traceId,
          spanId: spanId,
          parentSpanId: parentSpanId,
          name: 'GET /x',
          kind: SpanKind.client,
          startTime: startTime,
          endTime: endTime,
          attributes: const <String, Object?>{'http.response.status_code': 200},
          status: SpanStatus.ok,
        ),
      ],
    );

    final span = _firstSpan(body);
    expect(span['traceId'], traceId);
    expect(span['spanId'], spanId);
    expect(span['parentSpanId'], parentSpanId);
    expect(span['name'], 'GET /x');
    expect(span['kind'], 3);
    expect(span['status'], <String, Object?>{'code': 1});
    expect(span.containsKey('startTimeUnixNano'), isTrue);
    expect(span.containsKey('endTimeUnixNano'), isTrue);
    expect(span['attributes'], <Object?>[
      <String, Object?>{
        'key': 'http.response.status_code',
        'value': <String, Object?>{'intValue': '200'},
      },
    ]);
  });

  test(
    'encodeSpans omits parentSpanId when absent and defaults status/kind',
    () {
      final body = encodeSpans(
        serviceName: 's',
        serviceVersion: '1',
        resourceAttributes: const <String, Object?>{},
        spans: <SpanData>[
          SpanData(
            traceId: traceId,
            spanId: spanId,
            name: 'root',
            kind: SpanKind.internal,
            startTime: startTime,
            endTime: endTime,
          ),
        ],
      );

      final span = _firstSpan(body);
      expect(span.containsKey('parentSpanId'), isFalse);
      expect(span['kind'], 1);
      expect(span['status'], <String, Object?>{'code': 0});
    },
  );

  test('every SpanKind encodes to its OTel wire value', () {
    const kinds = <SpanKind, int>{
      SpanKind.internal: 1,
      SpanKind.server: 2,
      SpanKind.client: 3,
      SpanKind.producer: 4,
      SpanKind.consumer: 5,
    };
    for (final entry in kinds.entries) {
      final span = _firstSpan(
        encodeSpans(
          serviceName: 's',
          serviceVersion: '1',
          resourceAttributes: const <String, Object?>{},
          spans: <SpanData>[
            SpanData(
              traceId: traceId,
              spanId: spanId,
              name: 'x',
              kind: entry.key,
              startTime: startTime,
              endTime: endTime,
            ),
          ],
        ),
      );
      expect(span['kind'], entry.value, reason: '${entry.key}');
    }
  });

  test('every SpanStatusCode encodes to its OTel wire value', () {
    const statuses = <SpanStatus, int>{
      SpanStatus.unset: 0,
      SpanStatus.ok: 1,
      SpanStatus.error: 2,
    };
    for (final entry in statuses.entries) {
      final span = _firstSpan(
        encodeSpans(
          serviceName: 's',
          serviceVersion: '1',
          resourceAttributes: const <String, Object?>{},
          spans: <SpanData>[
            SpanData(
              traceId: traceId,
              spanId: spanId,
              name: 'x',
              kind: SpanKind.internal,
              startTime: startTime,
              endTime: endTime,
              status: entry.key,
            ),
          ],
        ),
      );
      expect(span['status'], <String, Object?>{
        'code': entry.value,
      }, reason: '${entry.key}');
    }
  });

  test('attribute values encode by runtime type', () {
    final body = encodeLogs(
      serviceName: 's',
      serviceVersion: '1',
      resourceAttributes: const <String, Object?>{},
      records: <LogRecordData>[
        LogRecordData(
          timestamp: startTime,
          level: LogLevel.info,
          message: 'x',
          attributes: const <String, Object?>{
            'flag': true,
            'ratio': 1.5,
            'nothing': null,
            'other': Duration(seconds: 1),
          },
        ),
      ],
    );

    final attrs = _firstLogRecord(body)['attributes']! as List<Object?>;
    final byKey = {
      for (final entry in attrs.cast<Map<String, Object?>>())
        entry['key']: entry['value'],
    };
    expect(byKey['flag'], <String, Object?>{'boolValue': true});
    expect(byKey['ratio'], <String, Object?>{'doubleValue': 1.5});
    expect(byKey.containsKey('nothing'), isFalse);
    expect(byKey['other'], <String, Object?>{
      'stringValue': const Duration(seconds: 1).toString(),
    });
  });
}

Map<String, Object?> _firstLogRecord(Map<String, Object?> body) {
  final resourceLogs = body['resourceLogs']! as List<Object?>;
  final scopeLogs =
      (resourceLogs.single! as Map<String, Object?>)['scopeLogs']!
          as List<Object?>;
  final records =
      (scopeLogs.single! as Map<String, Object?>)['logRecords']!
          as List<Object?>;
  return records.single! as Map<String, Object?>;
}

Map<String, Object?> _firstMetric(Map<String, Object?> body) {
  final resourceMetrics = body['resourceMetrics']! as List<Object?>;
  final scopeMetrics =
      (resourceMetrics.single! as Map<String, Object?>)['scopeMetrics']!
          as List<Object?>;
  final metrics =
      (scopeMetrics.single! as Map<String, Object?>)['metrics']!
          as List<Object?>;
  return metrics.single! as Map<String, Object?>;
}

Map<String, Object?> _firstSpan(Map<String, Object?> body) {
  final resourceSpans = body['resourceSpans']! as List<Object?>;
  final scopeSpans =
      (resourceSpans.single! as Map<String, Object?>)['scopeSpans']!
          as List<Object?>;
  final spans =
      (scopeSpans.single! as Map<String, Object?>)['spans']! as List<Object?>;
  return spans.single! as Map<String, Object?>;
}
