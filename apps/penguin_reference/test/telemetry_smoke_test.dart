import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_telemetry/penguin_telemetry.dart';
import 'package:penguin_testing/penguin_testing.dart';

/// Allows this test's `OtlpHttpJsonExporter`/`OtlpSinkClient` calls to use
/// real sockets — `flutter_test` blocks real HTTP with a fake client once
/// the test binding initialises (agent-rules.md); the base
/// [HttpOverrides] implementation is the real, unmodified client.
class _RealHttp extends HttpOverrides {}

/// A self-contained manifest for this smoke test, independent of
/// `--dart-define`s: `lib/manifest.dart`'s `buildManifest()` requires
/// `API_BASE_URL` via `AppConfig.fromEnvironment`, but
/// `telemetry-validate.sh` only sets the `OTLP_SINK` env var, so this test
/// builds its own config directly (mirroring `env/dev.json`) rather than
/// depending on a dart-define this script never sets.
AppManifest _buildTestManifest(AppConfig config) {
  return AppManifest(
    productKey: config.productKey,
    appName: 'Penguin Reference',
    appVersion: config.appVersion,
    config: config,
    auth: AuthConfig.hosted(
      issuer: config.apiBaseUrl,
      clientId: 'io.penguintech.penguin_reference',
      redirectUri: 'io.penguintech.penguin_reference.dev://oauth/callback',
    ),
    features: const [],
  );
}

void main() {
  group('Telemetry smoke test', () {
    // A plain `test()`, not `testWidgets()`: this body does real async I/O
    // (Bootstrap.run's license fetch, the OTLP exporter's HTTP POSTs, and
    // an explicit `Future.delayed`) and never pumps a widget tree.
    // `testWidgets()` runs its callback inside
    // `AutomatedTestWidgetsFlutterBinding`'s `FakeAsync` zone (see
    // `binding.dart`'s `runTest`), which replaces every `Timer` — including
    // the ones backing `Future.delayed` and every `.timeout()` call in
    // `PenguinLicenseSource`/`OtlpHttpJsonExporter` — with a `FakeTimer`
    // that only elapses when something calls `tester.pump()`. Since this
    // test never pumps, those timers never fire and the test hangs
    // indefinitely with no output (confirmed by reading
    // `AutomatedTestWidgetsFlutterBinding.runTest`/`postTest` in the
    // Flutter 3.44.8 SDK). `test()` runs in the real zone instead, so every
    // Timer here — the 5s network timeouts and the 100ms delay — elapses
    // in real wall-clock time, same as the existing precedent for
    // real-HTTP tests in this repo (e.g.
    // `packages/penguin_telemetry/test/contract/otlp_sink_contract_test.dart`,
    // `packages/penguin_api/test/retry_client_test.dart`).
    test('emits logs, metrics, and traces', () async {
      // Runtime env var, not a `--dart-define`: `telemetry-validate.sh`
      // sets `OTLP_SINK` as a process environment variable
      // (`OTLP_SINK="$SINK_URL" flutter test ...`), and reading it via
      // `Platform.environment` (rather than `String.fromEnvironment`) also
      // sidesteps `flutter test`'s incremental-compiler cache — a
      // compile-time constant baked into a cached kernel from an earlier
      // run (with a different or no dart-define) is not recompiled just
      // because a later invocation passes a different `--dart-define`.
      final sinkEndpoint = Platform.environment['OTLP_SINK'] ?? '';
      if (sinkEndpoint.isEmpty) {
        markTestSkipped('OTLP_SINK not set');
        return;
      }

      await HttpOverrides.runWithHttpOverrides(() async {
        final config = AppConfig(
          productKey: 'penguinm',
          appVersion: '0.1.0',
          environment: PenguinEnvironment.prealpha,
          apiBaseUrl: Uri.parse('http://10.0.2.2:5000'),
          licenseServerUrl: 'https://license.penguintech.io',
        );
        final manifest = _buildTestManifest(config);
        final exporter = OtlpHttpJsonExporter(
          endpoint: Uri.parse(sinkEndpoint),
          serviceName: config.productKey,
          serviceVersion: config.appVersion,
        );

        // ShellServices is the sanctioned seam for the platform-/
        // network-bound collaborators Bootstrap.run otherwise manages
        // itself (agent-rules.md) — real ConnectivityMonitor/FlagCache
        // hang under flutter_test, so those are faked; the exporter stays
        // real since proving real OTLP emission is this test's entire
        // purpose.
        final result = await Bootstrap.run(
          manifest,
          services: ShellServices(
            telemetryExporter: exporter,
            connectivityMonitor: FakeConnectivityMonitor(),
            flagCache: InMemoryFlagCache(),
            authBackend: FakeAuthBackend(),
          ),
        );

        final container = ProviderContainer(overrides: result.overrides);
        addTearDown(container.dispose);

        final telemetry = container.read(telemetryProvider);
        final logger = container.read(loggerProvider);
        final metrics = container.read(metricsSinkProvider);
        final traces = container.read(traceSinkProvider);

        // Log one message
        logger.info('Telemetry smoke test started');

        // Record one histogram
        metrics.histogram(
          'app.startup.duration',
          result.startupDuration.inMilliseconds,
        );

        // Record one span
        final span = traces.startSpan(
          'telemetry_test',
          attributes: {'test': true},
        );
        span.end();

        // Flush
        await telemetry.flush();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Verify counts via OTLP sink (all four: logs, metrics, histograms,
        // spans)
        final client = OtlpSinkClient(baseUrl: Uri.parse(sinkEndpoint));
        final summary = await client.summary();
        client.close();

        expect(
          summary.logRecords,
          greaterThanOrEqualTo(1),
          reason: 'Must emit at least 1 log record',
        );
        expect(
          summary.metricDataPoints,
          greaterThanOrEqualTo(1),
          reason: 'Must emit at least 1 metric data point',
        );
        expect(
          summary.histograms,
          greaterThanOrEqualTo(1),
          reason: 'Must emit at least 1 histogram metric',
        );
        expect(
          summary.spans,
          greaterThanOrEqualTo(1),
          reason: 'Must emit at least 1 span',
        );
      }, _RealHttp());
    });
  });
}
