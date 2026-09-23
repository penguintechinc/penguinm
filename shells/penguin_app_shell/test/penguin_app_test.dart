import 'package:flutter/material.dart';
import 'package:flutter_libs/flutter_libs.dart' show ConsoleVersion;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_app_shell/testing.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_flags/penguin_flags.dart';
import 'package:penguin_offline/penguin_offline.dart';
import 'package:penguin_telemetry/penguin_telemetry.dart';
import 'package:penguin_testing/penguin_testing.dart';
import 'package:penguin_update/penguin_update.dart';
import 'package:penguin_ui/penguin_ui.dart';

/// In-memory [SessionStore] stand-in — the real default touches
/// `flutter_secure_storage`, which has no working platform implementation
/// under `flutter_test`.
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

class _HomeModule extends FeatureModule {
  @override
  String get id => 'home';

  @override
  String? get flagKey => null;

  @override
  List<RouteBase> routes(Ref ref) => [
    GoRoute(
      path: '/home',
      builder: (context, state) => const Text('HOME_CONTENT'),
    ),
  ];

  @override
  List<NavigationDestinationSpec> get destinations => const [
    NavigationDestinationSpec(
      route: '/home',
      label: 'Home',
      icon: Icons.home,
      selectedIcon: Icons.home,
    ),
  ];
}

Session _session() => Session(
  accessToken: 'fake-token',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  claims: JwtClaims.fromJson(const {}),
);

AppConfig _config() => AppConfig(
  productKey: 'product',
  appVersion: '1.0.0',
  environment: PenguinEnvironment.prealpha,
  apiBaseUrl: Uri.parse('https://api.product.example'),
  licenseServerUrl: 'https://license.penguintech.io',
);

AppManifest _manifest() => AppManifest(
  productKey: 'product',
  appName: 'Test App',
  appVersion: '1.0.0',
  config: _config(),
  auth: AuthConfig.hosted(
    issuer: Uri.parse('https://api.product.example'),
    clientId: 'test',
    redirectUri: 'io.penguintech.test://oauth/callback',
  ),
  features: [_HomeModule()],
  homeRoute: '/home',
);

/// [overrides] plus the underlying [telemetry] instance — callers must
/// `await telemetry.shutdown()` before their test body returns:
/// `Telemetry.start` schedules a periodic export `Timer` that only
/// Bootstrap's real app lifecycle would otherwise cancel, and
/// `flutter_test`'s pending-timer check runs before `addTearDown`
/// callbacks fire, so tearing it down there is too late.
typedef _TestOverrides = ({List<Override> overrides, Telemetry telemetry});

Future<_TestOverrides> _overrides({
  required FakeAuthBackend authBackend,
  InMemoryTelemetryExporter? exporter,
}) async {
  final config = _config();
  final telemetry = await Telemetry.start(
    TelemetryConfig.fromAppConfig(config),
    exporter: exporter ?? InMemoryTelemetryExporter(),
  );
  final featureFlags = FeatureFlags(
    config: FlagsConfig.fromAppConfig(config),
    flags: FakeFlagSource(),
    license: FakeLicenseSource(),
    cache: InMemoryFlagCache(),
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
    'auth redirect end-to-end: unauthenticated shows login, login navigates home',
    (tester) async {
      final authBackend = FakeAuthBackend()..queueLogin(Result.ok(_session()));
      final (:overrides, :telemetry) = await _overrides(
        authBackend: authBackend,
      );

      await pumpPenguinApp(tester, _manifest(), overrides: overrides);
      await tester.pumpAndSettle();

      // No stored session and no queued backend session yet consumed →
      // AuthController.initialize() lands on unauthenticated → redirected
      // to the hosted login screen, never the module content.
      expect(find.text('Continue to sign in'), findsOneWidget);
      expect(find.text('HOME_CONTENT'), findsNothing);

      await tester.tap(find.text('Continue to sign in'));
      await tester.pumpAndSettle();

      // A successful interactive login flips AuthController to
      // authenticated; refreshListenable re-runs the redirect and lands on
      // the home route.
      expect(find.text('HOME_CONTENT'), findsOneWidget);
      expect(find.text('Continue to sign in'), findsNothing);

      await telemetry.shutdown();
    },
  );

  testWidgets(
    'app.startup.duration histogram is recorded via InMemoryTelemetryExporter',
    (tester) async {
      final exporter = InMemoryTelemetryExporter();
      final authBackend = FakeAuthBackend()..queueLogin(Result.ok(_session()));
      final (:overrides, :telemetry) = await _overrides(
        authBackend: authBackend,
        exporter: exporter,
      );

      await pumpPenguinApp(tester, _manifest(), overrides: overrides);
      await tester.pumpAndSettle();

      await telemetry.flush();
      exporter.expectHistogram(StandardMetrics.appStartupDuration);

      await telemetry.shutdown();
    },
  );

  testWidgets('renders the console version overlay below prod', (tester) async {
    final authBackend = FakeAuthBackend()..queueLogin(Result.ok(_session()));
    final (:overrides, :telemetry) = await _overrides(authBackend: authBackend);

    await pumpPenguinApp(tester, _manifest(), overrides: overrides);
    await tester.pumpAndSettle();

    // ConsoleVersion renders nothing visible but must be mounted (non-prod
    // environment) — its presence proves the chrome wiring, not appearance.
    expect(find.byType(ConsoleVersion), findsOneWidget);

    await telemetry.shutdown();
  });
}
