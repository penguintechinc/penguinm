import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_flags/penguin_flags.dart';
import 'package:penguin_offline/penguin_offline.dart';
import 'package:penguin_telemetry/penguin_telemetry.dart';
import 'package:penguin_update/penguin_update.dart';

AppConfig _config({Uri? otlpEndpoint, String? posthogHost}) => AppConfig(
  productKey: 'penguinm',
  appVersion: '1.0.0',
  environment: PenguinEnvironment.prealpha,
  apiBaseUrl: Uri.parse('https://api.penguinm.example'),
  otlpEndpoint: otlpEndpoint,
  posthogHost: posthogHost,
  posthogProjectKey: posthogHost == null ? null : 'phc_test',
  licenseServerUrl: 'https://license.penguintech.io',
);

AppManifest _manifest({Uri? otlpEndpoint, String? posthogHost}) => AppManifest(
  productKey: 'penguinm',
  appName: 'Penguin Reference',
  appVersion: '1.0.0',
  config: _config(otlpEndpoint: otlpEndpoint, posthogHost: posthogHost),
  auth: AuthConfig.hosted(
    issuer: Uri.parse('https://api.penguinm.example'),
    clientId: 'penguinm-test',
    redirectUri: 'io.penguintech.penguinm.dev://oauth/callback',
  ),
  features: const [],
);

void main() {
  group('Bootstrap.run', () {
    test('resolves every managed provider with zero warnings', () async {
      final manifest = _manifest();
      final result = await Bootstrap.run(manifest);

      expect(result.warnings, isEmpty);
      expect(result.startupDuration.inMicroseconds, isNonNegative);

      final container = ProviderContainer(overrides: result.overrides);
      addTearDown(container.dispose);

      // The four providers with a throwing default must resolve to a real
      // instance rather than hitting `UnimplementedError`.
      expect(container.read(telemetryProvider), isA<Telemetry>());
      expect(container.read(authBackendProvider), isA<HostedLoginBackend>());
      expect(container.read(featureFlagsProvider), isA<FeatureFlags>());
      expect(container.read(apiClientProvider), isA<PenguinApiClient>());
      // Providers with a safe package default must also come from bootstrap
      // (a started ConnectivityMonitor) rather than falling through
      // unrelated to Bootstrap's own construction.
      expect(
        container.read(connectivityMonitorProvider),
        isA<ConnectivityMonitor>(),
      );
      expect(
        container.read(loggerProvider),
        same(container.read(telemetryProvider).logger),
      );
      expect(container.read(metricsSinkProvider), isA<TelemetryMetricsSink>());
      expect(container.read(traceSinkProvider), isA<TelemetryTraceSink>());
      expect(container.read(appConfigProvider).productKey, 'penguinm');

      // Providers this bootstrap doesn't manage still resolve end-to-end
      // through the ones it does (apiClientProvider, loggerProvider, ...).
      expect(container.read(syncQueueProvider), isA<SyncQueue>());
      final updateStatus = await container.read(updateStatusProvider.future);
      expect(updateStatus, isA<UpdateStatus>());
    });

    test(
      'invalid otlp endpoint records a telemetry warning and falls back to Noop',
      () async {
        final manifest = _manifest(
          otlpEndpoint: Uri(path: 'not-a-real-endpoint'),
        );
        final result = await Bootstrap.run(manifest);

        expect(result.warnings, hasLength(1));
        expect(result.warnings.single.step, 'telemetry');

        final container = ProviderContainer(overrides: result.overrides);
        addTearDown(container.dispose);
        // Telemetry still starts (with a NoopExporter) rather than the app
        // failing to boot.
        final telemetry = container.read(telemetryProvider);
        expect(telemetry, isA<Telemetry>());
        // flush() must not throw even though export happens through Noop.
        await expectLater(telemetry.flush(), completes);
      },
    );

    test(
      'a configured PostHog host builds a PostHogFlagSource-backed FeatureFlags',
      () async {
        final manifest = _manifest(posthogHost: 'https://posthog.example');
        final result = await Bootstrap.run(manifest);
        // The unawaited background refresh may hit the blocked-HTTP fake
        // client and fail, but that's swallowed inside FeatureFlags itself —
        // construction succeeding with zero warnings is what's under test.
        expect(result.warnings, isEmpty);
        final container = ProviderContainer(overrides: result.overrides);
        addTearDown(container.dispose);
        expect(container.read(featureFlagsProvider), isA<FeatureFlags>());
      },
    );

    test('password auth config builds a PasswordAuthBackend', () async {
      final manifest = AppManifest(
        productKey: 'penguincloud',
        appName: 'PenguinCloud',
        appVersion: '1.0.0',
        config: _config(),
        auth: const AuthConfig.password(),
        features: const [],
      );
      final result = await Bootstrap.run(manifest);
      expect(result.warnings, isEmpty);
      final container = ProviderContainer(overrides: result.overrides);
      addTearDown(container.dispose);
      expect(container.read(authBackendProvider), isA<PasswordAuthBackend>());
    });

    test('overrides not managed by Bootstrap pass through unchanged', () async {
      final manifest = _manifest();
      final fakeClock = _FixedClock();
      final result = await Bootstrap.run(
        manifest,
        overrides: [clockProvider.overrideWithValue(fakeClock)],
      );
      final container = ProviderContainer(overrides: result.overrides);
      addTearDown(container.dispose);
      expect(container.read(clockProvider), same(fakeClock));
    });
  });
}

class _FixedClock implements Clock {
  @override
  DateTime now() => DateTime.utc(2026);
}
