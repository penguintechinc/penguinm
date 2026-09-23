import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_offline/penguin_offline.dart';
import 'package:penguin_reference/features/offline_demo/data/notes_repository.dart';
import 'package:penguin_testing/penguin_testing.dart';

void main() {
  late OfflineDatabase db;
  late InMemoryOfflineStore store;
  late ScriptedHttpClient httpClient;
  late FakeConnectivityMonitor connectivity;
  late SyncQueue syncQueue;
  late FakeClock clock;
  late NotesRepository repository;

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
    repository = NotesRepository(
      store: store,
      syncQueue: syncQueue,
      clock: clock,
    );
  });

  tearDown(() async {
    await syncQueue.dispose();
    db.close();
  });

  group('NotesRepository.loadNotes', () {
    test('returns an empty list when nothing is cached', () async {
      expect(await repository.loadNotes(), isEmpty);
    });

    test('returns cached notes newest-first', () async {
      httpClient
        ..queueResponse(statusCode: 200, body: '{}')
        ..queueResponse(statusCode: 200, body: '{}');
      clock.set(DateTime.utc(2026, 1, 1));
      await repository.addNote('first');
      clock.set(DateTime.utc(2026, 1, 2));
      await repository.addNote('second');

      final notes = await repository.loadNotes();
      expect(notes, hasLength(2));
      expect(notes.first.text, 'second');
      expect(notes.last.text, 'first');
    });
  });

  group('NotesRepository.addNote', () {
    test('rejects blank text without touching the cache or queue', () async {
      expect(() => repository.addNote('   '), throwsArgumentError);
      expect(await repository.loadNotes(), isEmpty);
    });

    test('writes the note to the offline cache immediately', () async {
      httpClient.queueResponse(statusCode: 200, body: '{}');
      final note = await repository.addNote('Buy milk');

      expect(note.text, 'Buy milk');
      final cached = await store.get(offlineDemoNotesCollection, note.id);
      expect(cached, isNotNull);
      expect(cached!.data['text'], 'Buy milk');
    });

    test('enqueues a durable write that SyncQueue sends on drain', () async {
      httpClient.queueResponse(statusCode: 200, body: '{}');
      final note = await repository.addNote('Call the vet');

      final report = await syncQueue.drain();

      expect(report.sent, 1);
      expect(httpClient.seenRequests, hasLength(1));
      final sent = httpClient.seenRequests.single;
      expect(sent.method, 'POST');
      expect(sent.url.path, '/offline-demo/notes');
      expect(sent.body, contains(note.id));
    });

    test('a non-retriable server error dead-letters the write instead of '
        'silently dropping it', () async {
      httpClient.queueResponse(statusCode: 422, body: '{"error":"nope"}');
      final deadLetterFuture = syncQueue.deadLetters.first;
      final note = await repository.addNote('Bad note');

      final report = await syncQueue.drain();

      expect(report.deadLettered, 1);
      final deadLetter = await deadLetterFuture;
      expect(deadLetter.id, note.id);
      expect(deadLetter.path, '/offline-demo/notes');
    });
  });
}
