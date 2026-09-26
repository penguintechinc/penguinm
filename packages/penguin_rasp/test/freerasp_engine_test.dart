import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_rasp/penguin_rasp.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildTalsecConfig', () {
    // `AndroidConfig`/`IOSConfig` run freerasp's own platform-specific
    // validation in their constructors, gated on `defaultTargetPlatform`.
    // Overriding to a platform that is neither means these tests exercise
    // only THIS package's branching (which sub-config gets built from
    // which `RaspConfig` fields), not freerasp's own validation rules.
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test(
      'watcherMail is always blank (not yet plumbed through RaspConfig)',
      () {
        final config = buildTalsecConfig(const RaspConfig());
        expect(config.watcherMail, '');
      },
    );

    test('isProd is propagated from RaspConfig.isProd', () {
      expect(buildTalsecConfig(const RaspConfig(isProd: true)).isProd, isTrue);
      expect(
        buildTalsecConfig(const RaspConfig(isProd: false)).isProd,
        isFalse,
      );
    });

    test('null packageName builds no androidConfig', () {
      final config = buildTalsecConfig(const RaspConfig(packageName: null));
      expect(config.androidConfig, isNull);
    });

    test('empty packageName builds no androidConfig', () {
      final config = buildTalsecConfig(const RaspConfig(packageName: ''));
      expect(config.androidConfig, isNull);
    });

    test(
      'non-empty packageName builds androidConfig with the given fields',
      () {
        final config = buildTalsecConfig(
          const RaspConfig(
            packageName: 'io.penguintech.penguin_reference',
            signingCertHashes: ['AKoRuyLMM91E7lX/Zqp3u4jMmd0A7hH/Iqozu0TMVd0='],
          ),
        );
        expect(config.androidConfig, isNotNull);
        expect(
          config.androidConfig!.packageName,
          'io.penguintech.penguin_reference',
        );
        expect(config.androidConfig!.signingCertHashes, [
          'AKoRuyLMM91E7lX/Zqp3u4jMmd0A7hH/Iqozu0TMVd0=',
        ]);
      },
    );

    test('empty bundleIds builds no iosConfig', () {
      final config = buildTalsecConfig(const RaspConfig());
      expect(config.iosConfig, isNull);
    });

    test('non-empty bundleIds builds iosConfig with a blank teamId', () {
      final config = buildTalsecConfig(
        const RaspConfig(bundleIds: ['io.penguintech.penguinReference']),
      );
      expect(config.iosConfig, isNotNull);
      expect(config.iosConfig!.bundleIds, ['io.penguintech.penguinReference']);
      expect(config.iosConfig!.teamId, '');
    });

    test('both androidConfig and iosConfig can be populated together', () {
      final config = buildTalsecConfig(
        const RaspConfig(
          packageName: 'io.penguintech.penguin_reference',
          signingCertHashes: ['AKoRuyLMM91E7lX/Zqp3u4jMmd0A7hH/Iqozu0TMVd0='],
          bundleIds: ['io.penguintech.penguinReference'],
          isProd: true,
        ),
      );
      expect(config.androidConfig, isNotNull);
      expect(config.iosConfig, isNotNull);
      expect(config.isProd, isTrue);
    });
  });

  group('FreeraspEngine lifecycle (no platform channel involved)', () {
    test('construction never touches the platform channel', () {
      expect(FreeraspEngine(), isA<RaspEngine>());
    });

    test('threats exposes a stream before start is ever called', () {
      final engine = FreeraspEngine();
      expect(engine.threats, isA<Stream<RaspThreat>>());
    });

    test(
      'stop without start completes and closes the threats stream',
      () async {
        final engine = FreeraspEngine();
        var done = false;
        engine.threats.listen((_) {}, onDone: () => done = true);

        await engine.stop();

        expect(done, isTrue);
      },
    );

    test('stop is idempotent', () async {
      final engine = FreeraspEngine();
      await engine.stop();
      await engine.stop();
    });
  });

  group('FreeraspEngine.start/stop against a mocked freerasp channel', () {
    // freerasp's `Talsec` talks to native code over two named platform
    // channels (`talsec.app/freerasp/methods` for `start`,
    // `talsec.app/freerasp/events` for the threat stream); mocking those
    // two — the same technique Flutter's own plugin test suites use —
    // lets `FreeraspEngine.start`/`stop` run genuinely end to end on a
    // host machine, with no real device involved. `attachListener`'s
    // malware callback is pigeon-based and registers itself purely
    // locally (no outgoing platform call), so it needs no separate mock.
    const methodChannel = MethodChannel('talsec.app/freerasp/methods');
    const eventChannel = EventChannel('talsec.app/freerasp/events');
    MockStreamHandlerEventSink? eventSink;

    RaspConfig validAndroidConfig() => const RaspConfig(
      packageName: 'io.penguintech.penguin_reference',
      signingCertHashes: ['AKoRuyLMM91E7lX/Zqp3u4jMmd0A7hH/Iqozu0TMVd0='],
      isProd: true,
    );

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (call) async => null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            eventChannel,
            MockStreamHandler.inline(
              onListen: (args, events) => eventSink = events,
              onCancel: (args) => eventSink = null,
            ),
          );
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(eventChannel, null);
      eventSink = null;
    });

    test(
      'start succeeds and a native threat event maps onto threats',
      () async {
        final engine = FreeraspEngine();
        await engine.start(validAndroidConfig());

        final received = <RaspThreat>[];
        engine.threats.listen(received.add);

        // 209533833 is freerasp's wire code for `Threat.hooks` (see
        // `ThreatX.fromInt`) — simulates native code reporting a hooking
        // detection over the (mocked) event channel.
        eventSink!.success(209533833);
        await Future<void>.delayed(Duration.zero);

        expect(received, hasLength(1));
        expect(received.single.type, RaspThreatType.hooking);

        await engine.stop();
      },
    );

    test(
      'stop after a successful start detaches and closes the stream',
      () async {
        final engine = FreeraspEngine();
        await engine.start(validAndroidConfig());

        var done = false;
        engine.threats.listen((_) {}, onDone: () => done = true);

        await engine.stop();

        expect(done, isTrue);
      },
    );
  });
}
