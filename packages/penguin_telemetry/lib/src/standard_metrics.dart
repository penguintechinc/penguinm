/// Well-known metric instrument names shared across every penguinm app, so
/// dashboards and alerts can rely on a stable name regardless of which app
/// emitted the data.
class StandardMetrics {
  StandardMetrics._();

  /// Histogram: time from process start to the first interactive frame.
  static const String appStartupDuration = 'app.startup.duration';

  /// Histogram: time to load a route's data/screen.
  static const String routeLoadDuration = 'app.route.load.duration';

  /// Histogram: `PenguinApiClient` request duration.
  static const String httpClientRequestDuration =
      'http.client.request.duration';

  /// Histogram: `PenguinApiClient` request body size.
  static const String httpClientRequestSize = 'http.client.request.body.size';

  /// Gauge: number of items waiting in the offline sync queue.
  static const String syncQueueDepth = 'sync.queue.depth';

  /// Counter: records dropped by `Telemetry` — queue overflow or a failed
  /// export.
  static const String telemetryDropped = 'telemetry.dropped';
}
