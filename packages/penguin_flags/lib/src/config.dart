import 'package:penguin_core/penguin_core.dart';

/// Static configuration for a [FeatureFlags] instance: which product's
/// flags to evaluate, where to reach PostHog and the license server, and
/// how often to refresh. Built once at app startup, typically via
/// [FlagsConfig.fromAppConfig].
class FlagsConfig {
  /// Creates flags configuration directly; prefer [FlagsConfig.fromAppConfig]
  /// in apps so values stay derived from the single [AppConfig] source.
  const FlagsConfig({
    required this.productKey,
    this.posthogHost,
    this.posthogProjectKey,
    required this.licenseServerUrl,
    this.refreshInterval = const Duration(minutes: 15),
    this.bypassDomain = false,
  });

  /// The product key (e.g., 'waddlebot', 'penguinm'); every flag key this
  /// instance evaluates must be prefixed with `$productKey.`.
  final String productKey;

  /// PostHog host (e.g., 'https://posthog.example.com'); null disables
  /// PostHog flag evaluation and falls back to cached/default values only.
  final String? posthogHost;

  /// PostHog project key (public, write-only) sent as `api_key` on every
  /// `/decide` request.
  final String? posthogProjectKey;

  /// License entitlement server base URL (e.g.
  /// 'https://license.penguintech.io').
  final Uri licenseServerUrl;

  /// How often background refresh re-fetches flags and tier (default 15
  /// minutes); callers may also trigger [FeatureFlags.refresh] manually.
  final Duration refreshInterval;

  /// True when this deployment is on a license-bypass domain, in which case
  /// [FeatureFlags.tier] always reports enterprise without contacting the
  /// license server.
  final bool bypassDomain;

  /// Builds configuration from the app's single [AppConfig], the standard
  /// path apps use so flags/license values stay derived from one source of
  /// build-time truth rather than being duplicated.
  factory FlagsConfig.fromAppConfig(AppConfig appConfig) {
    return FlagsConfig(
      productKey: appConfig.productKey,
      posthogHost: appConfig.posthogHost,
      posthogProjectKey: appConfig.posthogProjectKey,
      licenseServerUrl: Uri.parse(appConfig.licenseServerUrl),
      bypassDomain: appConfig.isLicenseBypassDomain,
    );
  }
}
