import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_telemetry/src/otlp_json.dart';
import 'package:penguin_telemetry/src/queue.dart';
import 'package:penguin_telemetry/src/tracer.dart';

void main() {
  test('startSpan without a parent generates fresh 32/16-hex IDs', () {
    final queue = BoundedQueue<SpanData>(maxSize: 10);
    final tracer = Tracer(clock: const SystemClock(), queue: queue);

    final span = tracer.startSpan('root');

    expect(span.traceId, hasLength(32));
    expect(span.spanId, hasLength(16));
    expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(span.traceId), isTrue);
    expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(span.spanId), isTrue);
    expect(span.parentSpanId, isNull);
  });

  test('startSpan with a parent shares traceId and records parentSpanId', () {
    final queue = BoundedQueue<SpanData>(maxSize: 10);
    final tracer = Tracer(clock: const SystemClock(), queue: queue);

    final parent = tracer.startSpan('parent');
    final child = tracer.startSpan('child', parent: parent);

    expect(child.traceId, parent.traceId);
    expect(child.parentSpanId, parent.spanId);
    expect(child.spanId == parent.spanId, isFalse);
  });

  test('two spans without a shared parent get different trace IDs', () {
    final queue = BoundedQueue<SpanData>(maxSize: 10);
    final tracer = Tracer(clock: const SystemClock(), queue: queue);

    final a = tracer.startSpan('a');
    final b = tracer.startSpan('b');

    expect(a.traceId == b.traceId, isFalse);
  });

  test('ending a span enqueues it', () {
    final queue = BoundedQueue<SpanData>(maxSize: 10);
    final tracer = Tracer(clock: const SystemClock(), queue: queue);

    tracer.startSpan('op').end();

    expect(queue.length, 1);
  });

  test('trace() ends the span and returns the body result', () async {
    final queue = BoundedQueue<SpanData>(maxSize: 10);
    final tracer = Tracer(clock: const SystemClock(), queue: queue);

    final result = await tracer.trace('work', (span) async => 42);

    expect(result, 42);
    expect(queue.length, 1);
    expect(queue.drain().single.status.code, SpanStatusCode.unset);
  });

  test(
    'trace() records the error, sets error status, ends the span, and rethrows on exception',
    () async {
      final queue = BoundedQueue<SpanData>(maxSize: 10);
      final tracer = Tracer(clock: const SystemClock(), queue: queue);

      await expectLater(
        () => tracer.trace<void>(
          'work',
          (span) async => throw StateError('boom'),
        ),
        throwsA(isA<StateError>()),
      );

      expect(queue.length, 1);
      final data = queue.drain().single;
      expect(data.status.code, SpanStatusCode.error);
      expect(data.attributes['exception.message'], contains('boom'));
    },
  );
}
