import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_auth/penguin_auth.dart' show AuthConfig;
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_offline/penguin_offline.dart';
import 'package:penguin_testing/penguin_testing.dart';
import 'package:penguin_ui/penguin_ui.dart';
import 'package:penguin_update/penguin_update.dart';

AppConfig _config() => AppConfig(
  productKey: 'product',
  appVersion: '1.0.0',
  environment: PenguinEnvironment.beta,
  apiBaseUrl: Uri.parse('https://api.product.example'),
  licenseServerUrl: 'https://license.penguintech.io',
);

AppManifest _manifest() => AppManifest(
  productKey: 'product',
  appName: 'Test App',
  appVersion: '1.0.0',
  config: _config(),
  auth: const AuthConfig.password(),
  features: const [],
);

SyncQueue _queueWithOneDeadLetter() {
  final db = OfflineDatabase.inMemory();
  final api = PenguinApiClient(
    config: _config(),
    tokens: FakeTokenProvider(initialToken: 'tok'),
    inner: ScriptedHttpClient()..queueResponse(statusCode: 422, body: '{}'),
  );
  final queue = SyncQueue(
    db: db,
    api: api,
    connectivity: FakeConnectivityMonitor(),
    log: ConsoleLogger(),
  );
  return queue;
}

/// Pumps `AppChrome` (offline banner visible, one dead-letter notice, a
/// simple body) at [size] with device-pixel-ratio compensation.
Future<void> _pumpChrome(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final queue = _queueWithOneDeadLetter();
  await queue.enqueue(
    PendingWrite(
      id: 'w1',
      method: 'POST',
      path: '/x',
      createdAt: DateTime.now(),
    ),
  );
  await queue.drain();
  addTearDown(queue.dispose);

  final connectivity = FakeConnectivityMonitor();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        connectivityMonitorProvider.overrideWithValue(connectivity),
        syncQueueProvider.overrideWithValue(queue),
        updateStatusProvider.overrideWith(
          (ref) async => const UpdateStatus.upToDate(),
        ),
      ],
      child: MaterialApp(
        theme: PenguinTheme.dark(),
        // AppChrome wraps the router outlet, which in a real app is
        // always itself a Scaffold (AppShellScaffold/HostedLoginScreen);
        // give it one here too so backgrounds/text styles resolve the
        // same way a real screen would.
        home: AppChrome(
          manifest: _manifest(),
          child: const Scaffold(body: Center(child: Text('HOME'))),
        ),
      ),
    ),
  );
  await tester.pump();

  // ConnectivityBanner reads a StreamProvider wrapping `monitor.status`, a
  // broadcast stream — setStatus before the widget subscribes would be
  // lost, so it must be called (and pumped) only after the first pump.
  connectivity.setStatus(ConnectivityStatus.offline);
  await tester.pumpAndSettle();
}

void main() {
  group('AppChrome goldens', () {
    testWidgets('phone (390x844)', (tester) async {
      await _pumpChrome(tester, const Size(390, 844));
      await expectLater(
        find.byType(AppChrome),
        matchesGoldenFile('chrome_phone.png'),
      );
    });

    testWidgets('tablet (834x1194)', (tester) async {
      await _pumpChrome(tester, const Size(834, 1194));
      await expectLater(
        find.byType(AppChrome),
        matchesGoldenFile('chrome_tablet.png'),
      );
    });
  });
}
