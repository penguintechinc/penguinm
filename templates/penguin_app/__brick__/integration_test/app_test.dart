import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{name}}/main.dart' as app;

void main() {
  group('{{display_name}} integration tests', () {
    testWidgets('app launches and displays home', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify app is running
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('home screen is accessible', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to home
      expect(find.text('Home'), findsWidgets);
    });
  });
}
