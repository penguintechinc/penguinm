import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_offline/src/pending_write.dart';

void main() {
  group('PendingWrite', () {
    test('stores all constructor fields verbatim', () {
      final now = DateTime(2026, 9, 14, 12);
      final write = PendingWrite(
        id: 'write1',
        method: 'POST',
        path: '/users',
        body: const {'name': 'Alice'},
        idempotencyKey: 'idem-1',
        createdAt: now,
        attempts: 2,
        lastError: 'Connection timeout',
      );

      expect(write.id, 'write1');
      expect(write.method, 'POST');
      expect(write.path, '/users');
      expect(write.body, {'name': 'Alice'});
      expect(write.idempotencyKey, 'idem-1');
      expect(write.createdAt, now);
      expect(write.attempts, 2);
      expect(write.lastError, 'Connection timeout');
    });

    test(
      'attempts defaults to 0 and lastError/body/idempotencyKey default to null',
      () {
        final write = PendingWrite(
          id: 'w1',
          method: 'DELETE',
          path: '/x',
          createdAt: DateTime.now(),
        );

        expect(write.attempts, 0);
        expect(write.lastError, isNull);
        expect(write.body, isNull);
        expect(write.idempotencyKey, isNull);
      },
    );

    test('copyWith overrides only the given fields', () {
      final now = DateTime(2026, 9, 14, 12);
      final original = PendingWrite(
        id: 'w1',
        method: 'POST',
        path: '/x',
        createdAt: now,
      );

      final updated = original.copyWith(
        idempotencyKey: 'k1',
        attempts: 1,
        lastError: 'boom',
      );

      expect(updated.id, 'w1');
      expect(updated.method, 'POST');
      expect(updated.path, '/x');
      expect(updated.createdAt, now);
      expect(updated.idempotencyKey, 'k1');
      expect(updated.attempts, 1);
      expect(updated.lastError, 'boom');
    });

    test('copyWith with no arguments returns equivalent values', () {
      final now = DateTime(2026, 9, 14, 12);
      final original = PendingWrite(
        id: 'w1',
        method: 'PUT',
        path: '/x',
        body: const {'a': 1},
        idempotencyKey: 'k0',
        createdAt: now,
        attempts: 3,
        lastError: 'e',
      );

      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.method, original.method);
      expect(copy.path, original.path);
      expect(copy.body, original.body);
      expect(copy.idempotencyKey, original.idempotencyKey);
      expect(copy.createdAt, original.createdAt);
      expect(copy.attempts, original.attempts);
      expect(copy.lastError, original.lastError);
    });
  });
}
