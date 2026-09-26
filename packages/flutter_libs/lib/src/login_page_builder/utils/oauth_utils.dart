import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../login_types.dart';

/// OAuth2 provider endpoint configurations.
const Map<BuiltInProviderType, _ProviderEndpoint> _providerEndpoints = {
  BuiltInProviderType.google: _ProviderEndpoint(
    authUrl: 'https://accounts.google.com/o/oauth2/v2/auth',
    defaultScopes: ['openid', 'email', 'profile'],
  ),
  BuiltInProviderType.github: _ProviderEndpoint(
    authUrl: 'https://github.com/login/oauth/authorize',
    defaultScopes: ['user:email'],
  ),
  BuiltInProviderType.microsoft: _ProviderEndpoint(
    authUrl: 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
    defaultScopes: ['openid', 'email', 'profile'],
  ),
  BuiltInProviderType.apple: _ProviderEndpoint(
    authUrl: 'https://appleid.apple.com/auth/authorize',
    defaultScopes: ['name', 'email'],
  ),
  BuiltInProviderType.twitch: _ProviderEndpoint(
    authUrl: 'https://id.twitch.tv/oauth2/authorize',
    defaultScopes: ['user:read:email'],
  ),
  BuiltInProviderType.discord: _ProviderEndpoint(
    authUrl: 'https://discord.com/api/oauth2/authorize',
    defaultScopes: ['identify', 'email'],
  ),
};

class _ProviderEndpoint {
  const _ProviderEndpoint({required this.authUrl, required this.defaultScopes});

  final String authUrl;
  final List<String> defaultScopes;
}

/// Provider display colors for social login buttons.
class ProviderColors {
  /// Creates [ProviderColors] with background and text ARGB colors.
  const ProviderColors({required this.background, required this.text});

  /// Background color as ARGB hex value.
  final int background;

  /// Text color as ARGB hex value.
  final int text;
}

/// Default button colors for built-in providers.
const Map<BuiltInProviderType, ProviderColors> providerColorMap = {
  BuiltInProviderType.google: ProviderColors(
    background: 0xFFFFFFFF,
    text: 0xFF374151,
  ),
  BuiltInProviderType.github: ProviderColors(
    background: 0xFF111827,
    text: 0xFFFFFFFF,
  ),
  BuiltInProviderType.microsoft: ProviderColors(
    background: 0xFF2F2F2F,
    text: 0xFFFFFFFF,
  ),
  BuiltInProviderType.apple: ProviderColors(
    background: 0xFF000000,
    text: 0xFFFFFFFF,
  ),
  BuiltInProviderType.twitch: ProviderColors(
    background: 0xFF9146FF,
    text: 0xFFFFFFFF,
  ),
  BuiltInProviderType.discord: ProviderColors(
    background: 0xFF5865F2,
    text: 0xFFFFFFFF,
  ),
};

/// Result of building an OAuth2/OIDC authorization URL.
///
/// Carries the [url] to navigate/launch the user to, the CSRF [state] value
/// (validate it against the callback's `state` param with
/// [isValidCallbackState] before proceeding), and the PKCE [codeVerifier]
/// the caller must retain (e.g. in memory or secure storage keyed by
/// [state]) to exchange the authorization code for tokens once the
/// callback fires.
class OAuth2AuthorizationRequest {
  /// Creates an [OAuth2AuthorizationRequest] with authorization URL and CSRF/PKCE values.
  const OAuth2AuthorizationRequest({
    required this.url,
    required this.state,
    required this.codeVerifier,
  });

  /// The authorization endpoint URL to navigate/launch the user to.
  final String url;

  /// The CSRF state value to validate in the callback.
  final String state;

  /// The PKCE code verifier to use for token exchange.
  final String codeVerifier;
}

/// Generate a cryptographically secure state parameter for CSRF protection.
///
/// Returns a 32-byte hex string.
String generateState() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Generate a PKCE code verifier.
///
/// Returns a base64url-encoded 32-byte random string.
String generateCodeVerifier() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Generate a PKCE code challenge from a [verifier].
///
/// Returns the SHA-256 hash of the verifier, base64url-encoded.
String generateCodeChallenge(String verifier) {
  final bytes = utf8.encode(verifier);
  final digest = sha256.convert(bytes);
  return base64Url.encode(digest.bytes).replaceAll('=', '');
}

/// Builds an OAuth2 authorization URL for a built-in provider, with PKCE
/// (`S256`) and CSRF `state` wired in.
///
/// Returns an [OAuth2AuthorizationRequest] whose `url` is ready to
/// navigate/launch the user to. The returned
/// [OAuth2AuthorizationRequest.codeVerifier] must be retained by the caller
/// and used at token-exchange time; the [OAuth2AuthorizationRequest.state]
/// must be validated against the callback via [isValidCallbackState].
///
/// Throws an [ArgumentError] if [provider]'s `provider` type has no known
/// endpoint configuration.
OAuth2AuthorizationRequest buildOAuth2Url(
  /// The built-in provider configuration.
  BuiltInOAuth2Provider provider, {

  /// Optional state value; if omitted, a random value is generated.
  String? state,
}) {
  final endpoint = _providerEndpoints[provider.provider];
  if (endpoint == null) {
    throw ArgumentError('Unknown provider: ${provider.provider}');
  }

  final oauthState = state ?? generateState();
  final codeVerifier = generateCodeVerifier();
  final codeChallenge = generateCodeChallenge(codeVerifier);
  final scopes = provider.scopes ?? endpoint.defaultScopes;

  final params = <String, String>{
    'client_id': provider.clientId,
    'response_type': 'code',
    'scope': scopes.join(' '),
    'state': oauthState,
    'code_challenge': codeChallenge,
    'code_challenge_method': 'S256',
  };

  if (provider.redirectUri != null) {
    params['redirect_uri'] = provider.redirectUri!;
  }

  final uri = Uri.parse(endpoint.authUrl).replace(queryParameters: params);
  return OAuth2AuthorizationRequest(
    url: uri.toString(),
    state: oauthState,
    codeVerifier: codeVerifier,
  );
}

/// Builds an OAuth2 authorization URL for a custom provider, with PKCE
/// (`S256`) and CSRF `state` wired in.
///
/// Returns an [OAuth2AuthorizationRequest] built from [provider]'s
/// `authUrl`; unlike [buildOAuth2Url] the `scope` parameter is omitted
/// entirely from the URL when [provider] has no scopes configured, rather
/// than sent empty. See [buildOAuth2Url] for the caller-side contract on
/// the returned request (retain `codeVerifier`, validate `state`).
OAuth2AuthorizationRequest buildCustomOAuth2Url(
  /// The custom provider configuration.
  CustomOAuth2Provider provider, {

  /// Optional state value; if omitted, a random value is generated.
  String? state,
}) {
  final oauthState = state ?? generateState();
  final codeVerifier = generateCodeVerifier();
  final codeChallenge = generateCodeChallenge(codeVerifier);
  final scopes = provider.scopes ?? [];

  final params = <String, String>{
    'client_id': provider.clientId,
    'response_type': 'code',
    'state': oauthState,
    'code_challenge': codeChallenge,
    'code_challenge_method': 'S256',
  };

  if (scopes.isNotEmpty) {
    params['scope'] = scopes.join(' ');
  }

  if (provider.redirectUri != null) {
    params['redirect_uri'] = provider.redirectUri!;
  }

  final uri = Uri.parse(provider.authUrl).replace(queryParameters: params);
  return OAuth2AuthorizationRequest(
    url: uri.toString(),
    state: oauthState,
    codeVerifier: codeVerifier,
  );
}

/// Builds an OIDC authorization URL using the issuer's discovery document.
///
/// Fetches `{issuerUrl}/.well-known/openid-configuration` (30s timeout) and
/// uses its `authorization_endpoint`, rather than assuming a path — issuers
/// are not required to serve authorization at `/authorize`. Wires in PKCE
/// (`S256`) and CSRF `state`; see [buildOAuth2Url] for the caller-side
/// contract on the returned request.
///
/// Returns a [Future] that resolves to the [OAuth2AuthorizationRequest]
/// built from the discovered `authorization_endpoint`.
///
/// Throws on discovery fetch failure, a non-200 response, a malformed
/// document, or a missing `authorization_endpoint` — callers should treat
/// any exception as "social login unavailable" and surface an error rather
/// than falling back to a guessed URL.
Future<OAuth2AuthorizationRequest> buildOIDCUrl(
  /// The OIDC provider configuration.
  OIDCProvider provider, {

  /// Optional state value; if omitted, a random value is generated.
  String? state,

  /// Optional HTTP client for discovery; if omitted, an ephemeral client is created.
  http.Client? client,
}) async {
  final oauthState = state ?? generateState();
  final codeVerifier = generateCodeVerifier();
  final codeChallenge = generateCodeChallenge(codeVerifier);
  final scopes = provider.scopes ?? ['openid', 'email', 'profile'];

  final discoveryUrl = provider.issuerUrl.endsWith('/')
      ? '${provider.issuerUrl}.well-known/openid-configuration'
      : '${provider.issuerUrl}/.well-known/openid-configuration';

  final ownedClient = client == null ? http.Client() : null;
  final httpClient = client ?? ownedClient!;

  final http.Response response;
  try {
    response = await httpClient
        .get(Uri.parse(discoveryUrl))
        .timeout(const Duration(seconds: 30));
  } finally {
    ownedClient?.close();
  }

  if (response.statusCode != 200) {
    throw http.ClientException(
      'OIDC discovery request failed with status ${response.statusCode}',
    );
  }

  final decoded = json.decode(response.body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException(
      'OIDC discovery document was not a JSON object',
    );
  }

  final authEndpoint = decoded['authorization_endpoint'] as String?;
  if (authEndpoint == null || authEndpoint.isEmpty) {
    throw const FormatException(
      'OIDC discovery document is missing authorization_endpoint',
    );
  }

  final params = <String, String>{
    'client_id': provider.clientId,
    'response_type': 'code',
    'scope': scopes.join(' '),
    'state': oauthState,
    'code_challenge': codeChallenge,
    'code_challenge_method': 'S256',
  };

  if (provider.redirectUri != null) {
    params['redirect_uri'] = provider.redirectUri!;
  }

  final uri = Uri.parse(authEndpoint).replace(queryParameters: params);
  return OAuth2AuthorizationRequest(
    url: uri.toString(),
    state: oauthState,
    codeVerifier: codeVerifier,
  );
}

/// Gets the display label for a built-in provider.
///
/// Returns the provider's human-readable brand name (e.g. `'Google'`,
/// `'GitHub'`) for use on a social login button.
String getProviderLabel(
  /// The provider type to get the label for.
  BuiltInProviderType provider,
) {
  switch (provider) {
    case BuiltInProviderType.google:
      return 'Google';
    case BuiltInProviderType.github:
      return 'GitHub';
    case BuiltInProviderType.microsoft:
      return 'Microsoft';
    case BuiltInProviderType.apple:
      return 'Apple';
    case BuiltInProviderType.twitch:
      return 'Twitch';
    case BuiltInProviderType.discord:
      return 'Discord';
  }
}

/// Gets the button colors for a built-in provider.
///
/// Returns the [ProviderColors] from [providerColorMap] for [provider];
/// falls back to a neutral slate background (`0xFF334155`) with white text
/// if [provider] has no entry in the map.
ProviderColors getProviderColors(
  /// The provider type to get colors for.
  BuiltInProviderType provider,
) {
  return providerColorMap[provider] ??
      const ProviderColors(background: 0xFF334155, text: 0xFFFFFFFF);
}
