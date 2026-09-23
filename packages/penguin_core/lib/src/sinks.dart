/// Cross-cutting metrics emission interface implemented by
/// `penguin_telemetry`; consumed by packages (api, offline) that must not
/// depend on telemetry directly.
abstract interface class MetricsSink {
  /// Increments a monotonic counter by [value].
  void counter(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  });

  /// Records a single observation of [value] into a histogram.
  void histogram(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  });

  /// Records the current reading of a gauge.
  void gauge(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  });
}

/// Cross-cutting distributed tracing interface implemented by
/// `penguin_telemetry`.
abstract interface class TraceSink {
  /// Starts a new span named [name], optionally nested under [parent].
  SpanHandle startSpan(
    String name, {
    SpanHandle? parent,
    Map<String, Object?> attributes = const {},
  });
}

/// A single in-flight span handle returned by [TraceSink.startSpan].
abstract interface class SpanHandle {
  /// Attaches or overwrites an attribute on this span.
  void setAttribute(String key, Object? value);

  /// Records [error] (and optional [stack]) as an error event on this span.
  void recordError(Object error, [StackTrace? stack]);

  /// Ends the span, making it eligible for export.
  void end();

  /// The W3C `traceparent` header value for propagating this span's
  /// context across service boundaries.
  String get traceparent;
}

/// No-op [MetricsSink] used before telemetry starts or when telemetry is
/// disabled — every call is a safe, silent discard.
class NoopMetricsSink implements MetricsSink {
  /// Creates a no-op metrics sink.
  const NoopMetricsSink();

  @override
  void counter(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  }) {}

  @override
  void histogram(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  }) {}

  @override
  void gauge(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  }) {}
}

/// No-op [TraceSink] used before telemetry starts or when telemetry is
/// disabled — always returns a [NoopSpanHandle].
class NoopTraceSink implements TraceSink {
  /// Creates a no-op trace sink.
  const NoopTraceSink();

  @override
  SpanHandle startSpan(
    String name, {
    SpanHandle? parent,
    Map<String, Object?> attributes = const {},
  }) => const NoopSpanHandle();
}

/// No-op [SpanHandle] returned by [NoopTraceSink] — every call is a safe,
/// silent discard and [traceparent] is always empty.
class NoopSpanHandle implements SpanHandle {
  /// Creates a no-op span handle.
  const NoopSpanHandle();

  @override
  void setAttribute(String key, Object? value) {}

  @override
  void recordError(Object error, [StackTrace? stack]) {}

  @override
  void end() {}

  @override
  String get traceparent => '';
}
