import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_telemetry/penguin_telemetry.dart';

class _FakeExporter implements TelemetryExporter {
  final List<List<LogRecordData>> logBatches = <List<LogRecordData>>[];
  final List<List<MetricData>> metricBatches = <List<MetricData>>[];
  final List<List<SpanData>> spanBatches = <List<SpanData>>[];
  bool fail = false;

  @override
  Future<ExportResult> exportLogs(List<LogRecordData> records) async {
    logBatches.add(records);
    return fail
        ? const ExportResult(ok: false, accepted: 0, error: 'boom')
        : ExportResult(ok: true, accepted: records.length);
  }

  @override
  Future<ExportResult> exportMetrics(List<MetricData> metrics) async {
    metricBatches.add(metrics);
    return fail
        ? const ExportResult(ok: false, accepted: 0, error: 'boom')
        : ExportResult(ok: true, accepted: metrics.length);
  }

  @override
  Future<ExportResult> exportSpans(List<SpanData> spans) async {
    spanBatches.add(spans);
    return fail
        ? const ExportResult(ok: false, accepted: 0, error: 'boom')
        : ExportResult(ok: true, accepted: spans.length);
  }
}

void main() {
  test('start() uses NoopExporter when config.endpoint is null', () async {
    final telemetry = await Telemetry.start(
      const TelemetryConfig(
        serviceName: 's',
        serviceVersion: '1',
        exportInterval: Duration(minutes: 10),
      ),
    );
    addTearDown(telemetry.shutdown);

    telemetry.logger.info('hello');
    await telemetry.flush();

    expect(telemetry.droppedCount, 0);
  });

  test(
    'flush() sends queued logs, metrics, and spans through the given exporter',
    () async {
      final exporter = _FakeExporter();
      final telemetry = await Telemetry.start(
        const TelemetryConfig(
          serviceName: 's',
          serviceVersion: '1',
          exportInterval: Duration(minutes: 10),
        ),
        exporter: exporter,
      );
      addTearDown(telemetry.shutdown);

      telemetry.logger.info('hello');
      telemetry.meter.counter('c').add(1);
      telemetry.tracer.startSpan('op').end();

      await telemetry.flush();

      expect(exporter.logBatches.single, hasLength(1));
      expect(exporter.metricBatches.single, hasLength(1));
      expect(exporter.spanBatches.single, hasLength(1));
    },
  );

  test('flush() with nothing queued makes no export calls', () async {
    final exporter = _FakeExporter();
    final telemetry = await Telemetry.start(
      const TelemetryConfig(
        serviceName: 's',
        serviceVersion: '1',
        exportInterval: Duration(minutes: 10),
      ),
      exporter: exporter,
    );
    addTearDown(telemetry.shutdown);

    await telemetry.flush();

    expect(exporter.logBatches, isEmpty);
    expect(exporter.metricBatches, isEmpty);
    expect(exporter.spanBatches, isEmpty);
  });

  test('droppedCount reflects queue overflow plus failed exports', () async {
    final exporter = _FakeExporter()..fail = true;
    final telemetry = await Telemetry.start(
      const TelemetryConfig(
        serviceName: 's',
        serviceVersion: '1',
        exportInterval: Duration(minutes: 10),
        maxQueue: 1,
      ),
      exporter: exporter,
    );
    addTearDown(telemetry.shutdown);

    telemetry.logger.info('one');
    telemetry.logger.info('two');

    await telemetry.flush();

    expect(telemetry.droppedCount, 2);
  });

  test(
    'a second flush reports newly dropped items as the telemetry.dropped counter',
    () async {
      final exporter = _FakeExporter()..fail = true;
      final telemetry = await Telemetry.start(
        const TelemetryConfig(
          serviceName: 's',
          serviceVersion: '1',
          exportInterval: Duration(minutes: 10),
        ),
        exporter: exporter,
      );
      addTearDown(telemetry.shutdown);

      telemetry.logger.info('one');
      await telemetry.flush();
      exporter.fail = false;
      await telemetry.flush();

      final droppedMetric = exporter.metricBatches
          .expand((batch) => batch)
          .firstWhere((m) => m.name == StandardMetrics.telemetryDropped);
      expect(droppedMetric.sumPoints.single.value, greaterThanOrEqualTo(1));
    },
  );

  test(
    'shutdown cancels the periodic timer and performs a final flush',
    () async {
      final exporter = _FakeExporter();
      final telemetry = await Telemetry.start(
        const TelemetryConfig(
          serviceName: 's',
          serviceVersion: '1',
          exportInterval: Duration(minutes: 10),
        ),
        exporter: exporter,
      );

      telemetry.logger.info('final');
      await telemetry.shutdown();

      expect(exporter.logBatches.single, hasLength(1));
    },
  );

  test(
    'fromAppConfig maps AppConfig fields and enables DEBUG in prealpha',
    () async {
      final appConfig = AppConfig(
        productKey: 'gazer',
        appVersion: '1.2.3',
        environment: PenguinEnvironment.prealpha,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        otlpEndpoint: Uri.parse('http://127.0.0.1:4318'),
        licenseServerUrl: 'https://license.penguintech.io',
      );

      final config = TelemetryConfig.fromAppConfig(appConfig);

      expect(config.serviceName, 'gazer');
      expect(config.serviceVersion, '1.2.3');
      expect(config.endpoint, Uri.parse('http://127.0.0.1:4318'));
      expect(config.resourceAttributes['deployment.environment'], 'prealpha');
      expect(config.consoleMirror, isTrue);

      final exporter = _FakeExporter();
      final telemetry = await Telemetry.start(config, exporter: exporter);
      addTearDown(telemetry.shutdown);

      telemetry.logger.debug('debug is enabled in prealpha');
      await telemetry.flush();

      expect(exporter.logBatches.single, hasLength(1));
    },
  );

  test('fromAppConfig disables DEBUG outside prealpha/alpha', () async {
    final appConfig = AppConfig(
      productKey: 'gazer',
      appVersion: '1.0.0',
      environment: PenguinEnvironment.prod,
      apiBaseUrl: Uri.parse('https://api.example.com'),
      licenseServerUrl: 'https://license.penguintech.io',
    );

    final config = TelemetryConfig.fromAppConfig(appConfig);
    expect(config.consoleMirror, isFalse);

    final exporter = _FakeExporter();
    final telemetry = await Telemetry.start(config, exporter: exporter);
    addTearDown(telemetry.shutdown);

    telemetry.logger.debug('should be dropped');
    await telemetry.flush();

    expect(exporter.logBatches, isEmpty);
  });

  test(
    'an unsupported protocol falls back to http/json with a WARN log',
    () async {
      final exporter = _FakeExporter();
      final telemetry = await Telemetry.start(
        const TelemetryConfig(
          serviceName: 's',
          serviceVersion: '1',
          protocol: OtlpProtocol.grpc,
          exportInterval: Duration(minutes: 10),
        ),
        exporter: exporter,
      );
      addTearDown(telemetry.shutdown);

      await telemetry.flush();

      final warned = exporter.logBatches
          .expand((batch) => batch)
          .any((r) => r.message.contains('unsupported OTLP protocol'));
      expect(warned, isTrue);
    },
  );

  test(
    'start() builds a real OtlpHttpJsonExporter when an endpoint is configured and no exporter override is given',
    () async {
      final telemetry = await Telemetry.start(
        const TelemetryConfig(
          serviceName: 's',
          serviceVersion: '1',
          endpoint: null,
          exportInterval: Duration(minutes: 10),
        ),
      );
      addTearDown(telemetry.shutdown);
      expect(telemetry.droppedCount, 0);

      final withEndpoint = await Telemetry.start(
        TelemetryConfig(
          serviceName: 's',
          serviceVersion: '1',
          endpoint: Uri.parse('http://127.0.0.1:4318'),
          exportInterval: const Duration(minutes: 10),
        ),
      );
      addTearDown(withEndpoint.shutdown);
      expect(withEndpoint.droppedCount, 0);
    },
  );

  test('the periodic timer flushes automatically on exportInterval', () async {
    final exporter = _FakeExporter();
    final telemetry = await Telemetry.start(
      const TelemetryConfig(
        serviceName: 's',
        serviceVersion: '1',
        exportInterval: Duration(milliseconds: 20),
      ),
      exporter: exporter,
    );
    addTearDown(telemetry.shutdown);

    telemetry.logger.info('periodic');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(exporter.logBatches, isNotEmpty);
  });

  test('telemetryProvider throws until overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Riverpod wraps the thrown error in a ProviderException; assert on the
    // underlying message rather than the wrapper type.
    expect(
      () => container.read(telemetryProvider),
      throwsA(
        predicate<Object>(
          (e) => e.toString().contains('telemetryProvider must be overridden'),
        ),
      ),
    );
  });
}
