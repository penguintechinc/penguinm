import 'package:penguin_core/penguin_core.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

/// A sibling app a manifest can hand off to (PenguinCloud → product apps,
/// companions → their family's core app) — deep link first, app-store
/// fallback second.
class SiblingApp {
  /// Creates a sibling-app reference. [scheme] is conventionally the same
  /// value as [applicationId] (`io.penguintech.<id>`), kept as a separate
  /// field since a deep-link scheme is not required to match the Android
  /// applicationId.
  const SiblingApp({
    required this.id,
    required this.displayName,
    required this.applicationId,
    required this.scheme,
  });

  /// Directory/pubspec id of the sibling app, e.g. `'waddles'`.
  final String id;

  /// Human-readable name shown in launcher UI/error messages.
  final String displayName;

  /// Android application id, e.g. `'io.penguintech.waddles'`.
  final String applicationId;

  /// Custom URL scheme the sibling app registers for deep links.
  final String scheme;

  /// The deep-link URI for [route] inside this sibling app
  /// (`<scheme>://open<route>`).
  Uri deepLink(String route) {
    final normalized = route.startsWith('/') ? route : '/$route';
    return Uri(scheme: scheme, host: 'open', path: normalized);
  }

  /// The Play Store fallback URI when the deep link can't be opened
  /// (sibling app not installed).
  Uri get storeUri => Uri.parse('market://details?id=$applicationId');
}

/// One-method abstraction over `url_launcher`'s `launchUrl` so
/// [SiblingAppLauncher] is testable without the real plugin.
abstract interface class UrlLauncher {
  /// Attempts to launch [uri]; returns whether it succeeded. May throw
  /// (mirroring the real `launchUrl`, which can throw a `PlatformException`
  /// instead of returning `false` depending on the failure) — callers must
  /// treat both as "couldn't launch".
  Future<bool> launch(Uri uri);
}

/// Always-fails [UrlLauncher] — useful in tests that want a launcher which
/// never succeeds without touching any platform channel. Not the shell's
/// default; see [UrlLauncherAdapter].
class NoopUrlLauncher implements UrlLauncher {
  /// Creates a no-op launcher.
  const NoopUrlLauncher();

  @override
  Future<bool> launch(Uri uri) async => false;
}

/// Signature of `package:url_launcher`'s top-level `launchUrl` function —
/// factored out purely so [UrlLauncherAdapter] can have a fake substituted
/// for it in tests without needing `url_launcher`'s own platform-interface
/// test seam (`UrlLauncherPlatform.instance`), which isn't a declared
/// dependency of this package.
typedef LaunchUrlFn =
    Future<bool> Function(Uri url, {url_launcher.LaunchMode mode});

/// Production [UrlLauncher] backed by `package:url_launcher`. Calls
/// `launchUrl` directly with `LaunchMode.externalApplication` — deliberately
/// never `canLaunchUrl` first: on Android 11+, `canLaunchUrl`'s package
/// visibility check requires every consuming app to declare a `<queries>`
/// manifest entry per sibling scheme, which this shared shell has no way to
/// mandate on each app's behalf. A `false` return or a thrown
/// `PlatformException` both mean "couldn't launch" — [SiblingAppLauncher]
/// treats them identically and falls back to the store.
class UrlLauncherAdapter implements UrlLauncher {
  /// Creates the real url_launcher-backed adapter. [launchUrlFn] is
  /// injectable for tests (defaults to the real `url_launcher.launchUrl`).
  const UrlLauncherAdapter({this.launchUrlFn = url_launcher.launchUrl});

  /// The `launchUrl`-shaped function this adapter delegates to.
  final LaunchUrlFn launchUrlFn;

  @override
  Future<bool> launch(Uri uri) {
    return launchUrlFn(uri, mode: url_launcher.LaunchMode.externalApplication);
  }
}

/// Outcome of a [SiblingAppLauncher.open] attempt.
enum LaunchOutcome {
  /// The sibling app's deep link was opened directly.
  opened,

  /// The deep link could not be opened; the user was sent to the store
  /// listing instead.
  sentToStore,

  /// Neither the deep link nor the store listing could be launched.
  failed,
}

/// Opens a [SiblingApp] by deep link, falling back to its store listing —
/// never throws, regardless of which step fails. Emits a `sibling_app.open`
/// span and a `sibling_app.launch` counter (attributed by [LaunchOutcome])
/// through the same [TraceSink]/[MetricsSink] interfaces the rest of the
/// shell uses, and logs a WARN when both the deep link and the store fail.
class SiblingAppLauncher {
  /// Creates a launcher using [launcher] (defaults to the real
  /// [UrlLauncherAdapter]) to perform the actual `launchUrl` calls, emitting
  /// telemetry through [metrics]/[traces]/[log] (each defaulting to a safe
  /// no-op/console implementation, matching every other telemetry-emitting
  /// class in this shell).
  SiblingAppLauncher({
    UrlLauncher? launcher,
    this.metrics = const NoopMetricsSink(),
    this.traces = const NoopTraceSink(),
    PenguinLogger? log,
  }) : _launcher = launcher ?? const UrlLauncherAdapter(),
       _log = log ?? ConsoleLogger();

  final UrlLauncher _launcher;

  /// Sink `sibling_app.launch` counters are recorded to.
  final MetricsSink metrics;

  /// Sink the per-`open()` span is started on.
  final TraceSink traces;
  final PenguinLogger _log;

  /// Tries [app]'s deep link for [route] first; on failure (not installed,
  /// launch rejected, or an unexpected error) falls back to the store
  /// listing. Never throws.
  Future<LaunchOutcome> open(SiblingApp app, {String route = '/'}) async {
    final span = traces.startSpan(
      'sibling_app.open',
      attributes: {'app': app.id},
    );
    try {
      final outcome = await _attempt(app, route);
      span.setAttribute('outcome', outcome.name);
      metrics.counter(
        'sibling_app.launch',
        1,
        attributes: {'app': app.id, 'outcome': outcome.name},
      );
      if (outcome == LaunchOutcome.failed) {
        _log.warn(
          'sibling app launch failed: neither the deep link nor the store could be opened',
          attributes: {'app': app.id},
        );
      }
      return outcome;
    } finally {
      span.end();
    }
  }

  Future<LaunchOutcome> _attempt(SiblingApp app, String route) async {
    if (await _tryLaunch(app.deepLink(route))) {
      return LaunchOutcome.opened;
    }
    if (await _tryLaunch(app.storeUri)) {
      return LaunchOutcome.sentToStore;
    }
    return LaunchOutcome.failed;
  }

  /// Launches [uri] via [_launcher], collapsing both failure shapes (a
  /// `false` return and a thrown exception) into a single `false`.
  Future<bool> _tryLaunch(Uri uri) async {
    try {
      return await _launcher.launch(uri);
    } catch (_) {
      return false;
    }
  }
}
