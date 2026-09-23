import 'package:flutter_test/flutter_test.dart';
import 'package:penguincloud/features/profile/domain/user.dart';

void main() {
  group('User.fromJson / toJson', () {
    test('decodes every field from a full profile payload', () {
      final user = User.fromJson(const {
        'id': 'user-1',
        'email': 'penny@example.com',
        'name': 'Penny Waddle',
        'roles': ['admin', 'viewer'],
      });

      expect(user.id, 'user-1');
      expect(user.email, 'penny@example.com');
      expect(user.name, 'Penny Waddle');
      expect(user.roles, ['admin', 'viewer']);
    });

    test('name and roles default sensibly when absent', () {
      final user = User.fromJson(const {
        'id': 'user-2',
        'email': 'gus@example.com',
      });

      expect(user.name, isNull);
      expect(user.roles, isEmpty);
    });

    test('toJson round-trips through fromJson', () {
      const user = User(
        id: 'user-3',
        email: 'chilly@example.com',
        name: 'Chilly Bergman',
        roles: ['maintainer'],
      );

      final decoded = User.fromJson(user.toJson());

      expect(decoded.id, user.id);
      expect(decoded.email, user.email);
      expect(decoded.name, user.name);
      expect(decoded.roles, user.roles);
    });

    test('toJson omits name when null', () {
      const user = User(id: 'user-4', email: 'skipper@example.com');
      expect(user.toJson().containsKey('name'), isFalse);
    });
  });

  group('User role helpers', () {
    test('hasRole checks membership', () {
      const user = User(
        id: 'u',
        email: 'e@example.com',
        roles: ['admin', 'viewer'],
      );
      expect(user.hasRole('admin'), isTrue);
      expect(user.hasRole('maintainer'), isFalse);
    });

    test('isAdmin is true only when the admin role is present', () {
      const admin = User(id: 'u1', email: 'e1@example.com', roles: ['admin']);
      const viewer = User(id: 'u2', email: 'e2@example.com', roles: ['viewer']);
      expect(admin.isAdmin, isTrue);
      expect(viewer.isAdmin, isFalse);
    });
  });
}
