import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';

void main() {
  group('FormTab', () {
    test('applies defaults when only required fields are given', () {
      final id = 'general';
      final label = 'General';
      final tab = FormTab(id: id, label: label);

      expect(tab.id, 'general');
      expect(tab.label, 'General');
      expect(tab.icon, isNull);
      expect(tab.description, isNull);
    });

    test('accepts icon and description', () {
      final id = 'security';
      final label = 'Security';
      final icon = 'lock';
      final description = 'Security-related fields';
      final tab = FormTab(
        id: id,
        label: label,
        icon: icon,
        description: description,
      );

      expect(tab.id, 'security');
      expect(tab.label, 'Security');
      expect(tab.icon, 'lock');
      expect(tab.description, 'Security-related fields');
    });

    test('icon accepts non-string dynamic values', () {
      final id = 'profile';
      final label = 'Profile';
      final icon = 42;
      final tab = FormTab(id: id, label: label, icon: icon);
      expect(tab.icon, 42);
    });
  });
}
