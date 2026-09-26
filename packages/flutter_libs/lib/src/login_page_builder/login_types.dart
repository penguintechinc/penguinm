import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// HTTP method for login API calls.
enum LoginMethod {
  /// HTTP POST method for login endpoint.
  post,

  /// HTTP PUT method for login endpoint.
  put,
}

/// Whether [url] is an acceptable login endpoint given [isRelease].
///
/// Outside of release builds, any URL is allowed (so local HTTP dev servers
/// work). In release builds, only `https://` is allowed, with an exception
/// for `http://localhost`/`127.0.0.1`. Defaults [isRelease] to the real
/// [kReleaseMode]; exposed as a parameter so this can be unit tested without
/// needing an actual release build.
bool isSecureLoginUrl(String url, {bool isRelease = kReleaseMode}) {
  if (!isRelease) return true;
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.scheme == 'https') return true;
  if (uri.scheme == 'http') {
    return uri.host == 'localhost' || uri.host == '127.0.0.1';
  }
  return false;
}

/// Configuration for the login API endpoint.
///
/// In release builds, [loginUrl] must use `https://` (plain `http://` is
/// only permitted for `localhost`/`127.0.0.1`) — throws [ArgumentError]
/// otherwise, since submitting credentials over an unencrypted channel in
/// production is never acceptable. See [isSecureLoginUrl] for the check.
class LoginApiConfig {
  /// Creates a [LoginApiConfig] with endpoint URL and optional HTTP method and headers.
  LoginApiConfig({
    required this.loginUrl,
    this.method = LoginMethod.post,
    this.headers = const {},
  }) {
    if (!isSecureLoginUrl(loginUrl)) {
      throw ArgumentError.value(
        loginUrl,
        'loginUrl',
        'must use https:// in release builds '
            '(http:// is only allowed for localhost/127.0.0.1)',
      );
    }
  }

  /// The login API endpoint URL.
  final String loginUrl;

  /// The HTTP method for login requests (default POST).
  final LoginMethod method;

  /// Optional custom headers to send with the login request.
  final Map<String, String> headers;
}

/// Payload sent to the login API.
class LoginPayload {
  /// Creates a [LoginPayload] with email, password, and optional auth parameters.
  const LoginPayload({
    required this.email,
    required this.password,
    this.rememberMe = false,
    this.captchaToken,
    this.mfaCode,
    this.rememberDevice = false,
  });

  /// The user's email address.
  final String email;

  /// The user's password.
  final String password;

  /// Whether the user opted to be remembered for future logins.
  final bool rememberMe;

  /// Optional CAPTCHA verification token.
  final String? captchaToken;

  /// Optional MFA verification code.
  final String? mfaCode;

  /// Whether the user opted to skip MFA on this device for future logins.
  /// Only meaningful (and only sent) alongside [mfaCode].
  final bool rememberDevice;

  /// Converts this payload to a JSON-serializable map.
  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    if (rememberMe) 'rememberMe': true,
    if (captchaToken != null) 'captchaToken': captchaToken,
    if (mfaCode != null) 'mfaCode': mfaCode,
    if (mfaCode != null && rememberDevice) 'rememberDevice': true,
  };
}

/// User info returned from a successful login.
class LoginUser {
  /// Creates a [LoginUser] with identity and role information.
  const LoginUser({
    required this.id,
    required this.email,
    this.name,
    this.roles = const [],
  });

  /// Creates a [LoginUser] from a JSON response.
  factory LoginUser.fromJson(Map<String, dynamic> json) => LoginUser(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String?,
    roles:
        (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList() ??
        const [],
  );

  /// The user's unique identifier.
  final String id;

  /// The user's email address.
  final String email;

  /// The user's display name (optional).
  final String? name;

  /// The user's assigned roles.
  final List<String> roles;
}

/// Response from the login API.
class LoginResponse {
  /// Creates a [LoginResponse] with login result and optional tokens.
  const LoginResponse({
    required this.success,
    this.user,
    this.token,
    this.refreshToken,
    this.mfaRequired = false,
    this.error,
    this.errorCode,
  });

  /// Creates a [LoginResponse] from a JSON response.
  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    success: json['success'] as bool,
    user: json['user'] != null
        ? LoginUser.fromJson(json['user'] as Map<String, dynamic>)
        : null,
    token: json['token'] as String?,
    refreshToken: json['refreshToken'] as String?,
    mfaRequired: json['mfaRequired'] as bool? ?? false,
    error: json['error'] as String?,
    errorCode: json['errorCode'] as String?,
  );

  /// Whether the login attempt succeeded.
  final bool success;

  /// The authenticated user (only present on success).
  final LoginUser? user;

  /// The access token (only present on success).
  final String? token;

  /// The refresh token for obtaining new access tokens.
  final String? refreshToken;

  /// Whether MFA is required to complete authentication.
  final bool mfaRequired;

  /// Error message describing the failure.
  final String? error;

  /// Machine-readable error code.
  final String? errorCode;
}

/// Branding configuration for the login page.
class BrandingConfig {
  /// Creates a [BrandingConfig] with app name and optional logo/tagline.
  const BrandingConfig({
    required this.appName,
    this.logo,
    this.logoHeight = 300,
    this.tagline,
    this.githubRepo,
  });

  /// The application name displayed on the login page.
  final String appName;

  /// Optional logo widget to display instead of the app name.
  final Widget? logo;

  /// Logo height in logical pixels (default 300). Width scales automatically.
  /// Shrinks responsively on smaller screens.
  final double logoHeight;

  /// Optional tagline text displayed below the app name.
  final String? tagline;

  /// Optional GitHub repository URL shown in the footer.
  final String? githubRepo;
}

/// CAPTCHA configuration.
class CaptchaConfig {
  /// Creates a [CaptchaConfig] with CAPTCHA endpoint and thresholds.
  const CaptchaConfig({
    required this.enabled,
    this.provider = CaptchaProvider.altcha,
    this.failedAttemptsThreshold = 3,
    required this.challengeUrl,
    this.resetTimeoutMs = 900000,
  });

  /// Whether CAPTCHA verification is enabled.
  final bool enabled;

  /// The CAPTCHA provider (default Altcha).
  final CaptchaProvider provider;

  /// Number of failed login attempts before CAPTCHA is shown (default 3).
  final int failedAttemptsThreshold;

  /// The CAPTCHA challenge endpoint URL.
  final String challengeUrl;

  /// Timeout in milliseconds to reset the failed attempts counter (default 15 min).
  final int resetTimeoutMs;
}

/// Supported CAPTCHA providers.
enum CaptchaProvider {
  /// Altcha CAPTCHA provider.
  altcha,
}

/// MFA configuration.
class MFAConfig {
  /// Creates an [MFAConfig] with MFA code length and device memory options.
  const MFAConfig({
    required this.enabled,
    this.codeLength = 6,
    this.allowRememberDevice = true,
  });

  /// Whether MFA is enabled.
  final bool enabled;

  /// Expected MFA code length (default 6 digits).
  final int codeLength;

  /// Whether users can opt to skip MFA on this device in the future.
  final bool allowRememberDevice;
}

/// GDPR/cookie consent configuration.
class GDPRConfig {
  /// Creates a [GDPRConfig] with consent policy URLs and text.
  const GDPRConfig({
    this.enabled = true,
    required this.privacyPolicyUrl,
    this.cookiePolicyUrl,
    this.consentText,
    this.showPreferences = true,
  });

  /// Whether GDPR cookie consent banners are shown.
  final bool enabled;

  /// URL to the privacy policy.
  final String privacyPolicyUrl;

  /// Optional URL to the cookie policy.
  final String? cookiePolicyUrl;

  /// Optional custom consent banner text.
  final String? consentText;

  /// Whether to show a preferences link in the consent banner.
  final bool showPreferences;
}

// --- Social Login Provider Hierarchy ---

/// Base class for all social login providers.
sealed class SocialProvider {
  /// Creates a [SocialProvider] base instance.
  const SocialProvider();
}

/// Built-in OAuth2 provider (Google, GitHub, Microsoft, Apple, Twitch, Discord).
enum BuiltInProviderType {
  /// Google OAuth2 provider.
  google,

  /// GitHub OAuth2 provider.
  github,

  /// Microsoft OAuth2 provider.
  microsoft,

  /// Apple OAuth2 provider.
  apple,

  /// Twitch OAuth2 provider.
  twitch,

  /// Discord OAuth2 provider.
  discord,
}

/// A built-in OAuth2 provider configured with standard endpoints.
class BuiltInOAuth2Provider extends SocialProvider {
  /// Creates a [BuiltInOAuth2Provider] with provider type and OAuth credentials.
  const BuiltInOAuth2Provider({
    required this.provider,
    required this.clientId,
    this.redirectUri,
    this.scopes,
  });

  /// The built-in provider type.
  final BuiltInProviderType provider;

  /// The OAuth2 client ID.
  final String clientId;

  /// Optional OAuth2 redirect URI.
  final String? redirectUri;

  /// Optional list of OAuth2 scopes to request.
  final List<String>? scopes;
}

/// Custom OAuth2 provider with explicit auth URL.
class CustomOAuth2Provider extends SocialProvider {
  /// Creates a [CustomOAuth2Provider] with custom auth URL and branding.
  const CustomOAuth2Provider({
    required this.authUrl,
    required this.clientId,
    required this.label,
    this.redirectUri,
    this.scopes,
    this.icon,
    this.buttonColor,
    this.textColor,
  });

  /// The authorization endpoint URL.
  final String authUrl;

  /// The OAuth2 client ID.
  final String clientId;

  /// The label displayed on the login button.
  final String label;

  /// Optional OAuth2 redirect URI.
  final String? redirectUri;

  /// Optional list of OAuth2 scopes to request.
  final List<String>? scopes;

  /// Optional icon widget for the login button.
  final Widget? icon;

  /// Optional background color for the login button.
  final Color? buttonColor;

  /// Optional text color for the login button.
  final Color? textColor;
}

/// OpenID Connect provider with auto-discovery.
class OIDCProvider extends SocialProvider {
  /// Creates an [OIDCProvider] with issuer URL for auto-discovery.
  const OIDCProvider({
    required this.issuerUrl,
    required this.clientId,
    this.label,
    this.redirectUri,
    this.scopes,
    this.icon,
    this.buttonColor,
    this.textColor,
  });

  /// The OpenID Connect issuer URL for endpoint discovery.
  final String issuerUrl;

  /// The OpenID Connect client ID.
  final String clientId;

  /// Optional label displayed on the login button.
  final String? label;

  /// Optional redirect URI for the callback.
  final String? redirectUri;

  /// Optional list of OpenID Connect scopes to request.
  final List<String>? scopes;

  /// Optional icon widget for the login button.
  final Widget? icon;

  /// Optional background color for the login button.
  final Color? buttonColor;

  /// Optional text color for the login button.
  final Color? textColor;
}

/// SAML provider.
class SAMLProvider extends SocialProvider {
  /// Creates a [SAMLProvider] with IdP configuration.
  const SAMLProvider({
    required this.idpSsoUrl,
    required this.entityId,
    required this.acsUrl,
    this.certificate,
    this.label,
    this.icon,
    this.buttonColor,
    this.textColor,
  });

  /// The IdP single sign-on URL.
  final String idpSsoUrl;

  /// The SAML entity ID (service provider identifier).
  final String entityId;

  /// The assertion consumer service (ACS) URL for the callback.
  final String acsUrl;

  /// Optional IdP certificate for response validation.
  final String? certificate;

  /// Optional label displayed on the login button.
  final String? label;

  /// Optional icon widget for the login button.
  final Widget? icon;

  /// Optional background color for the login button.
  final Color? buttonColor;

  /// Optional text color for the login button.
  final Color? textColor;
}
