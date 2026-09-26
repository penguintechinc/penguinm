import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_ui/penguin_ui.dart';
import 'features/home/home_module.dart';
import 'features/offline_demo/offline_demo_module.dart';

/// Builds the app manifest with product config, auth, and features.
AppManifest buildManifest() {
  final config = AppConfig.fromEnvironment(
    productKey: 'penguinm',
    appVersion: '0.1.0',
  );

  return AppManifest(
    productKey: 'penguinm',
    appName: 'penguin_reference',
    appVersion: '0.1.0',
    config: config,
    auth: AuthConfig.hosted(
      issuer: config.apiBaseUrl,
      clientId: String.fromEnvironment(
        'OAUTH_CLIENT_ID',
        defaultValue: 'io.penguintech.penguin_reference',
      ),
      redirectUri: String.fromEnvironment(
        'OAUTH_REDIRECT_URI',
        defaultValue: 'io.penguintech.penguin_reference.dev://oauth/callback',
      ),
    ),
    brand: const AppBrand(displayName: 'Penguin Reference'),
    features: const [HomeModule(), OfflineDemoModule()],
    // RASP is enabled for this app so the reference app proves the full
    // shell capability end-to-end; it only actually starts once the
    // `penguinm.rasp` PostHog flag (default OFF) is also on — see
    // docs/RASP.md. minAndroidSdk 24 matches the platform convention's
    // `minSdk = 24` (platform/android/gradle/penguin-android.gradle.kts),
    // itself above freerasp's own floor of 23.
    raspPolicy: const RaspPolicy(enabled: true, minAndroidSdk: 24),
  );
}
