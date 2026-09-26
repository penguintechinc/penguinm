import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_ui/penguin_ui.dart';
import 'package:penguincloud/login_screen.dart';

AppManifest _manifest() => AppManifest(
  productKey: 'penguincloud',
  appName: 'PenguinCloud',
  appVersion: '0.1.0',
  config: AppConfig(
    productKey: 'penguincloud',
    appVersion: '0.1.0',
    environment: PenguinEnvironment.prealpha,
    apiBaseUrl: Uri.parse('https://api.penguincloud.example'),
    licenseServerUrl: 'https://license.penguintech.io',
  ),
  auth: const AuthConfig.password(),
  features: const [],
);

Widget _buildTestWidget() {
  return ProviderScope(
    child: MaterialApp(
      theme: PenguinTheme.dark(),
      home: PenguinCloudLoginScreen(manifest: _manifest()),
    ),
  );
}

void main() {
  group('PenguinCloudLoginScreen', () {
    testWidgets('renders only the login form on phone width', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Sign In'), findsOneWidget);
      // The separate branding pane (icon + tagline) is tablet/expanded
      // only; the form's own BrandingConfig header (just "PenguinCloud")
      // still renders on phone — that one is LoginPageBuilder's, not this
      // widget's pane.
      expect(find.text('Enterprise Springboard'), findsNothing);
    });

    testWidgets('renders the branding pane beside the form on tablet width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      // "PenguinCloud" appears twice: once in LoginPageBuilder's own
      // branding header, once in this widget's separate branding pane.
      expect(find.text('PenguinCloud'), findsNWidgets(2));
      expect(find.text('Enterprise Springboard'), findsOneWidget);
      expect(find.byIcon(Icons.cloud), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });
  });
}
