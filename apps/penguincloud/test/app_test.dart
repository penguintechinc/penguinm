import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_app_shell/testing.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_flags/penguin_flags.dart';
import 'package:penguin_offline/penguin_offline.dart';
import 'package:penguin_telemetry/penguin_telemetry.dart';
import 'package:penguin_testing/penguin_testing.dart';
import 'package:penguin_update/penguin_update.dart';
import 'package:penguincloud/manifest.dart';

/// In-memory [SessionStore] stand-in — the real default touches
/// `flutter_secure_storage`, which has no working platform implementation
/// under `flutter_test` (see `shells/penguin_app_shell/test/router_test.dart`
/// for the same pattern).
class _FakeSessionStore extends SessionStore {
  Session? _stored;

  @override
  Future<Session?> load() async => _stored;

  @override
  Future<void> save(Session session) async {
    _stored = session;
  }

  @override
  Future<void> clear() async {
    _stored = null;
  }
}

AppConfig _config() => AppConfig(
  productKey: 'penguincloud',
  appVersion: appVersion,
  environment: PenguinEnvironment.prealpha,
  apiBaseUrl: Uri.parse('https://api.penguincloud.example'),
  licenseServerUrl: 'https://license.penguintech.io',
);

Session _session() => Session(
  accessToken: 'fake-token',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  claims: JwtClaims.fromJson(const <String, Object?>{'roles': <String>[]}),
);

/// The two module flags PenguinCloud's manifest gates its routes behind
/// (spec §11.2) — pre-seeded into the [InMemoryFlagCache] below so
/// `FeatureFlags.initialize`'s synchronous cache load enables both modules
/// without needing a real PostHog host configured (this test's [_config]
/// leaves `posthogHost`/`posthogProjectKey` null, matching a bypass-domain
/// build).
CachedFlags _enabledFlags() => CachedFlags(
  flags: const <String, Object?>{
    'penguincloud.springboard': true,
    'penguincloud.profile': true,
  },
  tier: 'free',
  lastFetched: DateTime.now(),
);

/// [overrides] plus the underlying [telemetry] instance — callers must
/// `await telemetry.shutdown()` before their test body returns, mirroring
/// `shells/penguin_app_shell/test/penguin_app_test.dart`.
typedef _TestOverrides = ({List<Override> overrides, Telemetry telemetry});

Future<_TestOverrides> _overrides({
  required FakeAuthBackend authBackend,
}) async {
  final config = _config();
  final telemetry = await Telemetry.start(
    TelemetryConfig.fromAppConfig(config),
    exporter: InMemoryTelemetryExporter(),
  );
  final featureFlags = FeatureFlags(
    config: FlagsConfig.fromAppConfig(config),
    flags: FakeFlagSource(),
    license: FakeLicenseSource(),
    cache: InMemoryFlagCache(initial: _enabledFlags()),
    log: telemetry.logger,
  );
  await featureFlags.initialize(distinctId: 'test');

  final overrides = <Override>[
    initialAppConfigProvider.overrideWithValue(config),
    telemetryProvider.overrideWithValue(telemetry),
    loggerProvider.overrideWithValue(telemetry.logger),
    metricsSinkProvider.overrideWithValue(
      TelemetryMetricsSink(telemetry.meter),
    ),
    traceSinkProvider.overrideWithValue(TelemetryTraceSink(telemetry.tracer)),
    featureFlagsProvider.overrideWithValue(featureFlags),
    authBackendProvider.overrideWithValue(authBackend),
    sessionStoreProvider.overrideWithValue(_FakeSessionStore()),
    apiClientProvider.overrideWith(
      (ref) => PenguinApiClient(
        config: config,
        tokens: ref.watch(authControllerProvider.notifier),
      ),
    ),
    connectivityMonitorProvider.overrideWithValue(FakeConnectivityMonitor()),
    updateCheckerProvider.overrideWithValue(FakeUpdateChecker()),
  ];
  return (overrides: overrides, telemetry: telemetry);
}

void main() {
  testWidgets(
    'auth redirect: unauthenticated shows the login form, a successful '
    'password login navigates to the springboard home',
    (tester) async {
      final authBackend = FakeAuthBackend()..queueLogin(Result.ok(_session()));
      final (:overrides, :telemetry) = await _overrides(
        authBackend: authBackend,
      );
      final manifest = buildManifestFor(config: _config());

      await pumpPenguinApp(tester, manifest, overrides: overrides);
      await tester.pumpAndSettle();

      // No stored session and nothing authenticated yet → redirected to
      // the login route; the springboard home content is not reachable.
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Your springboard'), findsNothing);

      // Drive the same AuthController the login form would, via the
      // scripted backend — exercises the identical redirect wiring
      // (`authRedirect` + `AuthRefreshListenable`) the shell tests, using
      // PenguinCloud's own manifest/router.
      final container = ProviderScope.containerOf(
        tester.element(find.text('Email')),
        listen: false,
      );
      await container
          .read(authControllerProvider.notifier)
          .login(
            const LoginRequest.password(
              email: 'penny@example.com',
              password: 'hunter2',
            ),
          );
      await tester.pumpAndSettle();

      expect(find.text('Your springboard'), findsOneWidget);
      expect(find.text('Email'), findsNothing);
      expect(authBackend.loginRequests, hasLength(1));

      await telemetry.shutdown();
    },
  );

  testWidgets(
    'app.startup.duration histogram is recorded via InMemoryTelemetryExporter',
    (tester) async {
      final exporter = InMemoryTelemetryExporter();
      final config = _config();
      final telemetry = await Telemetry.start(
        TelemetryConfig.fromAppConfig(config),
        exporter: exporter,
      );
      final featureFlags = FeatureFlags(
        config: FlagsConfig.fromAppConfig(config),
        flags: FakeFlagSource(),
        license: FakeLicenseSource(),
        cache: InMemoryFlagCache(initial: _enabledFlags()),
        log: telemetry.logger,
      );
      await featureFlags.initialize(distinctId: 'test');
      final authBackend = FakeAuthBackend();

      final overrides = <Override>[
        initialAppConfigProvider.overrideWithValue(config),
        telemetryProvider.overrideWithValue(telemetry),
        loggerProvider.overrideWithValue(telemetry.logger),
        metricsSinkProvider.overrideWithValue(
          TelemetryMetricsSink(telemetry.meter),
        ),
        traceSinkProvider.overrideWithValue(
          TelemetryTraceSink(telemetry.tracer),
        ),
        featureFlagsProvider.overrideWithValue(featureFlags),
        authBackendProvider.overrideWithValue(authBackend),
        sessionStoreProvider.overrideWithValue(_FakeSessionStore()),
        apiClientProvider.overrideWith(
          (ref) => PenguinApiClient(
            config: config,
            tokens: ref.watch(authControllerProvider.notifier),
          ),
        ),
        connectivityMonitorProvider.overrideWithValue(
          FakeConnectivityMonitor(),
        ),
        updateCheckerProvider.overrideWithValue(FakeUpdateChecker()),
      ];
      final manifest = buildManifestFor(config: config);

      await pumpPenguinApp(tester, manifest, overrides: overrides);
      await tester.pumpAndSettle();
      await telemetry.flush();

      exporter.expectHistogram(StandardMetrics.appStartupDuration);

      await telemetry.shutdown();
    },
  );
}
