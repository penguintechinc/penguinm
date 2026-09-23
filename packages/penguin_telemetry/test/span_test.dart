import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_telemetry/src/otlp_json.dart';
import 'package:penguin_telemetry/src/span.dart';

class _FixedClock implements Clock {
  _FixedClock(this._now);
  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration duration) => _now = _now.add(duration);
}

void main() {
  final traceId = 't'.padRight(32, 't');
  final spanId = 's'.padRight(16, 's');

  test('end() enqueues a SpanData snapshot exactly once', () {
    final clock = _FixedClock(DateTime.utc(2026));
    final captured = <SpanData>[];
    final span = Span(
      name: 'op',
      kind: SpanKind.internal,
      traceId: traceId,
      spanId: spanId,
      clock: clock,
      onEnd: captured.add,
    );

    clock.advance(const Duration(milliseconds: 5));
    span.end();
    span.end();

    expect(captured, hasLength(1));
    expect(captured.single.name, 'op');
    expect(captured.single.endTime.isAfter(captured.single.startTime), isTrue);
  });

  test('setAttribute sanitizes sensitive values', () {
    final clock = _FixedClock(DateTime.utc(2026));
    final captured = <SpanData>[];
    final span = Span(
      name: 'op',
      kind: SpanKind.internal,
      traceId: traceId,
      spanId: spanId,
      clock: clock,
      onEnd: captured.add,
    );

    span.setAttribute('authToken', 'abcd1234wxyz');
    span.end();

    expect(captured.single.attributes['authToken'], '****wxyz');
  });

  test('constructor sanitizes initial attributes', () {
    final clock = _FixedClock(DateTime.utc(2026));
    final captured = <SpanData>[];
    final span = Span(
      name: 'op',
      kind: SpanKind.internal,
      traceId: traceId,
      spanId: spanId,
      clock: clock,
      attributes: const <String, Object?>{'password': 'hunter2xyz'},
      onEnd: captured.add,
    );

    span.end();

    expect(captured.single.attributes['password'], '****2xyz');
  });

  test('recordError attaches exception attributes and sets error status', () {
    final clock = _FixedClock(DateTime.utc(2026));
    final captured = <SpanData>[];
    final span = Span(
      name: 'op',
      kind: SpanKind.internal,
      traceId: traceId,
      spanId: spanId,
      clock: clock,
      onEnd: captured.add,
    );

    span.recordError(StateError('boom'), StackTrace.current);
    span.end();

    final data = captured.single;
    expect(data.attributes['exception.type'], contains('StateError'));
    expect(data.attributes['exception.message'], contains('boom'));
    expect(data.attributes.containsKey('exception.stacktrace'), isTrue);
    expect(data.status.code, SpanStatusCode.error);
  });

  test('recordError without a stack trace omits exception.stacktrace', () {
    final clock = _FixedClock(DateTime.utc(2026));
    final captured = <SpanData>[];
    final span = Span(
      name: 'op',
      kind: SpanKind.internal,
      traceId: traceId,
      spanId: spanId,
      clock: clock,
      onEnd: captured.add,
    );

    span.recordError(StateError('boom'));
    span.end();

    expect(
      captured.single.attributes.containsKey('exception.stacktrace'),
      isFalse,
    );
  });

  test('setStatus overrides the terminal status', () {
    final clock = _FixedClock(DateTime.utc(2026));
    final captured = <SpanData>[];
    final span = Span(
      name: 'op',
      kind: SpanKind.internal,
      traceId: traceId,
      spanId: spanId,
      clock: clock,
      onEnd: captured.add,
    );

    span.setStatus(SpanStatus.ok);
    span.end();

    expect(captured.single.status.code, SpanStatusCode.ok);
  });

  test('traceparent is a valid W3C header value', () {
    final clock = _FixedClock(DateTime.utc(2026));
    final span = Span(
      name: 'op',
      kind: SpanKind.internal,
      traceId: traceId,
      spanId: spanId,
      clock: clock,
      onEnd: (_) {},
    );

    expect(span.traceparent, '00-$traceId-$spanId-01');
  });
}
