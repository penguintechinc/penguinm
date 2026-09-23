import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_reference/features/offline_demo/domain/note.dart';

void main() {
  group('Note', () {
    test('equality and hashCode are value-based', () {
      final a = Note(id: '1', text: 'hi', fetchedAt: DateTime.utc(2026));
      final b = Note(id: '1', text: 'hi', fetchedAt: DateTime.utc(2026));
      final c = Note(id: '2', text: 'hi', fetchedAt: DateTime.utc(2026));

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('toString includes id and text', () {
      final note = Note(id: '1', text: 'hi', fetchedAt: DateTime.utc(2026));
      expect(note.toString(), contains('1'));
      expect(note.toString(), contains('hi'));
    });
  });

  group('isValidNoteText', () {
    test('rejects empty text', () {
      expect(isValidNoteText(''), isFalse);
    });

    test('rejects whitespace-only text', () {
      expect(isValidNoteText('   '), isFalse);
    });

    test('accepts trimmed non-empty text', () {
      expect(isValidNoteText('  hello  '), isTrue);
    });

    test('rejects text longer than maxNoteTextLength', () {
      expect(isValidNoteText('a' * (maxNoteTextLength + 1)), isFalse);
    });

    test('accepts text exactly maxNoteTextLength long', () {
      expect(isValidNoteText('a' * maxNoteTextLength), isTrue);
    });
  });
}
