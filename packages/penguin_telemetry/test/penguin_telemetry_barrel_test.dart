/// Verifies the penguin_telemetry barrel exports the public API surface
/// consumers rely on (spec §4.3) — a compile-time check as much as a
/// runtime one, since a missing export would fail to import.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_telemetry/penguin_telemetry.dart';

void main() {
  test('barrel exports the public telemetry API', () {
    expect(const NoopExporter(), isA<TelemetryExporter>());
    expect(
      const TelemetryConfig(serviceName: 's', serviceVersion: '1'),
      isA<TelemetryConfig>(),
    );
    expect(OtlpProtocol.httpJson, isA<OtlpProtocol>());
    expect(defaultMsBoundaries, isNotEmpty);
    expect(StandardMetrics.telemetryDropped, 'telemetry.dropped');
    expect(telemetryProvider, isA<Provider<Telemetry>>());
  });

  test(
    'NoopExporter reports success with zero accepted items on every signal',
    () async {
      const exporter = NoopExporter();

      final logs = await exporter.exportLogs(const <LogRecordData>[]);
      final metrics = await exporter.exportMetrics(const <MetricData>[]);
      final spans = await exporter.exportSpans(const <SpanData>[]);

      for (final result in [logs, metrics, spans]) {
        expect(result.ok, isTrue);
        expect(result.accepted, 0);
      }
    },
  );

  test('TelemetryConfig.fromAppConfig maps every OTLP protocol string', () {
    AppConfig configWith(String protocol) => AppConfig(
      productKey: 'p',
      appVersion: '1',
      environment: PenguinEnvironment.beta,
      apiBaseUrl: Uri.parse('https://api.example.com'),
      otlpProtocol: protocol,
      licenseServerUrl: 'https://license.penguintech.io',
    );

    expect(
      TelemetryConfig.fromAppConfig(configWith('http/json')).protocol,
      OtlpProtocol.httpJson,
    );
    expect(
      TelemetryConfig.fromAppConfig(configWith('http/protobuf')).protocol,
      OtlpProtocol.httpProtobuf,
    );
    expect(
      TelemetryConfig.fromAppConfig(configWith('grpc')).protocol,
      OtlpProtocol.grpc,
    );
    expect(
      TelemetryConfig.fromAppConfig(configWith('carrier-pigeon')).protocol,
      OtlpProtocol.httpJson,
    );
  });
}
