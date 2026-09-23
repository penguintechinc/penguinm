import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_auth/penguin_auth.dart' show AuthConfig;
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_offline/penguin_offline.dart';
import 'package:penguin_testing/penguin_testing.dart';
import 'package:penguin_update/penguin_update.dart';

AppConfig _config() => AppConfig(
  productKey: 'product',
  appVersion: '1.0.0',
  environment: PenguinEnvironment.beta,
  apiBaseUrl: Uri.parse('https://api.product.example'),
  licenseServerUrl: 'https://license.penguintech.io',
);

AppManifest _manifest({PenguinEnvironment? environment}) => AppManifest(
  productKey: 'product',
  appName: 'Test App',
  appVersion: '1.0.0',
  config: environment == null
      ? _config()
      : AppConfig(
          productKey: 'product',
          appVersion: '1.0.0',
          environment: environment,
          apiBaseUrl: Uri.parse('https://api.product.example'),
          licenseServerUrl: 'https://license.penguintech.io',
        ),
  auth: const AuthConfig.password(),
  features: const [],
);

SyncQueue _queueWithDeadLetter(
  ScriptedHttpClient http, {
  required int statusCode,
}) {
  final db = OfflineDatabase.inMemory();
  addTearDown(db.close);
  final api = PenguinApiClient(
    config: _config(),
    tokens: FakeTokenProvider(initialToken: 'tok'),
    inner: http,
  );
  final connectivity = FakeConnectivityMonitor();
  return SyncQueue(
    db: db,
    api: api,
    connectivity: connectivity,
    log: ConsoleLogger(),
  );
}

void main() {
  group('AppChrome', () {
    testWidgets(
      'wraps the router outlet with ConnectivityBanner and non-prod ConsoleVersion',
      (tester) async {
        final http = ScriptedHttpClient();
        final queue = _queueWithDeadLetter(http, statusCode: 200);
        addTearDown(queue.dispose);
        final overrides = <Override>[
          connectivityMonitorProvider.overrideWithValue(
            FakeConnectivityMonitor(),
          ),
          syncQueueProvider.overrideWithValue(queue),
          updateStatusProvider.overrideWith(
            (ref) async => const UpdateStatus.upToDate(),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: MaterialApp(
              home: AppChrome(manifest: _manifest(), child: const Text('BODY')),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('BODY'), findsOneWidget);
      },
    );

    testWidgets('omits the console version overlay in prod', (tester) async {
      final http = ScriptedHttpClient();
      final queue = _queueWithDeadLetter(http, statusCode: 200);
      addTearDown(queue.dispose);
      final overrides = <Override>[
        connectivityMonitorProvider.overrideWithValue(
          FakeConnectivityMonitor(),
        ),
        syncQueueProvider.overrideWithValue(queue),
        updateStatusProvider.overrideWith(
          (ref) async => const UpdateStatus.upToDate(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            home: AppChrome(
              manifest: _manifest(environment: PenguinEnvironment.prod),
              child: const Text('BODY'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('BODY'), findsOneWidget);
    });
  });

  group('DeadLetterNotice', () {
    testWidgets(
      'shows the startup backlog count and lets the user dismiss it',
      (tester) async {
        final http = ScriptedHttpClient()
          ..queueResponse(statusCode: 422, body: '{}');
        final queue = _queueWithDeadLetter(http, statusCode: 422);
        addTearDown(queue.dispose);
        await queue.enqueue(
          PendingWrite(
            id: 'w1',
            method: 'POST',
            path: '/x',
            createdAt: DateTime.now(),
          ),
        );
        await queue.drain();
        expect(await queue.deadLetterBacklog(), hasLength(1));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [syncQueueProvider.overrideWithValue(queue)],
            child: const MaterialApp(home: DeadLetterNotice()),
          ),
        );
        await tester.pump();

        expect(find.text("A change couldn't be saved"), findsOneWidget);

        await tester.tap(find.text('Dismiss'));
        await tester.pump();

        expect(find.text("A change couldn't be saved"), findsNothing);
        expect(await queue.deadLetterBacklog(), isEmpty);
      },
    );

    testWidgets('retry moves the write back onto the pending queue', (
      tester,
    ) async {
      final http = ScriptedHttpClient()
        ..queueResponse(statusCode: 422, body: '{}');
      final queue = _queueWithDeadLetter(http, statusCode: 422);
      addTearDown(queue.dispose);
      await queue.enqueue(
        PendingWrite(
          id: 'w1',
          method: 'POST',
          path: '/x',
          createdAt: DateTime.now(),
        ),
      );
      await queue.drain();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncQueueProvider.overrideWithValue(queue)],
          child: const MaterialApp(home: DeadLetterNotice()),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(find.text("A change couldn't be saved"), findsNothing);
      expect(await queue.deadLetterBacklog(), isEmpty);
    });

    testWidgets('a new dead letter arriving via the stream is surfaced live', (
      tester,
    ) async {
      final http = ScriptedHttpClient();
      final queue = _queueWithDeadLetter(http, statusCode: 200);
      addTearDown(queue.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncQueueProvider.overrideWithValue(queue)],
          child: const MaterialApp(home: DeadLetterNotice()),
        ),
      );
      await tester.pump();
      expect(find.text("A change couldn't be saved"), findsNothing);

      http.queueResponse(statusCode: 422, body: '{}');
      await queue.enqueue(
        PendingWrite(
          id: 'w2',
          method: 'POST',
          path: '/y',
          createdAt: DateTime.now(),
        ),
      );
      await queue.drain();
      await tester.pumpAndSettle();

      expect(find.text("A change couldn't be saved"), findsOneWidget);
    });

    testWidgets('renders nothing when the backlog is empty', (tester) async {
      final http = ScriptedHttpClient();
      final queue = _queueWithDeadLetter(http, statusCode: 200);
      addTearDown(queue.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncQueueProvider.overrideWithValue(queue)],
          child: const MaterialApp(home: DeadLetterNotice()),
        ),
      );
      await tester.pump();

      expect(find.text("A change couldn't be saved"), findsNothing);
    });

    testWidgets('shows a pluralized count when more than one write is queued', (
      tester,
    ) async {
      final http = ScriptedHttpClient()
        ..queueResponse(statusCode: 422, body: '{}')
        ..queueResponse(statusCode: 422, body: '{}');
      final queue = _queueWithDeadLetter(http, statusCode: 422);
      addTearDown(queue.dispose);
      await queue.enqueue(
        PendingWrite(
          id: 'w1',
          method: 'POST',
          path: '/x',
          createdAt: DateTime.now(),
        ),
      );
      await queue.enqueue(
        PendingWrite(
          id: 'w2',
          method: 'POST',
          path: '/y',
          createdAt: DateTime.now(),
        ),
      );
      await queue.drain();
      expect(await queue.deadLetterBacklog(), hasLength(2));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [syncQueueProvider.overrideWithValue(queue)],
          child: const MaterialApp(home: DeadLetterNotice()),
        ),
      );
      await tester.pump();

      expect(find.text("2 changes couldn't be saved"), findsOneWidget);
    });
  });
}
