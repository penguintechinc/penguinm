import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_offline/penguin_offline.dart';
import 'package:penguin_reference/features/offline_demo/presentation/offline_demo_screen.dart';
import 'package:penguin_testing/penguin_testing.dart';

/// [OfflineStore] fake whose [list] always fails, for exercising
/// [OfflineDemoScreen]'s `AsyncError` rendering branch.
class _ThrowingOfflineStore implements OfflineStore {
  @override
  Future<void> put(
    String collection,
    String id,
    Map<String, Object?> data, {
    DateTime? fetchedAt,
  }) => throw UnimplementedError();

  @override
  Future<CachedEntry?> get(String collection, String id) =>
      throw UnimplementedError();

  @override
  Future<List<CachedEntry>> list(String collection) async {
    throw StateError('offline store unavailable');
  }

  @override
  Future<void> remove(String collection, String id) =>
      throw UnimplementedError();

  @override
  Future<void> clear(String collection) => throw UnimplementedError();
}

void main() {
  late OfflineDatabase db;
  late InMemoryOfflineStore store;
  late ScriptedHttpClient httpClient;
  late FakeConnectivityMonitor connectivity;
  late SyncQueue syncQueue;
  late FakeClock clock;

  setUp(() {
    db = OfflineDatabase.inMemory();
    store = InMemoryOfflineStore();
    httpClient = ScriptedHttpClient();
    clock = FakeClock(DateTime.utc(2026, 1, 1));
    connectivity = FakeConnectivityMonitor();
    final apiClient = PenguinApiClient(
      config: AppConfig(
        productKey: 'penguinm',
        appVersion: '0.1.0',
        environment: PenguinEnvironment.prealpha,
        apiBaseUrl: Uri.parse('https://api.example.test'),
        licenseServerUrl: 'https://license.penguintech.io',
      ),
      tokens: FakeTokenProvider(initialToken: 'test-token'),
      inner: httpClient,
    );
    syncQueue = SyncQueue(
      db: db,
      api: apiClient,
      connectivity: connectivity,
      log: ConsoleLogger(),
    );
  });

  tearDown(() async {
    await syncQueue.dispose();
    db.close();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          offlineStoreProvider.overrideWithValue(store),
          syncQueueProvider.overrideWithValue(syncQueue),
          clockProvider.overrideWithValue(clock),
        ],
        child: const MaterialApp(home: OfflineDemoScreen()),
      ),
    );
    // Lets the async NotesController.build() future resolve without
    // pumpAndSettle (a focused TextField's blinking caret never settles).
    await tester.pump();
    await tester.pump();
  }

  group('OfflineDemoScreen', () {
    testWidgets('shows an empty state when no notes are cached', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.text('No notes yet'), findsOneWidget);
    });

    testWidgets('adding a note shows it with a StaleDataChip', (tester) async {
      httpClient.queueResponse(statusCode: 200, body: '{}');
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'Buy milk');
      await tester.tap(find.widgetWithText(FilledButton, 'Add note'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Buy milk'), findsOneWidget);
      expect(find.byType(StaleDataChip), findsOneWidget);
    });

    testWidgets('submitting via the keyboard action adds a note', (
      tester,
    ) async {
      httpClient.queueResponse(statusCode: 200, body: '{}');
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'Walk the dog');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();

      expect(find.text('Walk the dog'), findsOneWidget);
    });

    testWidgets('shows an error message when notes fail to load', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            offlineStoreProvider.overrideWithValue(_ThrowingOfflineStore()),
            syncQueueProvider.overrideWithValue(syncQueue),
            clockProvider.overrideWithValue(clock),
          ],
          child: const MaterialApp(home: OfflineDemoScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Failed to load notes'), findsOneWidget);
    });

    testWidgets('does not enqueue blank text', (tester) async {
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.widgetWithText(FilledButton, 'Add note'));
      await tester.pump();
      await tester.pump();

      expect(find.text('No notes yet'), findsOneWidget);
    });

    testWidgets('shows a snackbar when a write dead-letters', (tester) async {
      httpClient.queueResponse(statusCode: 422, body: '{"error":"nope"}');
      await pumpScreen(tester);

      await tester.enterText(find.byType(TextField), 'Bad note');
      await tester.tap(find.widgetWithText(FilledButton, 'Add note'));
      await tester.pump();
      await tester.pump();

      await syncQueue.drain();
      await tester.pump();
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining("couldn't be synced"), findsOneWidget);
    });
  });
}
