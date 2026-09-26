import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguincloud/features/profile/profile_module.dart';
import 'package:penguincloud/features/springboard/springboard_module.dart';
import 'package:penguincloud/manifest.dart';

AppConfig _config() => AppConfig(
  productKey: 'penguincloud',
  appVersion: appVersion,
  environment: PenguinEnvironment.prealpha,
  apiBaseUrl: Uri.parse('https://api.penguincloud.example'),
  licenseServerUrl: 'https://license.penguintech.io',
);

void main() {
  group('buildManifestFor', () {
    test('sets productKey, appName, appVersion, and applicationId', () {
      final manifest = buildManifestFor(config: _config());

      expect(manifest.productKey, 'penguincloud');
      expect(manifest.appName, 'PenguinCloud');
      expect(manifest.appVersion, appVersion);
      expect(manifest.applicationId, 'io.penguintech.penguincloud');
    });

    test(
      'uses the transitional password auth path with defaults from docs/AUTH.md',
      () {
        final manifest = buildManifestFor(config: _config());

        final auth = manifest.auth;
        expect(auth, isA<PasswordAuthConfig>());
        final password = auth as PasswordAuthConfig;
        expect(password.loginPath, '/api/v1/auth/login');
        expect(password.refreshPath, '/api/v1/auth/refresh');
        expect(password.logoutPath, '/api/v1/auth/logout');
        expect(password.profilePath, '/api/v1/auth/profile');
        expect(password.mfa, isTrue);
      },
    );

    test('contributes exactly the springboard and profile feature modules', () {
      final manifest = buildManifestFor(config: _config());

      expect(manifest.features, hasLength(2));
      expect(manifest.features.whereType<SpringboardModule>(), hasLength(1));
      expect(manifest.features.whereType<ProfileModule>(), hasLength(1));
    });

    test('sets a custom loginBuilder for the tablet branding pane', () {
      final manifest = buildManifestFor(config: _config());
      expect(manifest.loginBuilder, isNotNull);
    });

    test('carries the config it was built from', () {
      final config = _config();
      final manifest = buildManifestFor(config: config);
      expect(manifest.config, same(config));
    });

    test('defaults homeRoute to /home and loginRoute to /login', () {
      final manifest = buildManifestFor(config: _config());
      expect(manifest.homeRoute, '/home');
      expect(manifest.loginRoute, '/login');
    });
  });

  group('buildManifest', () {
    test('is exposed for main.dart, resolving config from the environment', () {
      // Not called here — `AppConfig.fromEnvironment` requires
      // `--dart-define API_BASE_URL=...`, which `flutter test` never
      // passes (see docs/MIGRATION.md); this asserts the production
      // entry point exists with the right shape instead of invoking it.
      expect(buildManifest, isA<Function>());
    });
  });
}
