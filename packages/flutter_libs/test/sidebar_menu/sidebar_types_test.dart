import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';

void main() {
  group('MenuItem', () {
    test('stores required fields with null optional defaults', () {
      const item = MenuItem(name: 'Dashboard', href: '/dashboard');

      expect(item.name, 'Dashboard');
      expect(item.href, '/dashboard');
      expect(item.icon, isNull);
      expect(item.roles, isNull);
    });

    test('stores optional icon and roles when provided', () {
      const item = MenuItem(
        name: 'Settings',
        href: '/settings',
        icon: Icons.settings,
        roles: ['admin', 'owner'],
      );

      expect(item.icon, Icons.settings);
      expect(item.roles, ['admin', 'owner']);
    });

    test('constructing without const runs the constructor at runtime', () {
      // Every other MenuItem/MenuCategory construction in this suite (here
      // and in sidebar_menu_test.dart) is `const`, which is compile-time
      // folded and never executes the constructor body — lcov shows it as
      // uncovered. A runtime-only value (read from a variable, not a
      // literal in a const context) forces a genuine, non-const call.
      final name = 'Settings';
      final href = '/settings';
      final item = MenuItem(name: name, href: href);

      expect(item.name, 'Settings');
      expect(item.href, '/settings');
    });
  });

  group('MenuCategory', () {
    test('defaults collapsible to true and header to null', () {
      const category = MenuCategory(
        items: [MenuItem(name: 'Home', href: '/')],
      );

      expect(category.header, isNull);
      expect(category.collapsible, isTrue);
      expect(category.items, hasLength(1));
    });

    test('stores explicit header and collapsible=false', () {
      const category = MenuCategory(
        header: 'Admin',
        collapsible: false,
        items: [
          MenuItem(name: 'Users', href: '/users'),
          MenuItem(name: 'Roles', href: '/roles'),
        ],
      );

      expect(category.header, 'Admin');
      expect(category.collapsible, isFalse);
      expect(category.items, hasLength(2));
    });

    test('constructing without const runs the constructor at runtime', () {
      final items = [MenuItem(name: 'Home', href: '/')];
      final category = MenuCategory(items: items);

      expect(category.items, hasLength(1));
    });
  });
}
