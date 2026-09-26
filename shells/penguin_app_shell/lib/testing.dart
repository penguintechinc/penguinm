/// Test-only entry point: `pumpPenguinApp` pumps a `PenguinApp` under
/// `flutter_test` inside a `ProviderScope` seeded with the caller's
/// [Override]s — typically `penguin_testing` fakes for whichever providers
/// the screen under test needs.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'src/app_manifest.dart';
import 'src/penguin_app.dart';
import 'src/run_penguin_app.dart' show recordStartupDuration;

/// Pumps `PenguinApp(manifest)` in a `ProviderScope` overridden with
/// [overrides] (typically `penguin_testing` fakes: `FakeAuthBackend`,
/// `InMemoryTelemetryExporter`-backed `Telemetry`, `FakeFlagSource`/
/// `FakeLicenseSource`-backed `FeatureFlags`, a `PenguinApiClient` wired to
/// `authControllerProvider`, `FakeConnectivityMonitor`,
/// `FakeUpdateChecker`, ...) — every provider `PenguinApp`'s widget tree
/// reads must be covered by [overrides] or its own package default, since
/// this does not call `Bootstrap.run`. Mirrors `runPenguinApp`'s
/// `app.startup.duration` recording so telemetry assertions behave the
/// same way in tests as in production.
Future<void> pumpPenguinApp(
  WidgetTester tester,
  AppManifest manifest, {
  List<Override> overrides = const [],
}) async {
  final stopwatch = Stopwatch()..start();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: PenguinApp(manifest: manifest),
    ),
  );
  await tester.pump();
  stopwatch.stop();
  recordStartupDuration(overrides, stopwatch.elapsed);
}
