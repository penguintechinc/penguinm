import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_rasp/penguin_rasp.dart';
import 'package:penguin_testing/penguin_testing.dart';

class MockMetricsSink extends Mock implements MetricsSink {}

class MockPenguinLogger extends Mock implements PenguinLogger {}

/// Flushes the microtask queue so a broadcast-stream listener registered via
/// `.listen()` has had a chance to run before assertions.
Future<void> flushMicrotasks() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeRaspEngine engine;
  late MockMetricsSink metrics;
  late MockPenguinLogger logger;

  setUp(() {
    engine = FakeRaspEngine();
    metrics = MockMetricsSink();
    logger = MockPenguinLogger();
  });

  RaspGuard buildGuard({
    required bool enforce,
    RaspPolicy policy = const RaspPolicy(),
    void Function()? onBlock,
    int? currentAndroidSdk,
    String? currentIosVersion,
  }) => RaspGuard(
    engine: engine,
    config: const RaspConfig(),
    metrics: metrics,
    logger: logger,
    policy: policy,
    enforce: enforce,
    onBlock: onBlock,
    currentAndroidSdk: currentAndroidSdk,
    currentIosVersion: currentIosVersion,
  );

  group('RaspGuard threat handling', () {
    test('alert-type threat emits a threat metric + warn log', () async {
      final guard = buildGuard(enforce: true);
      await guard.start();

      engine.emit(RaspThreatType.deviceBinding);
      await flushMicrotasks();

      verify(
        () => metrics.counter(
          RaspMetrics.threat,
          1,
          attributes: any(named: 'attributes'),
        ),
      ).called(1);
      verify(
        () => logger.warn(any(), attributes: any(named: 'attributes')),
      ).called(1);
    });

    test('block-type threat emits a threat metric + warn log', () async {
      final guard = buildGuard(enforce: true);
      await guard.start();

      engine.emit(RaspThreatType.hooking);
      await flushMicrotasks();

      verify(
        () => metrics.counter(
          RaspMetrics.threat,
          1,
          attributes: any(named: 'attributes'),
        ),
      ).called(1);
      verify(
        () => logger.warn(any(), attributes: any(named: 'attributes')),
      ).called(1);
    });

    test('threat metric attributes carry threat/action/enforced', () async {
      final guard = buildGuard(enforce: true);
      await guard.start();

      engine.emit(RaspThreatType.hooking);
      await flushMicrotasks();

      final captured =
          verify(
                () => metrics.counter(
                  RaspMetrics.threat,
                  1,
                  attributes: captureAny(named: 'attributes'),
                ),
              ).captured.single
              as Map<String, Object?>;

      expect(captured['threat'], RaspThreatType.hooking.name);
      expect(captured['action'], RaspAction.block.name);
      expect(captured['enforced'], isTrue);
    });
  });

  group('RaspGuard onBlock', () {
    test('is called for a block-type threat when enforcing', () async {
      var blocked = false;
      final guard = buildGuard(enforce: true, onBlock: () => blocked = true);
      await guard.start();

      engine.emit(RaspThreatType.hooking);
      await flushMicrotasks();

      expect(blocked, isTrue);
    });

    test('is NOT called for a block-type threat when not enforcing', () async {
      var blocked = false;
      final guard = buildGuard(enforce: false, onBlock: () => blocked = true);
      await guard.start();

      engine.emit(RaspThreatType.hooking);
      await flushMicrotasks();

      expect(blocked, isFalse);
    });

    test(
      'is NOT called for an alert-type threat even when enforcing',
      () async {
        var blocked = false;
        final guard = buildGuard(enforce: true, onBlock: () => blocked = true);
        await guard.start();

        engine.emit(RaspThreatType.deviceBinding);
        await flushMicrotasks();

        expect(blocked, isFalse);
      },
    );
  });

  group('RaspGuard fail-soft: engine failures', () {
    test('throwOnStart records rasp.failure and start() completes', () async {
      engine.throwOnStart = true;
      final guard = buildGuard(enforce: true);

      await expectLater(guard.start(), completes);

      verify(
        () => metrics.counter(
          RaspMetrics.failure,
          1,
          attributes: any(named: 'attributes'),
        ),
      ).called(1);
      verify(
        () => logger.error(
          any(),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
      // A partially-started engine (e.g. an engine whose `start()` threw
      // after some internal setup) must be torn down rather than left
      // running with no downstream listener.
      expect(engine.stopped, isTrue);
    });

    test('a stream error records rasp.failure via the onError path', () async {
      final guard = buildGuard(enforce: true);
      await guard.start();

      engine.emitError(StateError('boom'));
      await flushMicrotasks();

      verify(
        () => metrics.counter(
          RaspMetrics.failure,
          1,
          attributes: any(named: 'attributes'),
        ),
      ).called(1);
      verify(
        () => logger.error(
          any(),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  group('RaspGuard Android OS-version gate', () {
    test('below minAndroidSdk emits unsupportedOs and calls onBlock (default '
        'block set)', () async {
      var blocked = false;
      final guard = buildGuard(
        enforce: true,
        policy: const RaspPolicy(minAndroidSdk: 26),
        currentAndroidSdk: 23,
        onBlock: () => blocked = true,
      );

      await guard.start();
      await flushMicrotasks();

      final captured =
          verify(
                () => metrics.counter(
                  RaspMetrics.threat,
                  1,
                  attributes: captureAny(named: 'attributes'),
                ),
              ).captured.single
              as Map<String, Object?>;
      expect(captured['threat'], RaspThreatType.unsupportedOs.name);
      expect(blocked, isTrue);
    });

    test('at or above minAndroidSdk emits no unsupportedOs threat', () async {
      var blocked = false;
      final guard = buildGuard(
        enforce: true,
        policy: const RaspPolicy(minAndroidSdk: 26),
        currentAndroidSdk: 30,
        onBlock: () => blocked = true,
      );

      await guard.start();
      await flushMicrotasks();

      verifyNever(
        () => metrics.counter(
          RaspMetrics.threat,
          1,
          attributes: any(named: 'attributes'),
        ),
      );
      expect(blocked, isFalse);
    });

    test('null currentAndroidSdk skips the gate entirely', () async {
      final guard = buildGuard(
        enforce: true,
        policy: const RaspPolicy(minAndroidSdk: 26),
      );

      await guard.start();
      await flushMicrotasks();

      verifyNever(
        () => metrics.counter(
          RaspMetrics.threat,
          1,
          attributes: any(named: 'attributes'),
        ),
      );
    });
  });

  group('RaspGuard iOS OS-version gate', () {
    test('below minIosVersion emits unsupportedOs and calls onBlock '
        '(default block set)', () async {
      var blocked = false;
      final guard = buildGuard(
        enforce: true,
        policy: const RaspPolicy(minIosVersion: '15.0'),
        currentIosVersion: '14.0',
        onBlock: () => blocked = true,
      );

      await guard.start();
      await flushMicrotasks();

      final captured =
          verify(
                () => metrics.counter(
                  RaspMetrics.threat,
                  1,
                  attributes: captureAny(named: 'attributes'),
                ),
              ).captured.single
              as Map<String, Object?>;
      expect(captured['threat'], RaspThreatType.unsupportedOs.name);
      expect(blocked, isTrue);
    });

    test('at or above minIosVersion emits no unsupportedOs threat', () async {
      var blocked = false;
      final guard = buildGuard(
        enforce: true,
        policy: const RaspPolicy(minIosVersion: '15.0'),
        currentIosVersion: '16.0',
        onBlock: () => blocked = true,
      );

      await guard.start();
      await flushMicrotasks();

      verifyNever(
        () => metrics.counter(
          RaspMetrics.threat,
          1,
          attributes: any(named: 'attributes'),
        ),
      );
      expect(blocked, isFalse);
    });
  });

  group('RaspGuard.stop', () {
    test('cancels the subscription and stops the engine', () async {
      final guard = buildGuard(enforce: true);
      await guard.start();

      await guard.stop();

      expect(engine.stopped, isTrue);

      // After stop, further emissions must not reach the (cancelled)
      // listener — the fake's controller is closed by stop() too.
      engine.emit(RaspThreatType.hooking);
      await flushMicrotasks();
      verifyNever(
        () => metrics.counter(
          RaspMetrics.threat,
          1,
          attributes: any(named: 'attributes'),
        ),
      );
    });
  });
}
