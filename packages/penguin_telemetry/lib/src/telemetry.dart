import 'dart:async';

import 'package:penguin_core/penguin_core.dart';

import 'config.dart';
import 'exporter.dart';
import 'logger.dart';
import 'meter.dart';
import 'noop_exporter.dart';
import 'otlp_http_json_exporter.dart';
import 'otlp_json.dart';
import 'queue.dart';
import 'standard_metrics.dart';
import 'tracer.dart';

/// The running telemetry pipeline for a penguinm app: owns the logger,
/// meter and tracer, buffers everything they produce onto bounded queues,
/// and periodically (plus on explicit [flush]) exports batches via a
/// [TelemetryExporter]. Every instrument call ([PenguinLogger.log],
/// `Counter.add`, `Histogram.record`, `Span.end`) is synchronous and only
/// enqueues, so the app never awaits an export on a request path.
class Telemetry {
  Telemetry._({
    required this.logger,
    required this.meter,
    required this.tracer,
    required this._exporter,
    required this._clock,
    required this._logQueue,
    required this._spanQueue,
  });

  /// Starts telemetry from [config]: resolves an `OtlpHttpJsonExporter`
  /// when `config.endpoint` is set (or `NoopExporter` otherwise), unless
  /// [exporter] overrides that choice — tests always pass a fake here.
  /// `config.protocol` values other than [OtlpProtocol.httpJson] fall back
  /// to HTTP/JSON with a WARN log, since no other wire protocol is
  /// implemented in this version. DEBUG-level logs are enabled when
  /// `config.resourceAttributes['deployment.environment']` is `prealpha`
  /// or `alpha`; otherwise the minimum level is INFO.
  static Future<Telemetry> start(
    TelemetryConfig config, {
    TelemetryExporter? exporter,
    Clock? clock,
  }) async {
    final resolvedClock = clock ?? const SystemClock();
    final resolvedExporter = exporter ?? _defaultExporter(config);

    final logQueue = BoundedQueue<LogRecordData>(maxSize: config.maxQueue);
    final spanQueue = BoundedQueue<SpanData>(maxSize: config.maxQueue);
    final meter = Meter(clock: resolvedClock);
    final tracer = Tracer(clock: resolvedClock, queue: spanQueue);
    final logger = TelemetryLogger(
      clock: resolvedClock,
      queue: logQueue,
      minLevel: _minLevelFor(config),
      consoleMirror: config.consoleMirror,
    );

    final telemetry = Telemetry._(
      logger: logger,
      meter: meter,
      tracer: tracer,
      exporter: resolvedExporter,
      clock: resolvedClock,
      logQueue: logQueue,
      spanQueue: spanQueue,
    );

    if (config.protocol != OtlpProtocol.httpJson) {
      logger.warn(
        'unsupported OTLP protocol, falling back to http/json',
        attributes: <String, Object?>{'protocol': config.protocol.name},
      );
    }

    telemetry._timer = Timer.periodic(config.exportInterval, (_) {
      unawaited(telemetry.flush());
    });

    return telemetry;
  }

  static TelemetryExporter _defaultExporter(TelemetryConfig config) {
    final endpoint = config.endpoint;
    if (endpoint == null) return const NoopExporter();
    return OtlpHttpJsonExporter(
      endpoint: endpoint,
      serviceName: config.serviceName,
      serviceVersion: config.serviceVersion,
      resourceAttributes: config.resourceAttributes,
      headers: config.headers,
    );
  }

  static LogLevel _minLevelFor(TelemetryConfig config) {
    final environment = config.resourceAttributes['deployment.environment'];
    if (environment == 'prealpha' || environment == 'alpha') {
      return LogLevel.debug;
    }
    return LogLevel.info;
  }

  /// Structured logger backed by this telemetry instance.
  final PenguinLogger logger;

  /// Metric instrument factory backed by this telemetry instance.
  final Meter meter;

  /// Span factory backed by this telemetry instance.
  final Tracer tracer;

  final TelemetryExporter _exporter;
  final Clock _clock;
  final BoundedQueue<LogRecordData> _logQueue;
  final BoundedQueue<SpanData> _spanQueue;
  Timer? _timer;
  int _exportFailureCount = 0;
  DateTime? _lastExportWarnAt;
  int _lastReportedDropped = 0;

  /// Total records ever dropped: evicted from a full queue, plus records
  /// lost to failed exports. Also periodically reported as the
  /// `telemetry.dropped` counter on [meter].
  int get droppedCount =>
      _logQueue.droppedCount + _spanQueue.droppedCount + _exportFailureCount;

  /// Drains every buffered log/metric/span batch and sends it via the
  /// configured exporter; safe to call concurrently with instrument use
  /// (which only ever enqueues).
  Future<void> flush() async {
    final logs = _logQueue.drain();
    final spans = _spanQueue.drain();
    final metrics = meter.collect();

    if (logs.isNotEmpty) {
      _afterExport('logs', logs.length, await _exporter.exportLogs(logs));
    }
    if (metrics.isNotEmpty) {
      _afterExport(
        'metrics',
        metrics.length,
        await _exporter.exportMetrics(metrics),
      );
    }
    if (spans.isNotEmpty) {
      _afterExport('spans', spans.length, await _exporter.exportSpans(spans));
    }

    final dropped = droppedCount;
    if (dropped > _lastReportedDropped) {
      meter
          .counter(StandardMetrics.telemetryDropped)
          .add(dropped - _lastReportedDropped);
      _lastReportedDropped = dropped;
    }
  }

  void _afterExport(String signal, int itemCount, ExportResult result) {
    if (result.ok) return;
    _exportFailureCount += itemCount - result.accepted;
    final now = _clock.now();
    final lastWarn = _lastExportWarnAt;
    if (lastWarn == null ||
        now.difference(lastWarn) >= const Duration(minutes: 1)) {
      _lastExportWarnAt = now;
      logger.warn(
        'telemetry export failed',
        attributes: <String, Object?>{'signal': signal, 'error': result.error},
      );
    }
  }

  /// Cancels periodic export and performs one final [flush].
  Future<void> shutdown() async {
    _timer?.cancel();
    _timer = null;
    await flush();
  }
}
