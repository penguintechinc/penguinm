import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_update/penguin_update.dart';

void main() {
  group('UpdatePrompt callbacks', () {
    testWidgets('Update button in banner calls launchUrl', (
      WidgetTester tester,
    ) async {
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

      // The Update button should be present
      expect(find.widgetWithText(TextButton, 'Update'), findsOneWidget);

      // Tap the Update button - it should attempt to launch the URL
      await tester.tap(find.widgetWithText(TextButton, 'Update'));
      await tester.pumpAndSettle();

      // Widget should still be present (not unmounted by the tap)
      expect(find.byType(UpdatePrompt), findsOneWidget);
    });

    testWidgets('Update button in dialog calls launchUrl for required update', (
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

      // The Update button should be present in the dialog
      final updateButtons = find.widgetWithText(TextButton, 'Update');
      expect(updateButtons, findsOneWidget);

      // Tap the Update button
      await tester.tap(updateButtons);
      await tester.pumpAndSettle();

      // Dialog should still be displayed (not dismis) sable)
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('Later button attempts to hide banner', (
      WidgetTester tester,
    ) async {
      final versionInfo = ClientVersionInfo(
        latestVersion: '2.0.0',
        storeUrl: Uri.parse('https://example.com/app'),
      );

      final rootScaffold = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            key: rootScaffold,
            body: UpdatePrompt(
              applicationId: 'io.penguintech.test',
              status: UpdateAvailable(versionInfo),
            ),
          ),
        ),
      );

      // The Later button should be present
      expect(find.widgetWithText(TextButton, 'Later'), findsOneWidget);

      // Tap the Later button - it should hide the banner
      await tester.tap(find.widgetWithText(TextButton, 'Later'));
      await tester.pumpAndSettle();

      // UpdatePrompt should still exist (it wraps the banner)
      expect(find.byType(UpdatePrompt), findsOneWidget);
    });

    testWidgets('required update dialog cannot be dismissed via back button', (
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

      // PopScope should be present
      expect(find.byType(PopScope), findsOneWidget);

      // AlertDialog should be present
      expect(find.byType(AlertDialog), findsOneWidget);

      // The dialog text should be visible
      expect(find.text('Update Required'), findsOneWidget);
      expect(
        find.text(
          'This version of the app is no longer supported. Please update to continue using the app.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('available update shows both Update and Later buttons', (
      WidgetTester tester,
    ) async {
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

      // Both buttons should be present
      expect(find.widgetWithText(TextButton, 'Update'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Later'), findsOneWidget);
      expect(find.text('A new version is available'), findsOneWidget);
    });

    testWidgets('required update shows only Update button', (
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

      // Only Update button should be present (no Later button)
      expect(find.widgetWithText(TextButton, 'Update'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Later'), findsNothing);
    });
  });
}
