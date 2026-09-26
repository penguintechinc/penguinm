/// Configuration for authentication flow: either hosted browser-based OIDC/SAML
/// or transitional in-app password form.
sealed class AuthConfig {
  /// Default for every app. OIDC/SAML hosted login via authorization code + PKCE
  /// in the system browser. [issuer] is typically the product's API base URL.
  /// Discovery at `<issuer>/.well-known/openid-configuration` when endpoints
  /// are not provided explicitly.
  const factory AuthConfig.hosted({
    required Uri issuer,
    required String clientId,
    required String redirectUri,
    Uri? authorizationEndpoint,
    Uri? tokenEndpoint,
    Uri? endSessionEndpoint,
    List<String>? scopes,
    bool? preferEphemeralSession,
  }) = HostedAuthConfig;

  /// Transitional fallback for backends without hosted mobile login.
  /// Renders flutter_libs `LoginPageBuilder` in-app; every use is documented
  /// in docs/AUTH.md until the backend implements hosted login.
  const factory AuthConfig.password({
    String? loginPath,
    String? refreshPath,
    String? logoutPath,
    String? profilePath,
    bool? mfa,
  }) = PasswordAuthConfig;
}

/// OIDC/SAML hosted login via authorization code + PKCE in system browser.
class HostedAuthConfig implements AuthConfig {
  /// Creates a hosted login configuration.
  const HostedAuthConfig({
    required this.issuer,
    required this.clientId,
    required this.redirectUri,
    this.authorizationEndpoint,
    this.tokenEndpoint,
    this.endSessionEndpoint,
    List<String>? scopes,
    bool? preferEphemeralSession,
  }) : scopes =
           scopes ?? const ['openid', 'profile', 'email', 'offline_access'],
       preferEphemeralSession = preferEphemeralSession ?? false;

  /// Base URL for the OAuth2 issuer; typically the product's API base.
  final Uri issuer;

  /// OAuth2 client ID for this app.
  final String clientId;

  /// Redirect URI where the browser sends the authorization code.
  final String redirectUri;

  /// Authorization endpoint URI, or null to use discovery.
  final Uri? authorizationEndpoint;

  /// Token endpoint URI, or null to use discovery.
  final Uri? tokenEndpoint;

  /// End-session endpoint URI, or null if not available.
  final Uri? endSessionEndpoint;

  /// OAuth2 scopes requested.
  final List<String> scopes;

  /// Whether to prefer ephemeral browser sessions (no long-lived cookies).
  final bool preferEphemeralSession;
}

/// Transitional in-app password login via LoginPageBuilder.
class PasswordAuthConfig implements AuthConfig {
  /// Creates a password login configuration.
  const PasswordAuthConfig({
    String? loginPath,
    String? refreshPath,
    String? logoutPath,
    String? profilePath,
    bool? mfa,
  }) : loginPath = loginPath ?? '/api/v1/auth/login',
       refreshPath = refreshPath ?? '/api/v1/auth/refresh',
       logoutPath = logoutPath ?? '/api/v1/auth/logout',
       profilePath = profilePath ?? '/api/v1/auth/profile',
       mfa = mfa ?? true;

  /// API path for login request.
  final String loginPath;

  /// API path for token refresh.
  final String refreshPath;

  /// API path for logout/revocation.
  final String logoutPath;

  /// API path for user profile (optional).
  final String profilePath;

  /// Whether MFA is supported.
  final bool mfa;
}
