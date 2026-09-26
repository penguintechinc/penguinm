import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_offline/penguin_offline.dart';

import '../data/notes_repository.dart';
import '../domain/note.dart';

/// Builds the [NotesRepository] this feature uses, wiring it to the
/// shell's shared [offlineStoreProvider]/[syncQueueProvider]/[clockProvider]
/// so tests only need to override those three (or, more simply, pump
/// through `pumpPenguinApp` with `penguin_testing` fakes).
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepository(
    store: ref.watch(offlineStoreProvider),
    syncQueue: ref.watch(syncQueueProvider),
    clock: ref.watch(clockProvider),
  );
});

/// Every write [SyncQueue] dead-letters, surfaced by [OfflineDemoScreen] as
/// a snackbar — spec §4.7: "surfaced to the user, never silently dropped".
final offlineDemoDeadLettersProvider = StreamProvider<PendingWrite>((ref) {
  return ref.watch(syncQueueProvider).deadLetters;
});

/// Loads and mutates the offline_demo feature's cached [Note] list.
class NotesController extends AsyncNotifier<List<Note>> {
  @override
  Future<List<Note>> build() {
    return ref.watch(notesRepositoryProvider).loadNotes();
  }

  /// Adds [text] as a new note via the repository, then prepends the
  /// freshly-cached note to state rather than re-reading the whole
  /// collection.
  Future<void> addNote(String text) async {
    final repository = ref.read(notesRepositoryProvider);
    final note = await repository.addNote(text);
    final current = state.value ?? const <Note>[];
    state = AsyncData<List<Note>>([note, ...current]);
  }
}

/// Riverpod entry point for [NotesController].
final notesControllerProvider =
    AsyncNotifierProvider<NotesController, List<Note>>(NotesController.new);
