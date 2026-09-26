import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{name}}/features/home/presentation/home_screen.dart';
import '../../../test/fixtures/greetings.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('displays app bar with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomeScreen())),
      );

      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('displays greetings in list', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: HomeScreen())),
      );

      for (final greeting in greetings.take(2)) {
        expect(find.text(greeting.text), findsWidgets);
      }
    });
  });
}
