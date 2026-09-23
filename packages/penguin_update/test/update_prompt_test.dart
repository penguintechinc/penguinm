import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_update/penguin_update.dart';

void main() {
  group('UpdatePrompt', () {
    testWidgets('shows MaterialBanner for updateAvailable status', (
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
            body: Center(
              child: UpdatePrompt(
                applicationId: 'io.penguintech.test',
                status: UpdateAvailable(versionInfo),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MaterialBanner), findsOneWidget);
      expect(find.text('Update'), findsWidgets);
      expect(find.text('Later'), findsWidgets);
    });

    testWidgets('shows non-dismissible dialog for updateRequired status', (
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
            body: Center(
              child: UpdatePrompt(
                applicationId: 'io.penguintech.test',
                status: UpdateRequired(versionInfo),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Update'), findsWidgets);
      expect(find.byType(PopScope), findsOneWidget);
    });

    testWidgets('hides prompt for upToDate status', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: UpdatePrompt(
                applicationId: 'io.penguintech.test',
                status: UpToDate(),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MaterialBanner), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('hides prompt for unknown status', (WidgetTester tester) async {
      final failure = NetworkFailure('Connection failed');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: UpdatePrompt(
                applicationId: 'io.penguintech.test',
                status: Unknown(failure),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(MaterialBanner), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
