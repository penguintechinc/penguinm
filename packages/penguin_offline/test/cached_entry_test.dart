import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_offline/src/cached_entry.dart';

class _FakeClock implements Clock {
  _FakeClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}

void main() {
  group('CachedEntry', () {
    test('stores collection, id, data, fetchedAt verbatim', () {
      final fetchedAt = DateTime(2026, 9, 14, 12);
      final entry = CachedEntry(
        collection: 'users',
        id: 'user1',
        data: const {'name': 'Alice'},
        fetchedAt: fetchedAt,
      );

      expect(entry.collection, 'users');
      expect(entry.id, 'user1');
      expect(entry.data, {'name': 'Alice'});
      expect(entry.fetchedAt, fetchedAt);
    });

    test('age() reports elapsed time using the injected clock', () {
      final fetchedAt = DateTime(2026, 9, 14, 12);
      final entry = CachedEntry(
        collection: 'users',
        id: 'user1',
        data: const {},
        fetchedAt: fetchedAt,
      );

      final age = entry.age(
        _FakeClock(fetchedAt.add(const Duration(minutes: 5))),
      );
      expect(age, const Duration(minutes: 5));
    });

    test('age() is zero when the clock reads exactly fetchedAt', () {
      final fetchedAt = DateTime(2026, 9, 14, 12);
      final entry = CachedEntry(
        collection: 'users',
        id: 'user1',
        data: const {},
        fetchedAt: fetchedAt,
      );

      expect(entry.age(_FakeClock(fetchedAt)), Duration.zero);
    });
  });
}
