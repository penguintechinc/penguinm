import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_testing/penguin_testing.dart';
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

void main() {
  testWidgets('PenguinCloudLoginScreen tablet branding pane (834x1194)', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: PenguinTheme.dark(),
          home: PenguinCloudLoginScreen(manifest: _manifest()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await penguinGolden(
      tester,
      find.byType(PenguinCloudLoginScreen),
      'login_tablet',
      size: const Size(834, 1194),
    );
  });
}
