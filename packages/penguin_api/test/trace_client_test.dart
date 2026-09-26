import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_api/src/middleware/trace_client.dart';
import 'support/scripted_client.dart';

void main() {
  group('TraceClient', () {
    test('injects traceparent header', () async {
      final fakeTraceSink = _FakeTraceSink();
      final builder = ScriptedClientBuilder();
      builder.respond(method: 'GET', pathPattern: '/api', statusCode: 200);

      final inner = builder.build();
      final client = TraceClient(inner: inner, traces: fakeTraceSink);

      await client.get(Uri.parse('http://example.com/api'));

      final request = inner.seenRequests.first;
      expect(request.headers.containsKey('traceparent'), isTrue);
    });

    test('records http.client.request.duration histogram', () async {
      final fakeTraceSink = _FakeTraceSink();
      final fakeMetricsSink = _FakeMetricsSink();
      final builder = ScriptedClientBuilder();
      builder.respond(method: 'GET', pathPattern: '/api', statusCode: 200);

      final inner = builder.build();
      final client = TraceClient(
        inner: inner,
        traces: fakeTraceSink,
        metrics: fakeMetricsSink,
      );

      await client.get(Uri.parse('http://example.com/api'));

      expect(
        fakeMetricsSink.histograms,
        contains(
          predicate<_HistogramCall>(
            (call) =>
                call.name == 'http.client.request.duration' &&
                call.attributes.containsKey('http.response.status_code') &&
                call.attributes['http.response.status_code'] == 200,
          ),
        ),
      );
    });

    test('creates span with HTTP method', () async {
      final fakeTraceSink = _FakeTraceSink();
      final builder = ScriptedClientBuilder();
      builder.respond(method: 'POST', pathPattern: '/api', statusCode: 200);

      final inner = builder.build();
      final client = TraceClient(inner: inner, traces: fakeTraceSink);

      await client.post(Uri.parse('http://example.com/api'), body: 'data');

      expect(
        fakeTraceSink.spans,
        contains(predicate<_SpanCall>((call) => call.name.contains('POST'))),
      );
    });

    test('records status code in attributes', () async {
      final fakeTraceSink = _FakeTraceSink();
      final builder = ScriptedClientBuilder();
      builder.respond(method: 'GET', pathPattern: '/api', statusCode: 404);

      final inner = builder.build();
      final client = TraceClient(inner: inner, traces: fakeTraceSink);

      await client.get(Uri.parse('http://example.com/api'));

      expect(
        fakeTraceSink.spans,
        contains(
          predicate<_SpanCall>(
            (call) => call.attributes['http.response.status_code'] == 404,
          ),
        ),
      );
    });
  });
}

class _FakeMetricsSink implements MetricsSink {
  final histograms = <_HistogramCall>[];
  final counters = <_CounterCall>[];
  final gauges = <_GaugeCall>[];

  @override
  void counter(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  }) {
    counters.add(_CounterCall(name, value, attributes));
  }

  @override
  void gauge(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  }) {
    gauges.add(_GaugeCall(name, value, attributes));
  }

  @override
  void histogram(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  }) {
    histograms.add(_HistogramCall(name, value, attributes));
  }
}

class _HistogramCall {
  final String name;
  final num value;
  final Map<String, Object?> attributes;

  _HistogramCall(this.name, this.value, this.attributes);
}

class _CounterCall {
  final String name;
  final num value;
  final Map<String, Object?> attributes;

  _CounterCall(this.name, this.value, this.attributes);
}

class _GaugeCall {
  final String name;
  final num value;
  final Map<String, Object?> attributes;

  _GaugeCall(this.name, this.value, this.attributes);
}

class _FakeSpanHandle implements SpanHandle {
  _FakeSpanHandle(this.traceparent, this._call);

  @override
  final String traceparent;

  /// The recorded call this handle backs — [setAttribute] writes through
  /// to it so a real [SpanHandle]'s post-creation attribute updates (e.g.
  /// the response status code, set after the span is opened) are visible
  /// to assertions on [_FakeTraceSink.spans].
  final _SpanCall _call;

  @override
  void setAttribute(String key, Object? value) {
    _call.attributes[key] = value;
  }

  @override
  void recordError(Object error, [StackTrace? stack]) {}

  @override
  void end() {}
}

class _FakeTraceSink implements TraceSink {
  final spans = <_SpanCall>[];

  @override
  SpanHandle startSpan(
    String name, {
    SpanHandle? parent,
    Map<String, Object?> attributes = const {},
  }) {
    final call = _SpanCall(name, parent, Map<String, Object?>.of(attributes));
    spans.add(call);
    return _FakeSpanHandle('00-trace-span-01', call);
  }
}

class _SpanCall {
  final String name;
  final SpanHandle? parent;
  final Map<String, Object?> attributes;

  _SpanCall(this.name, this.parent, this.attributes);
}
