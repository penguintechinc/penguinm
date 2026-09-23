import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_telemetry/penguin_telemetry.dart';

import 'app_manifest.dart';
import 'bootstrap.dart';
import 'penguin_app.dart';

/// Bootstraps and runs a penguinm app: resolves telemetry/flags/auth/api
/// via `Bootstrap.run` (every step fail-soft — see `BootstrapWarning`),
/// mounts `PenguinApp` in a `ProviderScope`, and records
/// `app.startup.duration` once the first frame is scheduled. [services]
/// substitutes the platform-/network-bound collaborators `Bootstrap.run`
/// would otherwise construct for real (see `ShellServices`) — e.g. a
/// `FakeConnectivityMonitor` in a test/integration-test context where the
/// real `connectivity_plus` plugin has no working platform channel.
Future<void> runPenguinApp(
  AppManifest manifest, {
  ShellServices services = const ShellServices(),
  List<Override> overrides = const [],
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final stopwatch = Stopwatch()..start();
  final result = await Bootstrap.run(
    manifest,
    services: services,
    overrides: overrides,
  );
  runApp(
    ProviderScope(
      overrides: result.overrides,
      child: PenguinApp(manifest: manifest),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    stopwatch.stop();
    recordStartupDuration(result.overrides, stopwatch.elapsed);
  });
}

/// Records the `app.startup.duration` histogram through the same
/// `MetricsSink` value [overrides] wires into the app's real
/// `ProviderScope` — read via a throwaway probe container rather than the
/// app's own (which `runApp`/`pumpWidget` owns internally and never
/// exposes a handle to). Since `metricsSinkProvider` is overridden with a
/// plain value, the probe returns the exact same `MetricsSink` instance
/// the app itself uses, so this reaches the real exporter. Shared by
/// `runPenguinApp` and `pumpPenguinApp` (`lib/testing.dart`) — the one
/// piece of `runPenguinApp`'s post-mount behavior `pumpPenguinApp` can
/// reuse; the mount step itself (`runApp` vs. `WidgetTester.pumpWidget`)
/// is not shareable, since the two are fundamentally different app
/// lifecycles (real vs. test binding).
void recordStartupDuration(List<Override> overrides, Duration elapsed) {
  final probe = ProviderContainer(overrides: overrides);
  probe
      .read(metricsSinkProvider)
      .histogram(StandardMetrics.appStartupDuration, elapsed.inMilliseconds);
  probe.dispose();
}
