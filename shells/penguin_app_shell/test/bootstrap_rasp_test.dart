import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_flags/penguin_flags.dart';
import 'package:penguin_telemetry/penguin_telemetry.dart';
import 'package:penguin_testing/penguin_testing.dart';

const _productKey = 'penguinm';
const _raspFlagKey = '$_productKey.rasp';

AppConfig _config() => AppConfig(
  productKey: _productKey,
  appVersion: '1.0.0',
  environment: PenguinEnvironment.prealpha,
  apiBaseUrl: Uri.parse('https://api.penguinm.example'),
  licenseServerUrl: 'https://license.penguintech.io',
);

AppManifest _manifest({RaspPolicy raspPolicy = const RaspPolicy()}) =>
    AppManifest(
      productKey: _productKey,
      appName: 'Penguin Reference',
      appVersion: '1.0.0',
      config: _config(),
      auth: AuthConfig.hosted(
        issuer: Uri.parse('https://api.penguinm.example'),
        clientId: 'penguinm-test',
        redirectUri: 'io.penguintech.penguinm.dev://oauth/callback',
      ),
      features: const [],
      raspPolicy: raspPolicy,
    );

/// A [FlagCache] preloaded so `isEnabled(_raspFlagKey)` resolves to
/// [raspEnabled] as soon as `FeatureFlags.initialize` loads the cache —
/// no PostHog host is configured in [_config], so the background refresh
/// never overwrites this cached snapshot with a fetch of its own.
InMemoryFlagCache _flagCache({required bool raspEnabled}) => InMemoryFlagCache(
  initial: CachedFlags(
    flags: {_raspFlagKey: raspEnabled},
    tier: 'free',
    lastFetched: DateTime.now(),
  ),
);

void main() {
  group('Bootstrap.run RASP phase', () {
    test('flag ON + policy enabled starts the injected engine', () async {
      final fake = FakeRaspEngine();
      final manifest = _manifest(raspPolicy: const RaspPolicy(enabled: true));
      final result = await Bootstrap.run(
        manifest,
        services: ShellServices(
          raspEngine: fake,
          flagCache: _flagCache(raspEnabled: true),
        ),
      );

      expect(fake.started, isTrue);
      expect(fake.startedWith, isNotNull);
      expect(result.warnings, isEmpty);
      // The guard must be retained beyond `run` returning, or its
      // subscription to `fake.threats` would be eligible for GC.
      expect(Bootstrap.activeRaspGuardForTest, isNotNull);

      final container = ProviderContainer(overrides: result.overrides);
      addTearDown(container.dispose);
      expect(container.read(raspEngineProvider), same(fake));
    });

    test('flag OFF leaves the engine unstarted', () async {
      final fake = FakeRaspEngine();
      final manifest = _manifest(raspPolicy: const RaspPolicy(enabled: true));
      final result = await Bootstrap.run(
        manifest,
        services: ShellServices(
          raspEngine: fake,
          flagCache: _flagCache(raspEnabled: false),
        ),
      );

      expect(fake.started, isFalse);
      expect(result.warnings, isEmpty);

      final container = ProviderContainer(overrides: result.overrides);
      addTearDown(container.dispose);
      // No override was appended, so the provider still resolves its
      // package default rather than the injected fake.
      expect(container.read(raspEngineProvider), isA<NoopRaspEngine>());
    });

    test(
      'policy disabled leaves the engine unstarted even with the flag on',
      () async {
        final fake = FakeRaspEngine();
        final manifest = _manifest(); // const RaspPolicy() ⇒ enabled: false
        final result = await Bootstrap.run(
          manifest,
          services: ShellServices(
            raspEngine: fake,
            flagCache: _flagCache(raspEnabled: true),
          ),
        );

        expect(fake.started, isFalse);
        expect(result.warnings, isEmpty);
      },
    );

    test(
      'an engine that throws on start never crashes Bootstrap.run',
      () async {
        // FakeRaspEngine.start() throws; RaspGuard.start() (packages/
        // penguin_rasp, already covered by its own test suite) catches
        // that internally, records a `rasp.failure` metric + error log,
        // and returns normally rather than rethrowing — so this never
        // reaches Bootstrap's own try/catch, and no `BootstrapWarning`
        // with step `'rasp'` is produced for an engine-start failure.
        // Bootstrap's surrounding try/catch instead guards the
        // construction steps around the engine (building `RaspGuard`
        // itself, `detectAndroidSdk()`) — exactly like every other
        // fail-soft phase in this file wraps calls that are not expected
        // to throw in practice. What matters here is that Bootstrap.run
        // still completes normally and every other managed provider is
        // still present in the result.
        final fake = FakeRaspEngine(throwOnStart: true);
        final manifest = _manifest(raspPolicy: const RaspPolicy(enabled: true));

        final result = await Bootstrap.run(
          manifest,
          services: ShellServices(
            raspEngine: fake,
            flagCache: _flagCache(raspEnabled: true),
          ),
        );

        expect(fake.started, isTrue);
        expect(result.warnings.where((w) => w.step == 'rasp'), isEmpty);

        final container = ProviderContainer(overrides: result.overrides);
        addTearDown(container.dispose);
        expect(container.read(telemetryProvider), isA<Telemetry>());
        expect(container.read(featureFlagsProvider), isA<FeatureFlags>());
        expect(container.read(authBackendProvider), isA<AuthBackend>());
        // The engine object itself is still handed to the provider even
        // though its `start()` failed internally — `RaspGuard` treats a
        // failed start as "detection didn't come up", not "the engine
        // reference is unusable", matching the exact bootstrap snippet
        // (`raspEngine = engine;` runs unconditionally once `guard.start()`
        // returns, since that call itself never throws).
        expect(container.read(raspEngineProvider), same(fake));
      },
    );
  });
}
