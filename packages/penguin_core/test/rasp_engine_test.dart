import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';

void main() {
  group('RaspPolicy.actionFor', () {
    const policy = RaspPolicy();

    for (final type in RaspPolicy.defaultBlockThreats) {
      test('blocks $type (default-block set)', () {
        expect(policy.actionFor(type), RaspAction.block);
      });
    }

    for (final type in RaspThreatType.values.where(
      (t) => !RaspPolicy.defaultBlockThreats.contains(t),
    )) {
      test('alerts on $type (not in default-block set)', () {
        expect(policy.actionFor(type), RaspAction.alert);
      });
    }
  });

  group('RaspPolicy defaults', () {
    test('const RaspPolicy() has expected defaults', () {
      const policy = RaspPolicy();
      expect(policy.enabled, isFalse);
      expect(policy.blockThreats, RaspPolicy.defaultBlockThreats);
      expect(policy.minAndroidSdk, isNull);
      expect(policy.minIosVersion, isNull);
    });

    test('RaspPolicy value equality', () {
      const a = RaspPolicy(enabled: true, minAndroidSdk: 26);
      const b = RaspPolicy(enabled: true, minAndroidSdk: 26);
      const c = RaspPolicy();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('RaspThreat', () {
    test('has value equality on type + detectedAt', () {
      final at = DateTime(2026, 9, 26);
      final a = RaspThreat(RaspThreatType.hooking, at);
      final b = RaspThreat(RaspThreatType.hooking, at);
      final c = RaspThreat(RaspThreatType.tampering, at);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('NoopRaspEngine', () {
    test('start and stop complete without error', () async {
      const engine = NoopRaspEngine();
      await expectLater(engine.start(const RaspConfig()), completes);
      await expectLater(engine.stop(), completes);
    });

    test('threats yields no events and closes', () async {
      const engine = NoopRaspEngine();
      expect(await engine.threats.toList(), isEmpty);
    });
  });

  group('raspEngineProvider', () {
    test('defaults to NoopRaspEngine', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(raspEngineProvider), isA<NoopRaspEngine>());
    });
  });
}
