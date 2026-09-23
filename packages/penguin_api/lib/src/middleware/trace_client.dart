import 'package:http/http.dart' as http;
import 'package:penguin_core/penguin_core.dart';

/// Middleware that integrates with [TraceSink] and [MetricsSink]: opens a
/// span `HTTP <METHOD>`, injects `traceparent` header, records request
/// duration as `http.client.request.duration` histogram with the response
/// status code as an attribute.
class TraceClient extends http.BaseClient {
  /// Creates a tracing middleware wrapping [inner]. `traces`/`metrics` are
  /// initializing formals bound to private fields (`_traces`/`_metrics`) —
  /// Dart exposes the underscore-stripped name as the external label, so
  /// the public constructor call site (`TraceClient(inner: ..., traces:
  /// ..., metrics: ...)`) is unchanged.
  TraceClient({
    required this._inner,
    this._traces = const NoopTraceSink(),
    this._metrics = const NoopMetricsSink(),
  });

  final http.Client _inner;
  final TraceSink _traces;
  final MetricsSink _metrics;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final spanName = 'HTTP ${request.method}';
    final span = _traces.startSpan(
      spanName,
      attributes: {
        'http.request.method': request.method,
        'url.path': request.url.path,
      },
    );

    // Inject traceparent into the request
    request.headers['traceparent'] = span.traceparent;

    final stopwatch = Stopwatch()..start();
    http.StreamedResponse? response;

    try {
      response = await _inner.send(request);
      return response;
    } catch (e) {
      span.recordError(e);
      rethrow;
    } finally {
      stopwatch.stop();

      // Record the duration and status code. `response` stays null when
      // `_inner.send` threw above — never read it unconditionally here, or
      // the original error gets masked by a LateInitializationError.
      final currentResponse = response;
      if (currentResponse != null) {
        _metrics.histogram(
          'http.client.request.duration',
          stopwatch.elapsedMilliseconds,
          attributes: {'http.response.status_code': currentResponse.statusCode},
        );
        span.setAttribute(
          'http.response.status_code',
          currentResponse.statusCode,
        );
      } else {
        _metrics.histogram(
          'http.client.request.duration',
          stopwatch.elapsedMilliseconds,
        );
      }

      span.end();
    }
  }
}
