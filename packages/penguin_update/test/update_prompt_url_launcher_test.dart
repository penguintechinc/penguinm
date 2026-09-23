import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_update/penguin_update.dart';

void main() {
  group('UpdatePrompt store URL handling', () {
    test('storeUrlFor uses market:// when storeUrl is null', () {
      final versionInfo = ClientVersionInfo(
        latestVersion: '2.0.0',
        minimumVersion: '1.0.0',
        storeUrl: null,
      );

      final storeUrl = storeUrlFor('io.penguintech.test', versionInfo);
      expect(storeUrl.scheme, equals('market'));
      expect(storeUrl.toString(), contains('io.penguintech.test'));
    });

    test('storeUrlFor uses provided storeUrl when available', () {
      final expectedUrl = Uri.parse(
        'https://play.google.com/store/apps/details?id=io.penguintech.test',
      );
      final versionInfo = ClientVersionInfo(
        latestVersion: '2.0.0',
        minimumVersion: '1.0.0',
        storeUrl: expectedUrl,
      );

      final storeUrl = storeUrlFor('io.penguintech.test', versionInfo);
      expect(storeUrl, equals(expectedUrl));
    });

    testWidgets('displays Update button for available updates', (
      WidgetTester tester,
    ) async {
      final versionInfo = ClientVersionInfo(
        latestVersion: '2.0.0',
        minimumVersion: '1.0.0',
        storeUrl: Uri.parse('https://example.com/app'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdatePrompt(
              applicationId: 'io.penguintech.test',
              status: UpdateAvailable(versionInfo),
            ),
          ),
        ),
      );

      expect(find.text('Update'), findsWidgets);
      expect(find.text('Later'), findsWidgets);
    });

    testWidgets('displays non-dismissible dialog for required updates', (
      WidgetTester tester,
    ) async {
      final versionInfo = ClientVersionInfo(
        latestVersion: '2.0.0',
        minimumVersion: '2.0.0',
        storeUrl: Uri.parse('https://example.com/app'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdatePrompt(
              applicationId: 'io.penguintech.test',
              status: UpdateRequired(versionInfo),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // PopScope should prevent back navigation
      expect(find.byType(PopScope), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Update Required'), findsOneWidget);
    });

    testWidgets('Update button can be tapped', (WidgetTester tester) async {
      final versionInfo = ClientVersionInfo(
        latestVersion: '2.0.0',
        storeUrl: Uri.parse('https://example.com/app'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdatePrompt(
              applicationId: 'io.penguintech.test',
              status: UpdateAvailable(versionInfo),
            ),
          ),
        ),
      );

      // Find and tap the Update button - should not throw
      final updateButton = find.widgetWithText(TextButton, 'Update');
      expect(updateButton, findsOneWidget);
      await tester.tap(updateButton);
      await tester.pumpAndSettle();
    });
  });
}
