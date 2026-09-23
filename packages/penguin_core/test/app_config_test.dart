import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';

AppConfig _config({String productKey = 'gazer', required Uri apiBaseUrl}) {
  return AppConfig(
    productKey: productKey,
    appVersion: '1.0.0',
    environment: PenguinEnvironment.prealpha,
    apiBaseUrl: apiBaseUrl,
    licenseServerUrl: 'https://license.penguintech.io',
  );
}

void main() {
  test('AppConfig.fromEnvironment throws without API_BASE_URL', () {
    expect(
      () => AppConfig.fromEnvironment(productKey: 'gazer', appVersion: '1.0.0'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('AppConfig.fromEnvironment parses OTLP headers k=v,k=v', () {
    final headers = AppConfig.parseOtlpHeaders(
      'x-api-key=abc123,x-tenant=waddlebot',
    );
    expect(headers, {'x-api-key': 'abc123', 'x-tenant': 'waddlebot'});
  });

  test('AppConfig.parseOtlpHeaders returns empty map for empty input', () {
    expect(AppConfig.parseOtlpHeaders(''), <String, String>{});
  });

  test('AppConfig.parseOtlpHeaders ignores malformed pairs', () {
    final headers = AppConfig.parseOtlpHeaders('bad,valid=1,=novalue');
    expect(headers, {'valid': '1'});
  });

  test('isLicenseBypassDomain for penguintech.cloud and <product>.app', () {
    final bypassCloud = _config(
      apiBaseUrl: Uri.parse('https://gazer.penguintech.cloud'),
    );
    final bypassProduct = _config(
      productKey: 'waddles',
      apiBaseUrl: Uri.parse('https://waddles.app'),
    );
    final notBypass = _config(apiBaseUrl: Uri.parse('https://example.com'));

    expect(bypassCloud.isLicenseBypassDomain, isTrue);
    expect(bypassProduct.isLicenseBypassDomain, isTrue);
    expect(notBypass.isLicenseBypassDomain, isFalse);
  });

  test('isLicenseBypassDomain matches penguincloud.io and subdomains', () {
    expect(
      _config(
        apiBaseUrl: Uri.parse('https://penguincloud.io'),
      ).isLicenseBypassDomain,
      isTrue,
    );
    expect(
      _config(
        apiBaseUrl: Uri.parse('https://x.penguincloud.io'),
      ).isLicenseBypassDomain,
      isTrue,
    );
    expect(
      _config(
        apiBaseUrl: Uri.parse('https://evilpenguincloud.io'),
      ).isLicenseBypassDomain,
      isFalse,
    );
    expect(
      _config(
        apiBaseUrl: Uri.parse('https://penguincloud.io.evil.com'),
      ).isLicenseBypassDomain,
      isFalse,
    );
  });

  test('isLicenseBypassDomain rejects domain suffix hijacking', () {
    expect(
      _config(
        productKey: 'test',
        apiBaseUrl: Uri.parse('https://eviltest.app'),
      ).isLicenseBypassDomain,
      isFalse,
    );
    expect(
      _config(
        productKey: 'test',
        apiBaseUrl: Uri.parse('https://test.app.evil.com'),
      ).isLicenseBypassDomain,
      isFalse,
    );
  });

  test('copyWith replaces only given fields', () {
    final base = _config(apiBaseUrl: Uri.parse('https://a.example.com'));
    final updated = base.copyWith(
      apiBaseUrl: Uri.parse('https://b.example.com'),
    );

    expect(updated.apiBaseUrl, Uri.parse('https://b.example.com'));
    expect(updated.productKey, base.productKey);
    expect(updated.environment, base.environment);
  });

  test('copyWith without apiBaseUrl keeps the original value', () {
    final base = _config(apiBaseUrl: Uri.parse('https://a.example.com'));
    final updated = base.copyWith(environment: PenguinEnvironment.beta);

    expect(updated.apiBaseUrl, base.apiBaseUrl);
    expect(updated.environment, PenguinEnvironment.beta);
  });

  test(
    'PenguinEnvironment.parse recognizes known values and falls back on unknown',
    () {
      expect(PenguinEnvironment.parse('beta'), PenguinEnvironment.beta);
      expect(
        PenguinEnvironment.parse('not-a-real-tier'),
        PenguinEnvironment.prealpha,
      );
    },
  );

  test('AppConfig.fromMap requires API_BASE_URL', () {
    expect(
      () => AppConfig.fromMap({}, productKey: 'test', appVersion: '1.0.0'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('AppConfig.fromMap throws on invalid API_BASE_URL', () {
    expect(
      () => AppConfig.fromMap(
        {'API_BASE_URL': 'not a url'},
        productKey: 'test',
        appVersion: '1.0.0',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('AppConfig.fromMap parses all fields correctly', () {
    final env = <String, String>{
      'API_BASE_URL': 'https://api.example.com',
      'PENGUIN_ENV': 'beta',
      'OTEL_EXPORTER_OTLP_ENDPOINT': 'https://telemetry.example.com',
      'OTEL_EXPORTER_OTLP_PROTOCOL': 'http/protobuf',
      'OTEL_EXPORTER_OTLP_HEADERS': 'x-api-key=secret123,x-tenant=test',
      'POSTHOG_HOST': 'posthog.example.com',
      'POSTHOG_PROJECT_KEY': 'ph-key-123',
      'LICENSE_SERVER_URL': 'https://license.custom.io',
    };

    final config = AppConfig.fromMap(
      env,
      productKey: 'myapp',
      appVersion: '2.1.0',
    );

    expect(config.productKey, 'myapp');
    expect(config.appVersion, '2.1.0');
    expect(config.environment, PenguinEnvironment.beta);
    expect(config.apiBaseUrl, Uri.parse('https://api.example.com'));
    expect(config.otlpEndpoint, Uri.parse('https://telemetry.example.com'));
    expect(config.otlpProtocol, 'http/protobuf');
    expect(config.otlpHeaders, {'x-api-key': 'secret123', 'x-tenant': 'test'});
    expect(config.posthogHost, 'posthog.example.com');
    expect(config.posthogProjectKey, 'ph-key-123');
    expect(config.licenseServerUrl, 'https://license.custom.io');
  });

  test('AppConfig.fromMap uses defaults for optional fields', () {
    final env = <String, String>{'API_BASE_URL': 'https://api.example.com'};

    final config = AppConfig.fromMap(
      env,
      productKey: 'test',
      appVersion: '1.0.0',
    );

    expect(config.environment, PenguinEnvironment.prealpha);
    expect(config.otlpEndpoint, isNull);
    expect(config.otlpProtocol, 'http/json');
    expect(config.otlpHeaders, isEmpty);
    expect(config.posthogHost, isNull);
    expect(config.posthogProjectKey, isNull);
    expect(config.licenseServerUrl, 'https://license.penguintech.io');
  });

  test('AppConfig.fromMap collapses empty optional strings to null', () {
    final env = <String, String>{
      'API_BASE_URL': 'https://api.example.com',
      'POSTHOG_HOST': '',
      'POSTHOG_PROJECT_KEY': '',
    };

    final config = AppConfig.fromMap(
      env,
      productKey: 'test',
      appVersion: '1.0.0',
    );

    expect(config.posthogHost, isNull);
    expect(config.posthogProjectKey, isNull);
  });

  test('AppConfig.fromMap skips invalid OTEL endpoint gracefully', () {
    // Empty OTLP endpoint is acceptable and results in null
    final env = <String, String>{
      'API_BASE_URL': 'https://api.example.com',
      'OTEL_EXPORTER_OTLP_ENDPOINT': '',
    };

    final config = AppConfig.fromMap(
      env,
      productKey: 'test',
      appVersion: '1.0.0',
    );

    expect(config.otlpEndpoint, isNull);
  });
}
