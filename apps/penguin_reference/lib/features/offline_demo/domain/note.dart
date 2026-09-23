/// A single offline-capable note shown by the offline_demo feature: pure
/// data plus [age], with no dependency on Flutter or on how it was
/// persisted (that lives in `data/notes_repository.dart`).
class Note {
  /// Creates a note. [id] is stable across cache writes and sync retries;
  /// [fetchedAt] is when this copy was last written to the local cache.
  const Note({required this.id, required this.text, required this.fetchedAt});

  /// Cache/write identifier, unique within the offline_demo notes
  /// collection.
  final String id;

  /// The note's body text.
  final String text;

  /// When this note was last written to the offline cache.
  final DateTime fetchedAt;

  @override
  String toString() => 'Note(id: $id, text: $text, fetchedAt: $fetchedAt)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          fetchedAt == other.fetchedAt;

  @override
  int get hashCode => Object.hash(id, text, fetchedAt);
}

/// Maximum length accepted for a note's text — matches the "add note" form
/// validation, so the repository never enqueues an oversized write.
const int maxNoteTextLength = 280;

/// True when [text] is non-blank and no longer than [maxNoteTextLength]
/// once surrounding whitespace is trimmed. Pure logic, exercised directly
/// by the "add note" form and by the notes repository as a guard.
bool isValidNoteText(String text) {
  final trimmed = text.trim();
  return trimmed.isNotEmpty && trimmed.length <= maxNoteTextLength;
}
