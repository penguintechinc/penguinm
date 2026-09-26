import 'package:flutter_test/flutter_test.dart';
import 'package:freerasp/freerasp.dart' show Threat;
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

  test('FreeraspEngine is exported and constructible', () {
    expect(FreeraspEngine(), isA<RaspEngine>());
  });

  test('mapFreeraspThreat is exported and callable', () {
    expect(mapFreeraspThreat(Threat.hooks), RaspThreatType.hooking);
  });

  test('isIosVersionBelow is exported and callable', () {
    expect(isIosVersionBelow('14.0', '15.0'), isTrue);
  });

  test('detectAndroidSdk/detectIosVersion are exported and callable', () async {
    // `defaultTargetPlatform` defaults to `TargetPlatform.android` under
    // `flutter test`, so `detectIosVersion` short-circuits to null via its
    // off-platform guard, while `detectAndroidSdk` passes the guard and
    // falls back to null via its own try/catch (no real `device_info_plus`
    // platform channel is mocked in this barrel test) — either way, both
    // calls remain exported, callable, and null-safe with no native code.
    expect(await detectAndroidSdk(), isNull);
    expect(await detectIosVersion(), isNull);
  });
}
