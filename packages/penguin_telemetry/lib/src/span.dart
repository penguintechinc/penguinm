import 'package:penguin_core/penguin_core.dart';

import 'otlp_json.dart';

/// A single in-flight span. Implements penguin_core's [SpanHandle] so it
/// can be used wherever the cross-cutting trace interface is expected,
/// while exposing the extra members (`traceId`, `spanId`, [setStatus]) a
/// `Tracer` needs to build parent/child relationships and terminal status.
class Span implements SpanHandle {
  /// Creates a span. Used internally by `Tracer.startSpan` — most callers
  /// obtain spans via a `Tracer` or `TraceSink` rather than constructing
  /// one directly. [onEnd] is invoked exactly once, with the completed
  /// snapshot, the first time [end] is called.
  Span({
    required this.name,
    required this.kind,
    required this.traceId,
    required this.spanId,
    required this._clock,
    required this._onEnd,
    this.parentSpanId,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) : _startTime = _clock.now(),
       _attributes = Map<String, Object?>.of(LogSanitizer.sanitize(attributes));

  /// The operation name this span records.
  final String name;

  /// The span kind.
  final SpanKind kind;

  /// 32-hex-character trace ID shared by every span in this trace.
  final String traceId;

  /// 16-hex-character span ID unique within [traceId].
  final String spanId;

  /// The parent span's ID, if any.
  final String? parentSpanId;

  final Clock _clock;
  final DateTime _startTime;
  final void Function(SpanData data) _onEnd;
  final Map<String, Object?> _attributes;
  SpanStatus _status = SpanStatus.unset;
  bool _ended = false;

  @override
  void setAttribute(String key, Object? value) {
    _attributes.addAll(LogSanitizer.sanitize(<String, Object?>{key: value}));
  }

  @override
  void recordError(Object error, [StackTrace? stack]) {
    _attributes['exception.type'] = error.runtimeType.toString();
    _attributes['exception.message'] = error.toString();
    if (stack != null) _attributes['exception.stacktrace'] = stack.toString();
    _status = SpanStatus.error;
  }

  /// Sets this span's terminal status; the last call before [end] wins.
  void setStatus(SpanStatus status) {
    _status = status;
  }

  @override
  void end() {
    if (_ended) return;
    _ended = true;
    _onEnd(
      SpanData(
        traceId: traceId,
        spanId: spanId,
        parentSpanId: parentSpanId,
        name: name,
        kind: kind,
        startTime: _startTime,
        endTime: _clock.now(),
        attributes: Map<String, Object?>.unmodifiable(_attributes),
        status: _status,
      ),
    );
  }

  @override
  String get traceparent => '00-$traceId-$spanId-01';
}
