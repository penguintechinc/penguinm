import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_telemetry/src/meter.dart';
import 'package:penguin_telemetry/src/otlp_json.dart';

void main() {
  test('counter accumulates cumulatively per attribute signature', () {
    final meter = Meter(clock: const SystemClock());
    final counter = meter.counter('requests.total');

    counter.add(1, attributes: const <String, Object?>{'route': '/a'});
    counter.add(2, attributes: const <String, Object?>{'route': '/a'});
    counter.add(5, attributes: const <String, Object?>{'route': '/b'});

    final metric = meter.collect().single;
    expect(metric.kind, MetricKind.sum);
    final byRoute = {
      for (final p in metric.sumPoints) p.attributes['route']: p.value,
    };
    expect(byRoute['/a'], 3.0);
    expect(byRoute['/b'], 5.0);
  });

  test(
    'counter() called twice with the same name returns the same instrument',
    () {
      final meter = Meter(clock: const SystemClock());
      expect(identical(meter.counter('x'), meter.counter('x')), isTrue);
    },
  );

  test('counter attributes are sanitized before storage', () {
    final meter = Meter(clock: const SystemClock());
    meter
        .counter('x')
        .add(1, attributes: const <String, Object?>{'apiKey': 'abcd12345678'});

    final point = meter.collect().single.sumPoints.single;
    expect(point.attributes['apiKey'], '****5678');
  });

  test('histogram buckets observations by boundary and tracks count/sum', () {
    final meter = Meter(clock: const SystemClock());
    final histogram = meter.histogram(
      'route.duration',
      boundaries: const <double>[10, 100],
    );

    histogram.record(5);
    histogram.record(50);
    histogram.record(500);

    final metric = meter.collect().single;
    expect(metric.kind, MetricKind.histogram);
    final point = metric.histogramPoints.single;
    expect(point.count, 3);
    expect(point.sum, 555.0);
    expect(point.bucketCounts, <int>[1, 1, 1]);
    expect(point.explicitBounds, <double>[10, 100]);
  });

  test(
    'histogram() called twice with the same name ignores new boundaries',
    () {
      final meter = Meter(clock: const SystemClock());
      meter.histogram('h', boundaries: const <double>[1]);
      final second = meter.histogram('h', boundaries: const <double>[1, 2, 3]);

      expect(second.boundaries, <double>[1]);
    },
  );

  test('histogram attributes are sanitized before storage', () {
    final meter = Meter(clock: const SystemClock());
    meter
        .histogram('h')
        .record(
          1,
          attributes: const <String, Object?>{'password': 'hunter2xyz'},
        );

    final point = meter.collect().single.histogramPoints.single;
    expect(point.attributes['password'], '****2xyz');
  });

  test(
    'gauge(observe) reports the pull-style current value at collection time',
    () {
      final meter = Meter(clock: const SystemClock());
      var current = 1.0;
      meter.gauge('battery.level', () => current);
      current = 42;

      final metric = meter.collect().single;
      expect(metric.kind, MetricKind.gauge);
      expect(metric.sumPoints.single.value, 42.0);
    },
  );

  test(
    'recordGaugeValue reports push-style readings per attribute signature',
    () {
      final meter = Meter(clock: const SystemClock());
      meter.recordGaugeValue('sync.queue.depth', 3, const <String, Object?>{
        'queue': 'a',
      });
      meter.recordGaugeValue('sync.queue.depth', 7, const <String, Object?>{
        'queue': 'b',
      });
      meter.recordGaugeValue('sync.queue.depth', 9, const <String, Object?>{
        'queue': 'a',
      });

      final metric = meter.collect().single;
      final byQueue = {
        for (final p in metric.sumPoints) p.attributes['queue']: p.value,
      };
      expect(byQueue['a'], 9.0);
      expect(byQueue['b'], 7.0);
    },
  );

  test('recordGaugeValue attributes are sanitized before storage', () {
    final meter = Meter(clock: const SystemClock());
    meter.recordGaugeValue('g', 1, const <String, Object?>{
      'token': 'abcd1234wxyz',
    });

    final point = meter.collect().single.sumPoints.single;
    expect(point.attributes['token'], '****wxyz');
  });

  test('collect() returns an entry per registered instrument', () {
    final meter = Meter(clock: const SystemClock());
    meter.counter('c').add(1);
    meter.histogram('h').record(1);
    meter.gauge('g', () => 1);

    expect(meter.collect(), hasLength(3));
  });
}
