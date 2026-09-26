import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_offline/penguin_offline.dart';
import 'package:penguin_telemetry/penguin_telemetry.dart';
import 'package:penguin_testing/penguin_testing.dart';
import 'package:penguin_ui/penguin_ui.dart';

/// In-memory [SessionStore] stand-in — the real default touches
/// `flutter_secure_storage`, which has no confirmed-safe platform
/// implementation under `flutter_test` in this sandbox. `sessionStoreProvider`
/// is not one of `Bootstrap.run`'s nine managed providers, so it can be
/// substituted through the plain `overrides` list without any duplicate-
/// override risk.
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
  List<NavigationDestinationSpec> get destinations => const [];
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

/// Calls the real `runPenguinApp` — the literal `runApp(...)` call and
/// its `addPostFrameCallback` included — inside a `testWidgets` body, then
/// pumps once to let the first frame (and the post-frame callback) run.
/// An earlier version of this file claimed `runApp()` deadlocks
/// `tester.pump()` under `TestWidgetsFlutterBinding`; that claim was
/// **wrong** — re-tested directly and it mounts and pumps exactly like
/// `tester.pumpWidget` does (`WidgetsFlutterBinding.ensureInitialized()`
/// returns the same `TestWidgetsFlutterBinding` instance either way). The
/// real obstacle, now fixed by [ShellServices] (`flagCache`/
/// `connectivityMonitor`), was two platform channels (`connectivity_plus`,
/// `SharedPreferences`) hanging indefinitely when `Bootstrap.run`
/// constructed them for real. `runApp` gives back no container handle of
/// its own, so this recovers one the same way production code never
/// needs to: locating the mounted `PenguinApp` element and reading its
/// nearest `ProviderScope`.
Future<ProviderContainer> _runPenguinAppAndPump(
  WidgetTester tester,
  AppManifest manifest, {
  ShellServices services = const ShellServices(),
  List<Override> overrides = const [],
}) async {
  await runPenguinApp(manifest, services: services, overrides: overrides);
  await tester.pump();
  return ProviderScope.containerOf(
    tester.element(find.byType(PenguinApp)),
    listen: false,
  );
}

void main() {
  test(
    'recordStartupDuration reports through the overridden MetricsSink',
    () async {
      final exporter = InMemoryTelemetryExporter();
      final telemetry = await Telemetry.start(
        TelemetryConfig.fromAppConfig(_config()),
        exporter: exporter,
      );
      addTearDown(telemetry.shutdown);

      final overrides = [
        metricsSinkProvider.overrideWithValue(
          TelemetryMetricsSink(telemetry.meter),
        ),
      ];

      recordStartupDuration(overrides, const Duration(milliseconds: 12));
      await telemetry.flush();

      exporter.expectHistogram(StandardMetrics.appStartupDuration);
    },
  );

  group('runPenguinApp, called for real inside testWidgets', () {
    testWidgets(
      'bootstraps for real and renders the home route once authenticated',
      (tester) async {
        final exporter = InMemoryTelemetryExporter();
        final authBackend = FakeAuthBackend()
          ..queueLogin(Result.ok(_session()));
        final services = ShellServices(
          connectivityMonitor: FakeConnectivityMonitor(),
          authBackend: authBackend,
          telemetryExporter: exporter,
          // FlagCache's first `.load()` resolves `SharedPreferences.
          // getInstance()` lazily, which hangs indefinitely under
          // `testWidgets` in this sandbox — confirmed by isolating
          // `FlagCache().load()` in a standalone testWidgets diagnostic (it
          // never returned, not even past flutter's own --timeout). Same
          // class of issue as `ConnectivityMonitor`'s platform channel.
          // The real feature-flags/auth/API HTTP calls (no injectable
          // client through `ShellServices` — see its class doc) fail fast
          // instead of hanging here, so no fake client is needed for them.
          flagCache: InMemoryFlagCache(),
        );

        final container = await _runPenguinAppAndPump(
          tester,
          _manifest(),
          services: services,
          overrides: [
            sessionStoreProvider.overrideWithValue(_FakeSessionStore()),
          ],
        );
        // AppChrome's UpdatePrompt reads updateStatusProvider, which races
        // a real response against a 5s `Future.delayed` timeout internally
        // (penguin_update's UpdateChecker.check) — `Future.any` never
        // cancels the losing branch's Timer, so it's still pending at test
        // teardown unless virtual time is advanced past it here.
        await tester.pump(const Duration(seconds: 6));

        // Unauthenticated until login completes — proves AuthController
        // initialized and the router redirected, i.e. the bootstrap order
        // (telemetry -> flags -> auth -> api client -> connectivity) ran
        // far enough to render a real screen instead of crashing on a
        // duplicate-override assertion.
        expect(find.text('Continue to sign in'), findsOneWidget);

        await tester.tap(find.text('Continue to sign in'));
        await tester.pumpAndSettle();

        expect(find.text('HOME_CONTENT'), findsOneWidget);
        expect(authBackend.loginRequests, hasLength(1));

        // The injected InMemoryTelemetryExporter proves the telemetry
        // bootstrap step ran for real (through ShellServices, not a
        // throwaway instance) and that app.startup.duration was recorded.
        final telemetry = container.read(telemetryProvider);
        await telemetry.flush();
        exporter.expectHistogram(StandardMetrics.appStartupDuration);
        await telemetry.shutdown();
      },
    );

    testWidgets(
      'uses the exact injected ConnectivityMonitor instance, with no duplicate-override assertion',
      (tester) async {
        final fakeMonitor = FakeConnectivityMonitor();
        final services = ShellServices(
          connectivityMonitor: fakeMonitor,
          authBackend: FakeAuthBackend(),
          telemetryExporter: InMemoryTelemetryExporter(),
          flagCache: InMemoryFlagCache(),
        );

        // Regression: this used to throw `AssertionError('Tried to
        // override a provider twice...')` in debug mode the moment
        // ProviderContainer was built, because Bootstrap.run
        // unconditionally appended its own connectivityMonitorProvider
        // override regardless of what the caller supplied in `overrides`.
        // Reaching the assertion below at all (not an AssertionError
        // during `_runPenguinAppAndPump`) is itself proof the crash is
        // gone.
        final container = await _runPenguinAppAndPump(
          tester,
          _manifest(),
          services: services,
          overrides: [
            sessionStoreProvider.overrideWithValue(_FakeSessionStore()),
          ],
        );
        // See the sibling test for why this is necessary (UpdateChecker's
        // internal 5s timeout Timer outlives Future.any).
        await tester.pump(const Duration(seconds: 6));

        expect(container.read(connectivityMonitorProvider), same(fakeMonitor));

        await container.read(telemetryProvider).shutdown();
      },
    );
  });
}
