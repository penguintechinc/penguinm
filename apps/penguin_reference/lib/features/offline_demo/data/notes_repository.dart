import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_offline/penguin_offline.dart';

import '../domain/note.dart';

/// Collection name this feature stores its notes under in [OfflineStore]
/// and uses as the API path segment for [SyncQueue] writes.
const String offlineDemoNotesCollection = 'offline_demo_notes';

/// Bridges the offline_demo feature to [OfflineStore] (cached reads) and
/// [SyncQueue] (durable writes) — the only place in this feature that
/// calls either, per spec §5's per-feature `data/` layer rule.
class NotesRepository {
  /// Creates a repository reading/writing through [store] and enqueueing
  /// writes through [syncQueue]; [clock] stamps new notes so tests can
  /// inject deterministic times.
  NotesRepository({
    required this.store,
    required this.syncQueue,
    this.clock = const SystemClock(),
  });

  /// Offline read cache for this feature's notes.
  final OfflineStore store;

  /// Durable write queue notes are enqueued to; replayed automatically
  /// once connectivity returns.
  final SyncQueue syncQueue;

  /// Source of "now" for new notes' [Note.fetchedAt] and id generation.
  final Clock clock;

  int _sequence = 0;

  /// Returns every cached note, most recently written first.
  Future<List<Note>> loadNotes() async {
    final entries = await store.list(offlineDemoNotesCollection);
    final notes = [for (final entry in entries) _toNote(entry)];
    notes.sort((a, b) => b.fetchedAt.compareTo(a.fetchedAt));
    return notes;
  }

  /// Validates [text], writes it to the offline cache immediately (so it's
  /// visible right away whether online or offline), then enqueues a
  /// durable `POST` write that [SyncQueue] replays against the server —
  /// automatically once connectivity returns, or immediately if already
  /// online. Throws [ArgumentError] when [text] fails [isValidNoteText].
  Future<Note> addNote(String text) async {
    if (!isValidNoteText(text)) {
      throw ArgumentError.value(
        text,
        'text',
        'must be 1-$maxNoteTextLength characters',
      );
    }
    final now = clock.now();
    final id = '${now.microsecondsSinceEpoch}-${_sequence++}';
    final data = <String, Object?>{'id': id, 'text': text.trim()};

    await store.put(offlineDemoNotesCollection, id, data, fetchedAt: now);
    await syncQueue.enqueue(
      PendingWrite(
        id: id,
        method: 'POST',
        path: '/offline-demo/notes',
        body: data,
        createdAt: now,
      ),
    );
    return Note(id: id, text: text.trim(), fetchedAt: now);
  }

  Note _toNote(CachedEntry entry) {
    return Note(
      id: entry.id,
      text: entry.data['text'] as String? ?? '',
      fetchedAt: entry.fetchedAt,
    );
  }
}
