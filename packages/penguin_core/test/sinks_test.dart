import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';

void main() {
  test('Noop sinks are no-ops', () {
    const metrics = NoopMetricsSink();
    metrics.counter('c', 1);
    metrics.histogram('h', 1.5, attributes: const {'k': 'v'});
    metrics.gauge('g', 2);

    const traceSink = NoopTraceSink();
    final span = traceSink.startSpan('span', attributes: const {'a': 1});
    expect(span, isA<NoopSpanHandle>());

    span.setAttribute('k', 'v');
    span.recordError(Exception('boom'), StackTrace.current);
    expect(span.traceparent, '');
    span.end();
  });

  test('metricsSinkProvider and traceSinkProvider default to no-ops', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(metricsSinkProvider), isA<NoopMetricsSink>());
    expect(container.read(traceSinkProvider), isA<NoopTraceSink>());
  });
}
