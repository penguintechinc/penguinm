import 'environment.dart';

/// Immutable runtime configuration for a penguinm app: product identity,
/// API/telemetry/license endpoints, and the deployment [PenguinEnvironment].
/// Built once at startup via [AppConfig.fromEnvironment] from
/// `--dart-define` values baked in at build time (see `env/*.json` per
/// app).
class AppConfig {
  /// Creates a config directly; prefer [AppConfig.fromEnvironment] in apps.
  const AppConfig({
    required this.productKey,
    required this.appVersion,
    required this.environment,
    required this.apiBaseUrl,
    this.otlpEndpoint,
    this.otlpProtocol = 'http/json',
    this.otlpHeaders = const {},
    this.posthogHost,
    this.posthogProjectKey,
    required this.licenseServerUrl,
    this.extra = const <String, String>{},
  });

  /// Parses configuration from a map of environment strings; throws
  /// [ArgumentError] when `API_BASE_URL` is missing. All other keys are
  /// optional; empty strings for optional keys collapse to null or default
  /// values.
  factory AppConfig.fromMap(
    Map<String, String> env, {
    required String productKey,
    required String appVersion,
  }) {
    final apiBaseUrlValue = env['API_BASE_URL'] ?? '';
    if (apiBaseUrlValue.isEmpty) {
      throw ArgumentError('API_BASE_URL must be provided');
    }

    final envName = env['PENGUIN_ENV'] ?? 'prealpha';
    final otlpEndpointValue = env['OTEL_EXPORTER_OTLP_ENDPOINT'] ?? '';
    final otlpProtocolValue = env['OTEL_EXPORTER_OTLP_PROTOCOL'] ?? 'http/json';
    final otlpHeadersValue = env['OTEL_EXPORTER_OTLP_HEADERS'] ?? '';
    final posthogHostValue = env['POSTHOG_HOST'] ?? '';
    final posthogProjectKeyValue = env['POSTHOG_PROJECT_KEY'] ?? '';
    final licenseServerUrlValue =
        env['LICENSE_SERVER_URL'] ?? 'https://license.penguintech.io';

    Uri? apiBaseUrl;
    try {
      apiBaseUrl = Uri.parse(apiBaseUrlValue);
      if (!apiBaseUrl.hasScheme || !apiBaseUrl.hasAuthority) {
        throw ArgumentError('API_BASE_URL must be a valid URL');
      }
    } catch (e) {
      throw ArgumentError('Invalid API_BASE_URL: $e');
    }

    Uri? otlpEndpoint;
    if (otlpEndpointValue.isNotEmpty) {
      try {
        otlpEndpoint = Uri.parse(otlpEndpointValue);
      } catch (e) {
        throw ArgumentError('Invalid OTEL_EXPORTER_OTLP_ENDPOINT: $e');
      }
    }

    return AppConfig(
      productKey: productKey,
      appVersion: appVersion,
      environment: PenguinEnvironment.parse(envName),
      apiBaseUrl: apiBaseUrl,
      otlpEndpoint: otlpEndpoint,
      otlpProtocol: otlpProtocolValue,
      otlpHeaders: parseOtlpHeaders(otlpHeadersValue),
      posthogHost: posthogHostValue.isEmpty ? null : posthogHostValue,
      posthogProjectKey: posthogProjectKeyValue.isEmpty
          ? null
          : posthogProjectKeyValue,
      licenseServerUrl: licenseServerUrlValue,
    );
  }

  /// Reads `--dart-define` values baked in at build time: `PENGUIN_ENV`,
  /// `API_BASE_URL`, `OTEL_EXPORTER_OTLP_ENDPOINT`,
  /// `OTEL_EXPORTER_OTLP_PROTOCOL`, `OTEL_EXPORTER_OTLP_HEADERS`
  /// (`k=v,k=v`), `POSTHOG_HOST`, `POSTHOG_PROJECT_KEY`,
  /// `LICENSE_SERVER_URL` (default `https://license.penguintech.io`).
  /// Throws [ArgumentError] when `API_BASE_URL` is missing since every app
  /// needs a backend to talk to.
  factory AppConfig.fromEnvironment({
    required String productKey,
    required String appVersion,
  }) {
    final env = <String, String>{
      'API_BASE_URL': const String.fromEnvironment('API_BASE_URL'),
      'PENGUIN_ENV': const String.fromEnvironment('PENGUIN_ENV'),
      'OTEL_EXPORTER_OTLP_ENDPOINT': const String.fromEnvironment(
        'OTEL_EXPORTER_OTLP_ENDPOINT',
      ),
      'OTEL_EXPORTER_OTLP_PROTOCOL': const String.fromEnvironment(
        'OTEL_EXPORTER_OTLP_PROTOCOL',
      ),
      'OTEL_EXPORTER_OTLP_HEADERS': const String.fromEnvironment(
        'OTEL_EXPORTER_OTLP_HEADERS',
      ),
      'POSTHOG_HOST': const String.fromEnvironment('POSTHOG_HOST'),
      'POSTHOG_PROJECT_KEY': const String.fromEnvironment(
        'POSTHOG_PROJECT_KEY',
      ),
      'LICENSE_SERVER_URL': const String.fromEnvironment('LICENSE_SERVER_URL'),
    };
    return AppConfig.fromMap(
      env,
      productKey: productKey,
      appVersion: appVersion,
    );
  }

  /// The product this app belongs to (`waddlebot`, `elder`, ...); scopes
  /// feature-flag keys and license entitlement lookups.
  final String productKey;

  /// The app's own semantic version, reported to the client-version
  /// endpoint.
  final String appVersion;

  /// Deployment tier this build targets.
  final PenguinEnvironment environment;

  /// Base URL for the product's backend API; user-overridable at runtime
  /// via `AppConfigController` (e.g. Gazer's domain switcher).
  final Uri apiBaseUrl;

  /// OTLP collector endpoint; null disables telemetry export (falls back
  /// to a no-op exporter in `penguin_telemetry`).
  final Uri? otlpEndpoint;

  /// OTLP wire protocol name (`http/json` default).
  final String otlpProtocol;

  /// Extra headers sent with every OTLP export request.
  final Map<String, String> otlpHeaders;

  /// PostHog host for feature flag evaluation, if configured.
  final String? posthogHost;

  /// Public PostHog project write-only key, if configured.
  final String? posthogProjectKey;

  /// License entitlement server base URL.
  final String licenseServerUrl;

  /// Product-specific extension values not covered by the standard fields.
  final Map<String, String> extra;

  /// True when [apiBaseUrl]'s host is a license-bypass domain
  /// (`penguincloud.io`, `penguintech.cloud`, or `<productKey>.app`) —
  /// these builds skip license entitlement checks entirely.
  bool get isLicenseBypassDomain {
    final host = apiBaseUrl.host.toLowerCase();
    return host == 'penguincloud.io' ||
        host.endsWith('.penguincloud.io') ||
        host == 'penguintech.cloud' ||
        host.endsWith('.penguintech.cloud') ||
        host == '$productKey.app' ||
        host.endsWith('.$productKey.app');
  }

  /// Returns a copy with the given fields replaced; used to apply a
  /// runtime API base-URL override without losing the rest of the config.
  AppConfig copyWith({
    Uri? apiBaseUrl,
    PenguinEnvironment? environment,
    Map<String, String>? extra,
  }) {
    return AppConfig(
      productKey: productKey,
      appVersion: appVersion,
      environment: environment ?? this.environment,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      otlpEndpoint: otlpEndpoint,
      otlpProtocol: otlpProtocol,
      otlpHeaders: otlpHeaders,
      posthogHost: posthogHost,
      posthogProjectKey: posthogProjectKey,
      licenseServerUrl: licenseServerUrl,
      extra: extra ?? this.extra,
    );
  }

  /// Parses the `OTEL_EXPORTER_OTLP_HEADERS` `k=v,k=v` format into a
  /// header map; malformed pairs (no `=`, or an empty key) are skipped
  /// rather than throwing, so one bad entry never blocks startup.
  static Map<String, String> parseOtlpHeaders(String raw) {
    if (raw.isEmpty) return const {};
    final headers = <String, String>{};
    for (final pair in raw.split(',')) {
      final idx = pair.indexOf('=');
      if (idx <= 0) continue;
      final key = pair.substring(0, idx).trim();
      final value = pair.substring(idx + 1).trim();
      if (key.isEmpty) continue;
      headers[key] = value;
    }
    return headers;
  }
}
