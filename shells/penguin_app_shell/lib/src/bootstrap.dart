import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode, visibleForTesting;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_flags/penguin_flags.dart';
import 'package:penguin_offline/penguin_offline.dart'
    show ConnectivityMonitor, connectivityMonitorProvider;
import 'package:penguin_rasp/penguin_rasp.dart';
import 'package:penguin_telemetry/penguin_telemetry.dart';

import 'app_manifest.dart';
import 'bootstrap_result.dart';
import 'rasp_terminate.dart';

/// A [FlagSource] used when no PostHog host/project key is configured;
/// `FeatureFlags` never calls it in that case (see its `_refreshInternal`
/// guard), but a real, harmless implementation is safer than a stub that
/// throws if that guard ever changes.
class _NoPostHogFlagSource implements FlagSource {
  const _NoPostHogFlagSource();

  @override
  Future<Result<Map<String, Object?>>> fetch({
    required String distinctId,
    Map<String, String> properties = const {},
  }) async => const Result.ok(<String, Object?>{});
}

/// Last-resort [AuthBackend] used only when constructing the real hosted
/// or password backend itself threw (never expected in practice, since
/// `AppManifest.auth` is always one of the two supported configs) — every
/// call reports the backend as unavailable rather than crashing the app.
class _UnavailableAuthBackend implements AuthBackend {
  const _UnavailableAuthBackend();

  @override
  Future<Result<Session>> login(LoginRequest request) async =>
      const Result.err(AuthFailure(null, 'Auth backend unavailable'));

  @override
  Future<Result<Session>> refresh(Session session) async =>
      const Result.err(AuthFailure(null, 'Auth backend unavailable'));

  @override
  Future<Result<void>> logout(Session session) async => const Result.ok(null);
}

/// Validates an optional OTLP endpoint before it's handed to
/// `OtlpHttpJsonExporter` — throws for a non-null endpoint missing a
/// scheme or host, since that would otherwise silently produce an exporter
/// that can never successfully export.
void _assertValidOtlpEndpoint(Uri? endpoint) {
  if (endpoint == null) return;
  if (!endpoint.hasScheme || endpoint.host.isEmpty) {
    throw ArgumentError.value(
      endpoint,
      'otlpEndpoint',
      'must be an absolute http(s) URL',
    );
  }
}

/// Platform- or network-bound collaborators [Bootstrap.run] would
/// otherwise construct itself from a real plugin — inject the ones a test
/// (or an app with its own reason to substitute one) needs to replace with
/// a fake or a pre-configured instance.
///
/// This exists because [Bootstrap.run]'s generic `overrides` parameter
/// cannot be used to fake any of the nine providers Bootstrap itself
/// manages (see the class doc on [Bootstrap.run] for why — Riverpod
/// rejects two overrides for the same provider in one container, and
/// Bootstrap always appends its own). [ShellServices] is the supported
/// seam for exactly that subset of managed collaborators that are
/// platform- or network-bound and therefore risky or impossible to
/// exercise for real under `flutter_test`/CI (most notably
/// `ConnectivityMonitor`, backed by `connectivity_plus`, which has no
/// working platform channel in many sandboxes and hangs — rather than
/// failing fast — when started for real).
///
/// Fields intentionally **not** included here: the HTTP client used by
/// the flags sources, the auth backend, and the API client is not exposed
/// here because `shells/penguin_app_shell`'s own `pubspec.yaml` does not
/// declare a direct dependency on `package:http` (each of those types
/// already defaults its own `client` parameter to a real `http.Client()`
/// internally when none is supplied); every real HTTP call those
/// collaborators make fails fast rather than hanging under
/// `flutter_test`/CI in this sandbox (unlike the platform-channel-backed
/// collaborators above), so there is no test-blocking reason to inject
/// one through this bundle. `clockProvider` and every other non-managed
/// provider are already fully overridable through [Bootstrap.run]'s
/// `overrides` list (Bootstrap never touches them, so there is no
/// collision to work around); `SiblingAppLauncher`'s `UrlLauncher` is
/// constructed independently by app code from `AppManifest.siblings`,
/// never by `Bootstrap`/`runPenguinApp`, so there is nothing for this
/// bundle to inject it into.
class ShellServices {
  /// Creates a services bundle; every field defaults to `null`, meaning
  /// "let Bootstrap construct the real one" — passing no [ShellServices]
  /// at all to [Bootstrap.run]/`runPenguinApp` is exactly equivalent to
  /// `const ShellServices()`. Production behavior is unchanged either way.
  const ShellServices({
    this.connectivityMonitor,
    this.authBackend,
    this.telemetryExporter,
    this.flagCache,
    this.raspEngine,
    this.onRaspBlock,
  });

  /// Replaces the real `connectivity_plus`-backed [ConnectivityMonitor]
  /// Bootstrap would otherwise construct and `.start()` lazily. Inject a
  /// `FakeConnectivityMonitor` (from `penguin_testing`) here — the
  /// documented cause of `runPenguinApp` hanging under `flutter_test` and
  /// most CI sandboxes, which have no working platform channel for it.
  /// Bootstrap still calls `.start()` on whichever monitor it ends up
  /// with, injected or real.
  final ConnectivityMonitor? connectivityMonitor;

  /// Replaces the real hosted/password [AuthBackend] Bootstrap would
  /// otherwise construct from `AppManifest.auth`. Inject a
  /// `FakeAuthBackend` (from `penguin_testing`) to drive login
  /// deterministically without a real OIDC browser flow or backend.
  final AuthBackend? authBackend;

  /// Replaces the [TelemetryExporter] `Telemetry.start` would otherwise
  /// resolve from `AppConfig.otlpEndpoint` (a real `OtlpHttpJsonExporter`,
  /// or `NoopExporter` when no endpoint is configured). Inject an
  /// `InMemoryTelemetryExporter` (from `penguin_testing`) to assert on
  /// emitted logs/metrics/spans — bypasses `Bootstrap.run`'s own
  /// endpoint-validation-and-fallback logic entirely, since a caller
  /// supplying an exporter directly has already made that choice.
  final TelemetryExporter? telemetryExporter;

  /// Replaces the real [FlagCache] `Bootstrap.run` would otherwise
  /// construct for `FeatureFlags`'s offline cache. `FlagCache`'s first
  /// `.load()`/`.save()` call resolves `SharedPreferences.getInstance()`
  /// lazily — confirmed (via an isolated `testWidgets` diagnostic) to hang
  /// indefinitely under `flutter_test`'s platform-channel handling in this
  /// sandbox, the same class of issue as the undeclared platform channel
  /// behind `ConnectivityMonitor`. Inject an `InMemoryFlagCache` (from
  /// `penguin_testing`) to avoid it.
  final FlagCache? flagCache;

  /// Replaces the real `FreeraspEngine` (from `penguin_rasp`) the RASP
  /// bootstrap phase would otherwise construct and start. Inject a
  /// `FakeRaspEngine` (from `penguin_testing`) to drive detections
  /// deterministically without the native freerasp platform channel, which
  /// has no working implementation under `flutter_test`/CI.
  final RaspEngine? raspEngine;

  /// Replaces `raspTerminate` as the callback `RaspGuard` invokes when a
  /// block-type threat fires while enforcing. Inject a spy in tests —
  /// `raspTerminate` must never actually run under `flutter_test` (it hard
  /// exits the process). Null means: use `raspTerminate`.
  final void Function()? onRaspBlock;
}

/// Resolves every cross-cutting provider a penguinm app needs — telemetry,
/// feature flags, the auth backend, and the API client — from an
/// [AppManifest], with every step fail-soft: a step that throws records a
/// [BootstrapWarning] and falls back to a safe default instead of ever
/// propagating out of [run]. Exposed as a static method (not a widget
/// lifecycle) so it can be unit-tested directly, independent of
/// `runPenguinApp`.
class Bootstrap {
  const Bootstrap._();

  /// Keeps the RASP phase's [RaspGuard] alive for the app's lifetime once
  /// [run] returns. [run] is a static method with no instance and
  /// [BootstrapResult] holds only provider overrides (plain data, not the
  /// guard itself), so without a reference held somewhere outside `run`'s
  /// local scope, the guard — and the stream subscription it holds on the
  /// RASP engine's `threats` stream — would become eligible for garbage
  /// collection the moment `run` returns, silently ending detection. A
  /// private static field is the simplest holder; [activeRaspGuardForTest]
  /// exposes it read-only so tests can assert it is retained.
  static RaspGuard? _activeRaspGuard;

  /// The most recently retained RASP guard, or null if RASP has never
  /// started. Test-only: production code has no reason to read this back
  /// (the guard's job is done once it's subscribed).
  @visibleForTesting
  static RaspGuard? get activeRaspGuardForTest => _activeRaspGuard;

  /// Runs the full bootstrap sequence for [manifest], always building real
  /// implementations for the nine providers it manages
  /// (`initialAppConfigProvider`, `telemetryProvider`, `loggerProvider`,
  /// `metricsSinkProvider`, `traceSinkProvider`, `featureFlagsProvider`,
  /// `authBackendProvider`, `apiClientProvider`,
  /// `connectivityMonitorProvider`) — unless [services] supplies a
  /// platform-/network-bound collaborator to use instead (see
  /// [ShellServices]). Every entry in [overrides] must target a
  /// *different* provider than the nine above (e.g. `clockProvider`,
  /// `sessionStoreProvider`) — Riverpod rejects two overrides for the same
  /// provider in one container, so [overrides] is merged into
  /// `result.overrides` unchanged rather than de-duplicated against it; use
  /// [services], not `overrides`, to fake any of the nine managed
  /// providers through this entrypoint. To render `PenguinApp` against
  /// fakes for *every* provider instead (widget/golden tests),
  /// `pumpPenguinApp` remains the more convenient option — it does not
  /// call [run] at all.
  static Future<BootstrapResult> run(
    AppManifest manifest, {
    ShellServices services = const ShellServices(),
    List<Override> overrides = const [],
  }) async {
    final stopwatch = Stopwatch()..start();
    final warnings = <BootstrapWarning>[];
    final config = manifest.config;
    final bootLogger = ConsoleLogger();

    // 1. Telemetry — logger/metrics/traces are always derived from
    //    whichever Telemetry instance results, so every signal shares one
    //    pipeline.
    Telemetry telemetry;
    final injectedExporter = services.telemetryExporter;
    if (injectedExporter != null) {
      telemetry = await Telemetry.start(
        TelemetryConfig.fromAppConfig(config),
        exporter: injectedExporter,
      );
    } else {
      try {
        _assertValidOtlpEndpoint(config.otlpEndpoint);
        telemetry = await Telemetry.start(
          TelemetryConfig.fromAppConfig(config),
        );
      } catch (e, st) {
        warnings.add(BootstrapWarning('telemetry', e));
        bootLogger.log(
          LogLevel.warn,
          'telemetry bootstrap failed; falling back to NoopExporter',
          attributes: {'error': e.toString()},
          error: e,
          stackTrace: st,
        );
        telemetry = await Telemetry.start(
          TelemetryConfig.fromAppConfig(config),
          exporter: const NoopExporter(),
        );
      }
    }
    final logger = telemetry.logger;
    final metrics = TelemetryMetricsSink(telemetry.meter);
    final traces = TelemetryTraceSink(telemetry.tracer);

    // 2. Feature flags — cache-first, background-refreshing;
    //    `FeatureFlags.initialize` never throws internally (every failure
    //    degrades to the existing cache), but the call is still guarded
    //    here so the "no step may throw" contract holds regardless.
    final flagsConfig = FlagsConfig.fromAppConfig(config);
    final flagSource =
        (flagsConfig.posthogHost != null &&
            flagsConfig.posthogProjectKey != null)
        ? PostHogFlagSource(
            host: Uri.parse(flagsConfig.posthogHost!),
            projectKey: flagsConfig.posthogProjectKey!,
          )
        : const _NoPostHogFlagSource();
    final featureFlags = FeatureFlags(
      config: flagsConfig,
      flags: flagSource,
      license: PenguinLicenseSource(serverUrl: flagsConfig.licenseServerUrl),
      cache: services.flagCache ?? FlagCache(),
      log: logger,
    );
    try {
      await featureFlags.initialize(distinctId: config.productKey);
    } catch (e, st) {
      warnings.add(BootstrapWarning('flags', e));
      logger.log(
        LogLevel.warn,
        'feature flags initialize failed',
        attributes: {'error': e.toString()},
        error: e,
        stackTrace: st,
      );
    }

    // 3. RASP (runtime application self-protection) — gated by both the
    //    per-app policy and the `${productKey}.rasp` feature flag (default
    //    OFF), so it is a runtime kill-switch as well as a build toggle.
    //    Engine start/detection failures never escape this phase: recorded
    //    as a `BootstrapWarning('rasp', e)` and logged, matching every
    //    other phase's contract.
    RaspEngine? raspEngine;
    try {
      if (manifest.raspPolicy.enabled &&
          featureFlags.isEnabled('${config.productKey}.rasp')) {
        final engine = services.raspEngine ?? FreeraspEngine();
        final guard = RaspGuard(
          engine: engine,
          config: RaspConfig(
            packageName: manifest.applicationId,
            isProd: kReleaseMode,
            minAndroidSdk: manifest.raspPolicy.minAndroidSdk,
            minIosVersion: manifest.raspPolicy.minIosVersion,
          ),
          metrics: metrics,
          logger: logger,
          policy: manifest.raspPolicy,
          enforce: raspEnforcementEnabled,
          onBlock: services.onRaspBlock ?? raspTerminate,
          currentAndroidSdk: await detectAndroidSdk(),
        );
        await guard.start();
        raspEngine = engine;
        // Retained for the app's lifetime so the guard's stream
        // subscription (and thus detection) is not garbage-collected once
        // `Bootstrap.run` returns — nothing else in Bootstrap's return
        // value (`BootstrapResult`) holds a reference to it.
        _activeRaspGuard = guard;
      }
    } catch (e) {
      warnings.add(BootstrapWarning('rasp', e));
      logger.warn('RASP bootstrap failed', attributes: {'error': e.toString()});
    }

    // 4. Auth backend — sync, plain-object construction; wrapped anyway so
    //    a future change to either backend constructor can never escape.
    //    Skipped entirely when the caller injects one via `services`.
    AuthBackend authBackend;
    final injectedAuthBackend = services.authBackend;
    if (injectedAuthBackend != null) {
      authBackend = injectedAuthBackend;
    } else {
      try {
        authBackend = switch (manifest.auth) {
          HostedAuthConfig() => HostedLoginBackend(manifest.auth),
          PasswordAuthConfig() => PasswordAuthBackend(
            manifest.auth,
            apiBaseUrl: config.apiBaseUrl,
          ),
        };
      } catch (e, st) {
        warnings.add(BootstrapWarning('auth', e));
        logger.log(
          LogLevel.warn,
          'auth backend construction failed',
          attributes: {'error': e.toString()},
          error: e,
          stackTrace: st,
        );
        authBackend = const _UnavailableAuthBackend();
      }
    }

    // 5. API client — a lazy override so it always resolves
    //    `authControllerProvider.notifier` from whichever container ends
    //    up hosting the app (never a throwaway one built here), keeping
    //    the API client and the auth controller it takes tokens from in
    //    the same provider scope.
    final apiClientOverride = apiClientProvider.overrideWith(
      (ref) => PenguinApiClient(
        config: config,
        tokens: ref.watch(authControllerProvider.notifier),
        metrics: metrics,
        traces: traces,
        log: logger,
      ),
    );

    // 6. Connectivity monitor — a lazy override so `.start()` runs once,
    //    lazily, in the container the app actually uses; its failure is
    //    caught inside the provider body itself (never synchronously, so
    //    a provider read can never throw) and only logged, since a
    //    missing platform channel (e.g. under `flutter_test`) must
    //    degrade to `ConnectivityStatus.unknown`, never crash. When the
    //    caller injects a monitor via `services`, that exact instance is
    //    used (and still `.start()`-ed) instead of a real one.
    final injectedMonitor = services.connectivityMonitor;
    final connectivityOverride = connectivityMonitorProvider.overrideWith((
      ref,
    ) {
      final monitor = injectedMonitor ?? ConnectivityMonitor();
      ref.onDispose(() => unawaited(monitor.dispose()));
      unawaited(
        monitor.start().catchError((Object e, StackTrace st) {
          ref
              .read(loggerProvider)
              .warn(
                'connectivity monitor failed to start',
                attributes: {'error': e.toString()},
              );
        }),
      );
      return monitor;
    });

    final finalOverrides = <Override>[
      ...overrides,
      initialAppConfigProvider.overrideWithValue(config),
      telemetryProvider.overrideWithValue(telemetry),
      loggerProvider.overrideWithValue(logger),
      metricsSinkProvider.overrideWithValue(metrics),
      traceSinkProvider.overrideWithValue(traces),
      featureFlagsProvider.overrideWithValue(featureFlags),
      authBackendProvider.overrideWithValue(authBackend),
      apiClientOverride,
      connectivityOverride,
      if (raspEngine != null) raspEngineProvider.overrideWithValue(raspEngine),
    ];

    stopwatch.stop();
    return BootstrapResult(
      overrides: finalOverrides,
      startupDuration: stopwatch.elapsed,
      warnings: warnings,
    );
  }
}
