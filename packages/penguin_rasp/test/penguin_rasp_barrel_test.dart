import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_rasp/penguin_rasp.dart';
import 'package:penguin_testing/penguin_testing.dart';

void main() {
  test('RaspGuard is exported and constructible', () {
    final guard = RaspGuard(
      engine: FakeRaspEngine(),
      config: const RaspConfig(),
      metrics: const NoopMetricsSink(),
      logger: ConsoleLogger(),
      policy: const RaspPolicy(),
      enforce: false,
    );

    expect(guard, isA<RaspGuard>());
  });

  test('RaspMetrics exports the well-known metric name strings', () {
    expect(RaspMetrics.threat, 'rasp.threat');
    expect(RaspMetrics.failure, 'rasp.failure');
  });

  test('raspEnforcementEnabled is exported and is a bool', () {
    expect(raspEnforcementEnabled, isA<bool>());
  });
}
