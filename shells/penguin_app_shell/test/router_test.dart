import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_flags/penguin_flags.dart';
import 'package:penguin_telemetry/penguin_telemetry.dart' show StandardMetrics;
import 'package:penguin_testing/penguin_testing.dart';
import 'package:penguin_ui/penguin_ui.dart';

class _TestModule extends FeatureModule {
  _TestModule(this._flagKey);

  final String? _flagKey;

  @override
  String get id => 'test';

  @override
  String? get flagKey => _flagKey;

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

AppConfig _config() => AppConfig(
  productKey: 'product',
  appVersion: '1.0.0',
  environment: PenguinEnvironment.prealpha,
  apiBaseUrl: Uri.parse('https://api.product.example'),
  licenseServerUrl: 'https://license.penguintech.io',
);

Session _session() => Session(
  accessToken: 'fake-token',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  claims: JwtClaims.fromJson(const {}),
);

/// In-memory [SessionStore] stand-in — the real default touches
/// `flutter_secure_storage`, which has no working platform implementation
/// under `flutter_test` (it can hang waiting on a system secret-service
/// that doesn't exist in this sandbox) rather than failing fast.
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

class _Harness extends StatelessWidget {
  const _Harness({required this.manifest});

  final AppManifest manifest;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        goRouterProvider.overrideWith((ref) => buildGoRouter(ref, manifest)),
      ],
      child: Consumer(
        builder: (context, ref, _) =>
            MaterialApp.router(routerConfig: ref.watch(goRouterProvider)),
      ),
    );
  }
}

Future<ProviderContainer> _pumpAuthenticatedHarness(
  WidgetTester tester,
  AppManifest manifest, {
  required bool flagEnabled,
}) async {
  final flagSource = FakeFlagSource(
    initialResult: Result.ok({manifest.features.single.flagKey!: flagEnabled}),
  );
  final featureFlags = FeatureFlags(
    config: FlagsConfig(
      productKey: 'product',
      // FeatureFlags only calls FlagSource.fetch when both are set.
      posthogHost: 'https://posthog.example',
      posthogProjectKey: 'phc_test',
      licenseServerUrl: Uri.parse('https://license.penguintech.io'),
    ),
    flags: flagSource,
    license: FakeLicenseSource(),
    cache: InMemoryFlagCache(),
    log: ConsoleLogger(),
  );
  // `initialize()` fires its refresh unawaited (cache-first semantics), so
  // wait for an explicit `refresh()` too — otherwise `isEnabled` would read
  // the still-empty cache instead of `flagSource`'s scripted result.
  await featureFlags.initialize(distinctId: 'test');
  await featureFlags.refresh(distinctId: 'test');

  final authBackend = FakeAuthBackend()..queueLogin(Result.ok(_session()));

  final overrides = <Override>[
    featureFlagsProvider.overrideWithValue(featureFlags),
    authBackendProvider.overrideWithValue(authBackend),
    sessionStoreProvider.overrideWithValue(_FakeSessionStore()),
    apiClientProvider.overrideWith(
      (ref) => PenguinApiClient(
        config: _config(),
        tokens: ref.watch(authControllerProvider.notifier),
      ),
    ),
  ];

  late final ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: Consumer(
        builder: (context, ref, _) {
          container = ProviderScope.containerOf(context);
          return _Harness(manifest: manifest);
        },
      ),
    ),
  );
  await container
      .read(authControllerProvider.notifier)
      .login(const LoginRequest.interactive());
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('flag ON: module route and destination are present', (
    tester,
  ) async {
    final manifest = AppManifest(
      productKey: 'product',
      appName: 'Test App',
      appVersion: '1.0.0',
      config: _config(),
      auth: AuthConfig.hosted(
        issuer: Uri.parse('https://api.product.example'),
        clientId: 'test',
        redirectUri: 'io.penguintech.test://oauth/callback',
      ),
      features: [_TestModule('product.test')],
      homeRoute: '/home',
    );

    await _pumpAuthenticatedHarness(tester, manifest, flagEnabled: true);

    expect(find.text('HOME_CONTENT'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);

    // Tapping the (only) destination exercises AppShellScaffold.onSelect,
    // which just re-navigates to the same route here.
    await tester.tap(find.byIcon(Icons.home));
    await tester.pumpAndSettle();
    expect(find.text('HOME_CONTENT'), findsOneWidget);
  });

  testWidgets(
    'flag OFF: navigating to the module route renders the not-found page',
    (tester) async {
      final manifest = AppManifest(
        productKey: 'product',
        appName: 'Test App',
        appVersion: '1.0.0',
        config: _config(),
        auth: AuthConfig.hosted(
          issuer: Uri.parse('https://api.product.example'),
          clientId: 'test',
          redirectUri: 'io.penguintech.test://oauth/callback',
        ),
        features: [_TestModule('product.test')],
        homeRoute: '/home',
      );

      await _pumpAuthenticatedHarness(tester, manifest, flagEnabled: false);

      // The module route is absent entirely, so landing on it renders the
      // router's errorBuilder (a not-found ErrorView) instead of the module's
      // content, and its destination never appears in the nav bar.
      expect(find.text('HOME_CONTENT'), findsNothing);
      expect(find.byIcon(Icons.home), findsNothing);
      expect(find.textContaining('Page not found'), findsOneWidget);
    },
  );

  testWidgets(
    'RouteMetricsObserver records a histogram and a span per navigation',
    (tester) async {
      final metrics = _RecordingMetricsSink();
      final traces = _RecordingTraceSink();
      final observer = RouteMetricsObserver(metrics: metrics, traces: traces);

      await tester.pumpWidget(
        MaterialApp(navigatorObservers: [observer], home: const Text('root')),
      );
      await tester.pumpAndSettle();

      expect(traces.spans, isNotEmpty);
      expect(metrics.histograms, isNotEmpty);
      expect(metrics.histograms.single.$1, StandardMetrics.routeLoadDuration);
    },
  );

  testWidgets('RouteMetricsObserver also records on didReplace', (
    tester,
  ) async {
    final metrics = _RecordingMetricsSink();
    final traces = _RecordingTraceSink();
    final observer = RouteMetricsObserver(metrics: metrics, traces: traces);

    // A pumped widget tree is needed for the scheduler to actually run a
    // post-frame callback when `pump()` is called below.
    await tester.pumpWidget(const MaterialApp(home: Text('root')));

    final route = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/replaced'),
      builder: (context) => const Text('replaced'),
    );
    observer.didReplace(newRoute: route, oldRoute: null);
    await tester.pump(const Duration(milliseconds: 20));

    expect(metrics.histograms.single.$1, StandardMetrics.routeLoadDuration);
    expect((traces.spans.single as _RecordingSpan).ended, isTrue);

    // didReplace with no newRoute is a deliberate no-op.
    observer.didReplace(newRoute: null, oldRoute: null);
    expect(metrics.histograms, hasLength(1));
  });
}

class _RecordingMetricsSink implements MetricsSink {
  final List<(String, num)> histograms = [];

  @override
  void counter(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  }) {}

  @override
  void histogram(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  }) {
    histograms.add((name, value));
  }

  @override
  void gauge(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  }) {}
}

class _RecordingTraceSink implements TraceSink {
  final List<SpanHandle> spans = [];

  @override
  SpanHandle startSpan(
    String name, {
    SpanHandle? parent,
    Map<String, Object?> attributes = const {},
  }) {
    final span = _RecordingSpan();
    spans.add(span);
    return span;
  }
}

class _RecordingSpan implements SpanHandle {
  bool ended = false;

  @override
  void setAttribute(String key, Object? value) {}

  @override
  void recordError(Object error, [StackTrace? stack]) {}

  @override
  void end() {
    ended = true;
  }

  @override
  String get traceparent => '';
}
