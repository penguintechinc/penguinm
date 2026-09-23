/// Verifies the penguin_app_shell barrel exports every public symbol the
/// spec §4.10 API surface requires.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_core/penguin_core.dart';

void main() {
  test('barrel exports the manifest, module, bootstrap, and app types', () {
    // A compile-time reference to each type is the actual assertion here —
    // if the barrel stopped exporting one, this file would fail to compile.
    final config = AppConfig(
      productKey: 'p',
      appVersion: '1.0.0',
      environment: PenguinEnvironment.prealpha,
      apiBaseUrl: Uri.parse('https://api.example.com'),
      licenseServerUrl: 'https://license.penguintech.io',
    );
    expect(config, isA<AppConfig>());
    expect(BootstrapWarning, isNotNull);
    expect(BootstrapResult, isNotNull);
    expect(Bootstrap, isNotNull);
    expect(AppManifest, isNotNull);
    expect(FeatureModule, isNotNull);
    expect(PenguinApp, isNotNull);
    expect(AppChrome, isNotNull);
    expect(DeadLetterNotice, isNotNull);
    expect(HostedLoginScreen, isNotNull);
    expect(SiblingApp, isNotNull);
    expect(SiblingAppLauncher, isNotNull);
    expect(LaunchOutcome.values, isNotEmpty);
    expect(UrlLauncher, isNotNull);
    expect(goRouterProvider, isNotNull);
  });
}
