import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_testing/penguin_testing.dart';

void main() {
  group('FakeRaspEngine', () {
    test(
      'emit delivers a RaspThreat with the given type to a listener',
      () async {
        final engine = FakeRaspEngine();
        final future = engine.threats.first;

        engine.emit(RaspThreatType.hooking);

        final threat = await future;
        expect(threat.type, RaspThreatType.hooking);
      },
    );

    test('emit accepts an explicit detectedAt timestamp', () async {
      final engine = FakeRaspEngine();
      final at = DateTime.utc(2026, 1, 1);
      final future = engine.threats.first;

      engine.emit(RaspThreatType.debugger, at: at);

      final threat = await future;
      expect(threat.detectedAt, at);
    });

    test('start sets started true and records the config', () async {
      final engine = FakeRaspEngine();
      const config = RaspConfig(packageName: 'io.penguintech.reference');

      expect(engine.started, isFalse);
      await engine.start(config);

      expect(engine.started, isTrue);
      expect(engine.startedWith, same(config));
    });

    test('stopped starts false and becomes true after stop', () async {
      final engine = FakeRaspEngine();
      expect(engine.stopped, isFalse);

      await engine.stop();

      expect(engine.stopped, isTrue);
    });

    test('throwOnStart makes start throw', () async {
      final engine = FakeRaspEngine(throwOnStart: true);

      await expectLater(
        engine.start(const RaspConfig()),
        throwsA(isA<StateError>()),
      );
      expect(engine.started, isTrue);
    });

    test('after stop the stream is closed to further events', () async {
      final engine = FakeRaspEngine();
      final received = <RaspThreat>[];
      engine.threats.listen(received.add);

      await engine.stop();
      engine.emit(RaspThreatType.tampering);

      expect(received, isEmpty);
    });

    test('emitError adds an error to the threats stream', () async {
      final engine = FakeRaspEngine();
      final errors = <Object>[];
      final sub = engine.threats.listen((_) {}, onError: errors.add);

      engine.emitError(StateError('boom'));
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      await sub.cancel();
    });
  });
}
