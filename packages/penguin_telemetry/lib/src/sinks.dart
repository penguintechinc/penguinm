import 'package:penguin_core/penguin_core.dart';

import 'meter.dart';
import 'span.dart';
import 'tracer.dart';

/// Adapts a [Meter] to penguin_core's cross-cutting [MetricsSink] interface
/// so packages like `penguin_api`/`penguin_offline` can emit metrics
/// without depending on `penguin_telemetry` directly.
class TelemetryMetricsSink implements MetricsSink {
  /// Wraps [meter].
  TelemetryMetricsSink(this._meter);

  final Meter _meter;

  @override
  void counter(
    String name,
    num value, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    _meter.counter(name).add(value, attributes: attributes);
  }

  @override
  void histogram(
    String name,
    num value, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    _meter.histogram(name).record(value, attributes: attributes);
  }

  @override
  void gauge(
    String name,
    num value, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    _meter.recordGaugeValue(name, value.toDouble(), attributes);
  }
}

/// Adapts a [Tracer] to penguin_core's cross-cutting [TraceSink] interface.
class TelemetryTraceSink implements TraceSink {
  /// Wraps [tracer].
  TelemetryTraceSink(this._tracer);

  final Tracer _tracer;

  @override
  SpanHandle startSpan(
    String name, {
    SpanHandle? parent,
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    return _tracer.startSpan(
      name,
      parent: parent is Span ? parent : null,
      attributes: attributes,
    );
  }
}
