/// Smoke test verifying the penguin_core barrel exports every public symbol
/// other packages and apps are expected to build on.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';

void main() {
  test('barrel exports config, result, failure, logging, and roster types', () {
    final config = AppConfig(
      productKey: 'gazer',
      appVersion: '1.0.0',
      environment: PenguinEnvironment.prealpha,
      apiBaseUrl: Uri.parse('https://gazer.example.com'),
      licenseServerUrl: 'https://license.penguintech.io',
    );
    expect(config.productKey, 'gazer');

    const result = Result<int>.ok(1);
    expect(result.isOk, isTrue);

    const Failure failure = StorageFailure('x');
    expect(failure.message, 'x');

    final logger = ConsoleLogger();
    expect(logger, isA<PenguinLogger>());

    expect(KnownApps.all, isNotEmpty);
    expect(KnownApps.byId('gazer'), isNotNull);

    const clock = SystemClock();
    expect(clock.now(), isA<DateTime>());

    const metrics = NoopMetricsSink();
    const traces = NoopTraceSink();
    expect(metrics, isA<MetricsSink>());
    expect(traces, isA<TraceSink>());
  });
}
