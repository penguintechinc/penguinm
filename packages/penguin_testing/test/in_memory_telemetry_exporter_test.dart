import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_telemetry/penguin_telemetry.dart';
import 'package:penguin_testing/penguin_testing.dart';

void main() {
  group('InMemoryTelemetryExporter', () {
    test('exportLogs records every record and reports acceptance', () async {
      final exporter = InMemoryTelemetryExporter();
      final record = LogRecordData(
        timestamp: DateTime.utc(2026),
        level: LogLevel.info,
        message: 'hello',
      );

      final result = await exporter.exportLogs([record]);

      expect(exporter.logs, [record]);
      expect(result.ok, isTrue);
      expect(result.accepted, 1);
    });

    test('exportMetrics records every metric', () async {
      final exporter = InMemoryTelemetryExporter();
      final metric = MetricData.sum(name: 'a.counter', dataPoints: const []);

      await exporter.exportMetrics([metric]);

      expect(exporter.metrics, [metric]);
    });

    test('exportSpans records every span', () async {
      final exporter = InMemoryTelemetryExporter();
      final span = SpanData(
        traceId: '0' * 32,
        spanId: '0' * 16,
        name: 'op',
        kind: SpanKind.internal,
        startTime: DateTime.utc(2026),
        endTime: DateTime.utc(2026, 1, 1, 0, 0, 1),
      );

      await exporter.exportSpans([span]);

      expect(exporter.spans, [span]);
    });

    test('expectHistogram returns the matching histogram metric', () async {
      final exporter = InMemoryTelemetryExporter();
      final histogram = MetricData.histogram(
        name: 'http.client.request.duration',
        dataPoints: const [],
      );
      final counter = MetricData.sum(
        name: 'other.counter',
        dataPoints: const [],
      );
      await exporter.exportMetrics([counter, histogram]);

      expect(
        exporter.expectHistogram('http.client.request.duration'),
        same(histogram),
      );
    });

    test('expectHistogram fails with a useful message when absent', () async {
      final exporter = InMemoryTelemetryExporter();
      await exporter.exportMetrics([
        MetricData.sum(name: 'other.counter', dataPoints: const []),
      ]);

      expect(
        () => exporter.expectHistogram('missing.histogram'),
        throwsA(
          isA<TestFailure>().having(
            (f) => f.message,
            'message',
            allOf(contains('missing.histogram'), contains('other.counter')),
          ),
        ),
      );
    });

    test('expectHistogram fails when nothing was ever exported', () {
      final exporter = InMemoryTelemetryExporter();
      expect(
        () => exporter.expectHistogram('missing.histogram'),
        throwsA(isA<TestFailure>()),
      );
    });

    test('reset clears every recorded signal', () async {
      final exporter = InMemoryTelemetryExporter();
      await exporter.exportLogs([
        LogRecordData(
          timestamp: DateTime.utc(2026),
          level: LogLevel.info,
          message: 'x',
        ),
      ]);
      await exporter.exportMetrics([
        MetricData.sum(name: 'c', dataPoints: const []),
      ]);
      await exporter.exportSpans([
        SpanData(
          traceId: '0' * 32,
          spanId: '0' * 16,
          name: 'op',
          kind: SpanKind.internal,
          startTime: DateTime.utc(2026),
          endTime: DateTime.utc(2026),
        ),
      ]);

      exporter.reset();

      expect(exporter.logs, isEmpty);
      expect(exporter.metrics, isEmpty);
      expect(exporter.spans, isEmpty);
    });
  });
}
