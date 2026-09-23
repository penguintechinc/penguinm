import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_reference/features/home/presentation/home_screen.dart';
import 'package:penguin_testing/penguin_testing.dart';

void main() {
  group('HomeScreen goldens', () {
    testWidgets('phone form factor', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomeScreen())),
      );

      await penguinGolden(tester, find.byType(HomeScreen), 'home_screen_phone');
    });

    testWidgets('tablet form factor', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomeScreen())),
      );

      await penguinGolden(
        tester,
        find.byType(HomeScreen),
        'home_screen_tablet',
        size: const Size(768, 1024),
      );
    });
  });
}
