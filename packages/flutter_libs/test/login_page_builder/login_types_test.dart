import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';

void main() {
  group('isSecureLoginUrl', () {
    test('allows any scheme outside of release builds', () {
      expect(
        isSecureLoginUrl('http://insecure.example.com', isRelease: false),
        isTrue,
      );
    });

    test('allows https in release builds', () {
      expect(
        isSecureLoginUrl('https://api.example.com/login', isRelease: true),
        isTrue,
      );
    });

    test('rejects plain http in release builds', () {
      expect(
        isSecureLoginUrl('http://api.example.com/login', isRelease: true),
        isFalse,
      );
    });

    test('allows http://localhost in release builds', () {
      expect(
        isSecureLoginUrl('http://localhost:8080/login', isRelease: true),
        isTrue,
      );
    });

    test('allows http://127.0.0.1 in release builds', () {
      expect(
        isSecureLoginUrl('http://127.0.0.1:8080/login', isRelease: true),
        isTrue,
      );
    });

    test('rejects an unparsable URL in release builds', () {
      expect(isSecureLoginUrl('::not a url::', isRelease: true), isFalse);
    });

    test('rejects a non-http(s) scheme in release builds', () {
      expect(
        isSecureLoginUrl('ftp://api.example.com/login', isRelease: true),
        isFalse,
      );
    });
  });

  group('LoginApiConfig', () {
    test('accepts an https loginUrl', () {
      expect(
        () => LoginApiConfig(loginUrl: 'https://api.example.com/login'),
        returnsNormally,
      );
    });

    // Note: LoginApiConfig's constructor gates on the real `kReleaseMode`,
    // which is always false under `flutter test` — so its release-mode
    // rejection path can't be exercised end-to-end here. The gating logic
    // itself is fully covered above via isSecureLoginUrl's `isRelease`
    // parameter, which LoginApiConfig delegates to.
  });

  group('config classes construct at runtime', () {
    // BrandingConfig/CaptchaConfig/MFAConfig/GDPRConfig and every
    // SocialProvider subtype are `const` classes; every usage elsewhere in
    // this suite (and in login_page_builder_test.dart) passes literal
    // values via `const`, which the compiler folds at compile time —
    // lcov never sees the constructor body execute. Runtime-only values
    // (read from a variable, not a literal in a const context) force a
    // genuine, non-const call for each one.
    test('BrandingConfig', () {
      final appName = 'Test App';
      final config = BrandingConfig(appName: appName);
      expect(config.appName, 'Test App');
    });

    test('CaptchaConfig', () {
      final enabled = true;
      final url = 'https://api.example.com/altcha';
      final config = CaptchaConfig(enabled: enabled, challengeUrl: url);
      expect(config.enabled, isTrue);
      expect(config.challengeUrl, url);
    });

    test('MFAConfig', () {
      final enabled = true;
      final config = MFAConfig(enabled: enabled);
      expect(config.enabled, isTrue);
    });

    test('GDPRConfig', () {
      final url = 'https://example.com/privacy';
      final config = GDPRConfig(privacyPolicyUrl: url);
      expect(config.privacyPolicyUrl, url);
    });

    test('BuiltInOAuth2Provider', () {
      final clientId = 'client-1';
      final provider = BuiltInOAuth2Provider(
        provider: BuiltInProviderType.google,
        clientId: clientId,
      );
      expect(provider.clientId, 'client-1');
    });

    test('CustomOAuth2Provider', () {
      final authUrl = 'https://idp.example.com/authorize';
      final provider = CustomOAuth2Provider(
        authUrl: authUrl,
        clientId: 'client-2',
        label: 'Acme SSO',
      );
      expect(provider.authUrl, authUrl);
    });

    test('OIDCProvider', () {
      final issuerUrl = 'https://idp.example.com';
      final provider = OIDCProvider(issuerUrl: issuerUrl, clientId: 'client-3');
      expect(provider.issuerUrl, issuerUrl);
    });

    test('SAMLProvider', () {
      final idpSsoUrl = 'https://idp.example.com/sso';
      final provider = SAMLProvider(
        idpSsoUrl: idpSsoUrl,
        entityId: 'entity-1',
        acsUrl: 'https://sp.example.com/acs',
      );
      expect(provider.idpSsoUrl, idpSsoUrl);
    });
  });

  group('LoginPayload.toJson', () {
    test('omits rememberDevice when there is no mfaCode', () {
      const payload = LoginPayload(
        email: 'user@example.com',
        password: 'secret',
        rememberDevice: true,
      );
      expect(payload.toJson().containsKey('rememberDevice'), isFalse);
    });

    test('includes rememberDevice alongside a mfaCode', () {
      const payload = LoginPayload(
        email: 'user@example.com',
        password: 'secret',
        mfaCode: '123456',
        rememberDevice: true,
      );
      final json = payload.toJson();
      expect(json['mfaCode'], '123456');
      expect(json['rememberDevice'], true);
    });

    test('omits rememberDevice when false even with a mfaCode', () {
      const payload = LoginPayload(
        email: 'user@example.com',
        password: 'secret',
        mfaCode: '123456',
      );
      expect(payload.toJson().containsKey('rememberDevice'), isFalse);
    });
  });
}
