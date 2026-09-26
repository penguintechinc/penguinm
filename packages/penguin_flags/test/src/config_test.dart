import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_flags/src/config.dart';

void main() {
  group('FlagsConfig', () {
    test('default refreshInterval is fifteen minutes', () {
      final config = FlagsConfig(
        productKey: 'penguinm',
        licenseServerUrl: Uri.parse('https://license.example.com'),
      );

      expect(config.refreshInterval, const Duration(minutes: 15));
      expect(config.bypassDomain, isFalse);
      expect(config.posthogHost, isNull);
      expect(config.posthogProjectKey, isNull);
    });

    test('fromAppConfig maps every field from AppConfig', () {
      final appConfig = AppConfig(
        productKey: 'penguinm',
        appVersion: '1.0.0',
        environment: PenguinEnvironment.beta,
        apiBaseUrl: Uri.parse('https://api.penguinm.penguintech.cloud'),
        posthogHost: 'https://license.penguintech.io',
        posthogProjectKey: 'proj-key',
        licenseServerUrl: 'https://license.penguintech.io',
      );

      final config = FlagsConfig.fromAppConfig(appConfig);

      expect(config.productKey, 'penguinm');
      expect(config.posthogHost, 'https://license.penguintech.io');
      expect(config.posthogProjectKey, 'proj-key');
      expect(
        config.licenseServerUrl,
        Uri.parse('https://license.penguintech.io'),
      );
      // .penguintech.cloud is a license-bypass domain per AppConfig.
      expect(config.bypassDomain, isTrue);
    });

    test('fromAppConfig reports bypassDomain false off a bypass host', () {
      final appConfig = AppConfig(
        productKey: 'penguinm',
        appVersion: '1.0.0',
        environment: PenguinEnvironment.prod,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        licenseServerUrl: 'https://license.penguintech.io',
      );

      final config = FlagsConfig.fromAppConfig(appConfig);
      expect(config.bypassDomain, isFalse);
    });
  });
}
