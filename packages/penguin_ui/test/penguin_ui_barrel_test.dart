/// Verifies the penguin_ui barrel exports all public API symbols.
library;

import 'package:flutter/material.dart';
import 'package:penguin_ui/penguin_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('barrel exports AppBrand', () {
    final brand = AppBrand(displayName: 'Test App');
    expect(brand.displayName, 'Test App');
  });

  test('barrel exports PenguinTheme', () {
    final theme = PenguinTheme.dark();
    expect(theme.useMaterial3, isTrue);
  });

  test('barrel exports FormFactor', () {
    expect(FormFactor.phone, isA<FormFactor>());
    expect(FormFactor.tablet, isA<FormFactor>());
    expect(FormFactor.expanded, isA<FormFactor>());
  });

  test('barrel exports NavigationDestinationSpec', () {
    const spec = NavigationDestinationSpec(
      route: '/test',
      label: 'Test',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    );
    expect(spec.route, '/test');
  });

  test('barrel exports ResponsiveScaffold', () {
    expect(ResponsiveScaffold, isA<Type>());
  });

  test('barrel exports AdaptiveLayout', () {
    expect(AdaptiveLayout, isA<Type>());
  });

  test('barrel exports ErrorView', () {
    expect(ErrorView, isA<Type>());
  });

  test('barrel exports LoadingView', () {
    expect(LoadingView, isA<Type>());
  });

  test('barrel exports EmptyView', () {
    expect(EmptyView, isA<Type>());
  });
}
