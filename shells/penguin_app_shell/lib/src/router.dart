import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_flags/penguin_flags.dart';
import 'package:penguin_telemetry/penguin_telemetry.dart';
import 'package:penguin_ui/penguin_ui.dart';

import 'app_manifest.dart';
import 'default_login.dart';

/// go_router `NavigatorObserver` recording `app.route.load.duration` (a
/// histogram keyed by route TEMPLATE, never a concrete id — go_router sets
/// `Route.settings.name` to `GoRouterState.name ?? GoRouterState.path`,
/// which is always the matched pattern, e.g. `/items/:id`) and a span per
/// navigation.
class RouteMetricsObserver extends NavigatorObserver {
  /// Creates an observer emitting through [metrics]/[traces].
  RouteMetricsObserver({required this.metrics, required this.traces});

  /// Sink `app.route.load.duration` histograms are recorded to.
  final MetricsSink metrics;

  /// Sink the per-navigation span is started on.
  final TraceSink traces;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _record(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _record(newRoute);
  }

  void _record(Route<dynamic> route) {
    final template = route.settings.name ?? 'unknown';
    final span = traces.startSpan(
      'route.load',
      attributes: {'route': template},
    );
    final stopwatch = Stopwatch()..start();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      stopwatch.stop();
      metrics.histogram(
        StandardMetrics.routeLoadDuration,
        stopwatch.elapsedMilliseconds,
        attributes: {'route': template},
      );
      span.end();
    });
  }
}

/// Notifies go_router's `refreshListenable` whenever `AuthController`'s
/// state changes, so a login/logout/expiry re-evaluates `redirect`
/// immediately instead of waiting for the next navigation attempt.
class AuthRefreshListenable extends ChangeNotifier {
  /// Subscribes to [ref]'s `authControllerProvider`.
  AuthRefreshListenable(Ref ref) {
    _subscription = ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

/// Renders the shared chrome scaffold (`ResponsiveScaffold`) around a
/// `ShellRoute`'s matched child, wiring its `destinations` to `context.go`.
class AppShellScaffold extends StatelessWidget {
  /// Creates the shell scaffold for the given [destinations], highlighting
  /// [currentPath] and rendering [child] as the body.
  const AppShellScaffold({
    required this.destinations,
    required this.currentPath,
    required this.child,
    super.key,
  });

  /// Navigation destinations contributed by every enabled module.
  final List<NavigationDestinationSpec> destinations;

  /// The currently matched route path, used to highlight the active
  /// destination.
  final String currentPath;

  /// The routed content for the current match.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) return child;
    final selectedIndex = destinations.indexWhere(
      (d) => d.route == currentPath,
    );
    return ResponsiveScaffold(
      destinations: destinations,
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onSelect: (index) => GoRouter.of(context).go(destinations[index].route),
      body: child,
    );
  }
}

/// Builds the `GoRouter` for [manifest]: a top-level login route outside
/// the shell, and a `ShellRoute` wrapping every route contributed by a
/// module whose `flagKey` is enabled or null (R35) — re-evaluated whenever
/// `FeatureFlags.changes` fires, since [ref] is watched here (a Riverpod
/// provider rebuilding this function produces a fresh router with the
/// updated route set). A module whose flag is off contributes neither
/// routes nor a destination — navigating to its path renders the
/// `errorBuilder`'s not-found page.
GoRouter buildGoRouter(Ref ref, AppManifest manifest) {
  ref.watch(flagChangesProvider);
  final enabledModules = manifest.features.where((module) {
    final key = module.flagKey;
    return key == null || ref.watch(flagProvider(key));
  }).toList();

  final moduleRoutes = <RouteBase>[
    for (final module in enabledModules) ...module.routes(ref),
  ];
  final destinations = <NavigationDestinationSpec>[
    for (final module in enabledModules) ...module.destinations,
  ];

  final metrics = ref.watch(metricsSinkProvider);
  final traces = ref.watch(traceSinkProvider);
  final refreshListenable = AuthRefreshListenable(ref);
  ref.onDispose(refreshListenable.dispose);

  final router = GoRouter(
    initialLocation: manifest.homeRoute,
    refreshListenable: refreshListenable,
    observers: [RouteMetricsObserver(metrics: metrics, traces: traces)],
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      return authRedirect(
        authState,
        state,
        loginPath: manifest.loginRoute,
        homePath: manifest.homeRoute,
      );
    },
    // A dedicated not-found body rather than `ErrorView` — that widget's
    // `messageForFailure` renders a fixed, generic message per `Failure`
    // subtype (never the concrete text passed in), which would misrepresent
    // a gated-off/unknown route as some other kind of application failure.
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri.path}')),
    ),
    routes: [
      GoRoute(
        path: manifest.loginRoute,
        builder: (context, state) => Consumer(
          builder: (context, ref, _) =>
              buildLoginScreen(context, ref, manifest),
        ),
      ),
      // `ShellRoute` asserts its `routes` are non-empty, so when every
      // module is currently flag-gated off there is no shell route at
      // all — any module path simply falls through to `errorBuilder`'s
      // not-found page, exactly as if the route never existed.
      if (moduleRoutes.isNotEmpty)
        ShellRoute(
          builder: (context, state, child) => AppShellScaffold(
            destinations: destinations,
            currentPath: state.uri.path,
            child: child,
          ),
          routes: moduleRoutes,
        ),
      ...manifest.extraRoutes,
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
