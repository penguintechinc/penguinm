import 'package:penguin_reference/features/offline_demo/domain/note.dart';

/// Fixture notes for offline_demo feature tests — four items, matching
/// spec §5's "≥3 fixture items per feature".
final notes = [
  Note(id: 'note-1', text: 'Buy milk', fetchedAt: DateTime.utc(2026, 1, 1)),
  Note(
    id: 'note-2',
    text: 'Call the vet',
    fetchedAt: DateTime.utc(2026, 1, 2, 12),
  ),
  Note(
    id: 'note-3',
    text: 'Finish the offline demo',
    fetchedAt: DateTime.utc(2026, 1, 3, 18, 30),
  ),
  Note(
    id: 'note-4',
    text: 'Read the penguinm spec',
    fetchedAt: DateTime.utc(2026, 1, 4, 9, 15),
  ),
];
