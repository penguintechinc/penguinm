import 'package:flutter_test/flutter_test.dart';
import 'package:penguincloud/features/springboard/domain/springboard_item.dart';

void main() {
  group('SpringboardItem.isVisibleTo', () {
    const openItem = SpringboardItem(
      id: 'open',
      title: 'Open',
      icon: SpringboardIcon.dashboard,
      route: '/open',
    );
    const adminOnlyItem = SpringboardItem(
      id: 'admin-only',
      title: 'Admin Only',
      icon: SpringboardIcon.people,
      route: '/admin',
      roles: ['admin'],
    );
    const multiRoleItem = SpringboardItem(
      id: 'multi-role',
      title: 'Multi Role',
      icon: SpringboardIcon.settings,
      route: '/multi',
      roles: ['admin', 'maintainer'],
    );

    test('an item with no configured roles is visible to everyone', () {
      expect(openItem.isVisibleTo([]), isTrue);
      expect(openItem.isVisibleTo(['viewer']), isTrue);
    });

    test('a role-gated item is hidden from a user without a matching role', () {
      expect(adminOnlyItem.isVisibleTo([]), isFalse);
      expect(adminOnlyItem.isVisibleTo(['viewer']), isFalse);
    });

    test('a role-gated item is visible to a user with the matching role', () {
      expect(adminOnlyItem.isVisibleTo(['admin']), isTrue);
    });

    test(
      'a multi-role item is visible when the user holds any one of them',
      () {
        expect(multiRoleItem.isVisibleTo(['maintainer']), isTrue);
        expect(multiRoleItem.isVisibleTo(['admin']), isTrue);
        expect(multiRoleItem.isVisibleTo(['viewer']), isFalse);
      },
    );
  });

  group('springboardItems', () {
    test('has six destinations, matching the legacy default items', () {
      expect(springboardItems, hasLength(6));
      expect(
        springboardItems.map((item) => item.id),
        containsAll(<String>[
          'dashboard',
          'users',
          'teams',
          'settings',
          'monitoring',
          'logs',
        ]),
      );
    });

    test('exactly the admin/maintainer-facing items are role-gated', () {
      final gated = springboardItems.where((item) => item.roles.isNotEmpty);
      expect(
        gated.map((item) => item.id),
        containsAll(<String>['users', 'settings', 'monitoring', 'logs']),
      );
      expect(gated, hasLength(4));
    });
  });
}
