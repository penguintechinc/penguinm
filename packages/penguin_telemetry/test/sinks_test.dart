import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_telemetry/src/meter.dart';
import 'package:penguin_telemetry/src/otlp_json.dart';
import 'package:penguin_telemetry/src/queue.dart';
import 'package:penguin_telemetry/src/sinks.dart';
import 'package:penguin_telemetry/src/span.dart';
import 'package:penguin_telemetry/src/tracer.dart';

void main() {
  test('TelemetryMetricsSink.counter delegates to the meter', () {
    final meter = Meter(clock: const SystemClock());
    final sink = TelemetryMetricsSink(meter);

    sink.counter('c', 1);
    sink.counter('c', 2);

    expect(meter.collect().single.sumPoints.single.value, 3.0);
  });

  test(
    'TelemetryMetricsSink.histogram records into the underlying histogram',
    () {
      final meter = Meter(clock: const SystemClock());
      final sink = TelemetryMetricsSink(meter);

      sink.histogram('h', 5);
      sink.histogram('h', 15);

      final point = meter.collect().single.histogramPoints.single;
      expect(point.count, 2);
      expect(point.sum, 20.0);
    },
  );

  test('TelemetryMetricsSink.gauge records the latest pushed value', () {
    final meter = Meter(clock: const SystemClock());
    final sink = TelemetryMetricsSink(meter);

    sink.gauge('g', 3);
    sink.gauge('g', 9);

    expect(meter.collect().single.sumPoints.single.value, 9.0);
  });

  test(
    'MetricsSink implementations are usable via the penguin_core interface',
    () {
      final meter = Meter(clock: const SystemClock());
      final MetricsSink sink = TelemetryMetricsSink(meter);

      sink.counter('c', 1, attributes: const <String, Object?>{'k': 'v'});

      expect(meter.collect(), hasLength(1));
    },
  );

  test('TelemetryTraceSink.startSpan delegates to the tracer', () {
    final queue = BoundedQueue<SpanData>(maxSize: 10);
    final tracer = Tracer(clock: const SystemClock(), queue: queue);
    final sink = TelemetryTraceSink(tracer);

    final handle = sink.startSpan('op');
    handle.end();

    expect(queue.length, 1);
  });

  test(
    'TelemetryTraceSink.startSpan links a Span parent but ignores a non-Span parent',
    () {
      final queue = BoundedQueue<SpanData>(maxSize: 10);
      final tracer = Tracer(clock: const SystemClock(), queue: queue);
      final sink = TelemetryTraceSink(tracer);

      final parent = sink.startSpan('parent') as Span;
      final child = sink.startSpan('child', parent: parent) as Span;
      expect(child.traceId, parent.traceId);

      final unrelated =
          sink.startSpan('other', parent: const NoopSpanHandle()) as Span;
      expect(unrelated.traceId == parent.traceId, isFalse);
    },
  );
}
