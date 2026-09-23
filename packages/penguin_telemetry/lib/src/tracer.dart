import 'dart:math';

import 'package:penguin_core/penguin_core.dart';

import 'ids.dart';
import 'otlp_json.dart';
import 'queue.dart';
import 'span.dart';

/// Creates and completes spans, assigning W3C-compatible trace/span IDs via
/// [Random.secure] and buffering completed spans onto a bounded queue for
/// export.
class Tracer {
  /// Creates a tracer that enqueues completed spans onto [queue], stamping
  /// timestamps from [clock] and generating IDs from [random] (defaults to
  /// [Random.secure] outside tests).
  Tracer({required this._clock, required this._queue, Random? random})
    : _random = random ?? Random.secure();

  final Clock _clock;
  final BoundedQueue<SpanData> _queue;
  final Random _random;

  /// Starts a new span named [name]. When [parent] is given, the new span
  /// shares its `traceId` and records `parentSpanId`; otherwise a fresh
  /// trace ID is generated.
  Span startSpan(
    String name, {
    SpanKind kind = SpanKind.internal,
    Span? parent,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    return Span(
      name: name,
      kind: kind,
      traceId: parent?.traceId ?? generateTraceId(_random),
      spanId: generateSpanId(_random),
      parentSpanId: parent?.spanId,
      clock: _clock,
      attributes: attributes,
      onEnd: _queue.add,
    );
  }

  /// Runs [body] inside a new span, ending it once [body] completes. Any
  /// error thrown by [body] is recorded on the span (which also marks it
  /// [SpanStatusCode.error]) before the span is ended and the error is
  /// rethrown.
  Future<T> trace<T>(
    String name,
    Future<T> Function(Span span) body, {
    SpanKind kind = SpanKind.internal,
  }) async {
    final span = startSpan(name, kind: kind);
    try {
      final result = await body(span);
      span.end();
      return result;
    } on Object catch (error, stackTrace) {
      span.recordError(error, stackTrace);
      span.end();
      rethrow;
    }
  }
}
