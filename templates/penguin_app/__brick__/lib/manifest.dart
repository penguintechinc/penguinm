import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_ui/penguin_ui.dart';
import 'features/home/home_module.dart';

/// Builds the app manifest with product config, auth, and features.
AppManifest buildManifest() {
  final config = AppConfig.fromEnvironment(
    productKey: '{{product_key}}',
    appVersion: '0.1.0',
  );

  return AppManifest(
    productKey: '{{product_key}}',
    appName: '{{name}}',
    appVersion: '0.1.0',
    config: config,
    auth: AuthConfig.hosted(
      issuer: config.apiBaseUrl,
      clientId: String.fromEnvironment(
        'OAUTH_CLIENT_ID',
        defaultValue: '{{org}}.{{name}}',
      ),
      redirectUri: String.fromEnvironment(
        'OAUTH_REDIRECT_URI',
        defaultValue: '{{org}}.{{name}}.dev://oauth/callback',
      ),
    ),
    brand: const AppBrand(displayName: '{{display_name}}'),
    features: const [HomeModule()],
  );
}
