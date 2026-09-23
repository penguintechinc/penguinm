import 'dart:convert';
import 'package:flutter_appauth/flutter_appauth.dart' as appauth;
import 'package:http/http.dart' as http;
import 'package:penguin_core/penguin_core.dart';
import 'app_auth_facade.dart';
import 'auth_backend.dart';
import 'auth_config.dart';
import 'jwt_claims.dart';
import 'login_request.dart';
import 'session.dart';

/// OIDC/SAML hosted login backend — the default for every app. Performs
/// the authorization code + PKCE flow in the system browser via
/// [AppAuthFacade] (real plugin in production, a fake in tests), resolving
/// endpoints from explicit [AuthConfig] values or OIDC discovery at
/// `<issuer>/.well-known/openid-configuration` when they are not given.
class HostedLoginBackend implements AuthBackend {
  /// Creates a hosted login backend for [config] (must be
  /// [AuthConfig.hosted]).
  HostedLoginBackend(
    this._config, {
    AppAuthFacade? appAuth,
    Clock? clock,
    http.Client? client,
  }) : _appAuth = appAuth ?? const FlutterAppAuthFacade(),
       _clock = clock ?? const SystemClock(),
       _client = client ?? http.Client() {
    if (_config case final HostedAuthConfig cfg) {
      _hostedConfig = cfg;
    } else {
      throw ArgumentError('HostedLoginBackend requires AuthConfig.hosted()');
    }
  }

  final AuthConfig _config;
  final AppAuthFacade _appAuth;
  final Clock _clock;
  final http.Client _client;
  late final HostedAuthConfig _hostedConfig;

  @override
  Future<Result<Session>> login(LoginRequest request) async {
    if (request case Interactive()) {
      return _interactiveLogin();
    }
    return Result.err(
      AuthFailure(null, 'HostedLoginBackend only supports interactive login'),
    );
  }

  /// Performs an interactive browser-based login flow, resolving
  /// authorization/token endpoints from config or discovery first so the
  /// facade always receives concrete endpoints.
  Future<Result<Session>> _interactiveLogin() async {
    try {
      final endpoints = await _resolveAuthEndpoints();
      if (endpoints case Err(:final failure)) {
        return Result.err(failure);
      }
      final (authorizationEndpoint, tokenEndpoint) = endpoints.valueOrNull!;

      final result = await _appAuth.authorizeAndExchangeCode(
        clientId: _hostedConfig.clientId,
        redirectUrl: _hostedConfig.redirectUri,
        authorizationEndpoint: authorizationEndpoint,
        tokenEndpoint: tokenEndpoint,
        scopes: _hostedConfig.scopes,
        preferEphemeralSession: _hostedConfig.preferEphemeralSession,
      );

      if (result.accessToken == null) {
        return Result.err(AuthFailure(null, 'Login was cancelled'));
      }

      return Result.ok(_sessionFromTokenResult(result));
    } on appauth.FlutterAppAuthUserCancelledException {
      // The real plugin throws rather than returning an empty result; a
      // fake/mock facade may do either — both map to the same outcome.
      // Kept here (not in the facade) so this translation is testable
      // without the real platform channel.
      return Result.err(AuthFailure(null, 'Login was cancelled'));
    } catch (e, st) {
      return Result.err(UnknownFailure(e, st));
    }
  }

  @override
  Future<Result<Session>> refresh(Session session) async {
    try {
      final refreshToken = session.refreshToken;
      if (refreshToken == null) {
        return Result.err(AuthFailure(null, 'No refresh token available'));
      }

      final tokenEndpointResult = await _resolveTokenEndpoint();
      if (tokenEndpointResult case Err(:final failure)) {
        return Result.err(failure);
      }
      final tokenEndpoint = tokenEndpointResult.valueOrNull!;

      final result = await _appAuth.token(
        clientId: _hostedConfig.clientId,
        redirectUrl: _hostedConfig.redirectUri,
        refreshToken: refreshToken,
        tokenEndpoint: tokenEndpoint,
        scopes: _hostedConfig.scopes,
      );

      if (result.accessToken == null) {
        return Result.err(AuthFailure(null, 'Token refresh failed'));
      }

      return Result.ok(
        _sessionFromTokenResult(result, fallbackRefreshToken: refreshToken),
      );
    } catch (e, st) {
      return Result.err(UnknownFailure(e, st));
    }
  }

  @override
  Future<Result<void>> logout(Session session) async {
    try {
      final endSessionEndpoint = _hostedConfig.endSessionEndpoint;
      if (endSessionEndpoint != null) {
        final ok = await _appAuth.endSession(
          idTokenHint: session.accessToken,
          endSessionEndpoint: endSessionEndpoint,
          redirectUrl: _hostedConfig.redirectUri,
          preferEphemeralSession: _hostedConfig.preferEphemeralSession,
        );
        if (!ok) {
          return Result.err(
            AuthFailure(null, 'End-session request was rejected'),
          );
        }
      }
      return const Result.ok(null);
    } catch (e, st) {
      return Result.err(UnknownFailure(e, st));
    }
  }

  /// Builds a [Session] from a token result, decoding claims from the
  /// access token (server-issued tokens are always JWTs per
  /// `docs/AUTH.md`'s backend contract; no signature check on the client).
  Session _sessionFromTokenResult(
    AppAuthTokenResult result, {
    String? fallbackRefreshToken,
  }) {
    final claims = JwtClaims.decode(result.accessToken!);
    final expiresAt =
        result.accessTokenExpirationDateTime ??
        _clock.now().add(const Duration(hours: 1));
    return Session(
      accessToken: result.accessToken!,
      refreshToken: result.refreshToken ?? fallbackRefreshToken,
      expiresAt: expiresAt,
      claims: claims,
    );
  }

  /// Resolves both authorization and token endpoints: explicit config
  /// values when given, OIDC discovery otherwise.
  Future<Result<(Uri, Uri)>> _resolveAuthEndpoints() async {
    var authEndpoint = _hostedConfig.authorizationEndpoint;
    var tokenEndpoint = _hostedConfig.tokenEndpoint;

    if (authEndpoint == null || tokenEndpoint == null) {
      final discoveryResult = await _discoverEndpoints(_hostedConfig.issuer);
      if (discoveryResult case Err(:final failure)) {
        return Result.err(failure);
      }
      final discovery = discoveryResult.valueOrNull!;
      authEndpoint ??= _parseUri(discovery['authorization_endpoint']);
      tokenEndpoint ??= _parseUri(discovery['token_endpoint']);
      if (authEndpoint == null || tokenEndpoint == null) {
        return Result.err(
          AuthFailure(
            null,
            'Could not discover authorization or token endpoints',
          ),
        );
      }
    }

    return Result.ok((authEndpoint, tokenEndpoint));
  }

  /// Resolves the token endpoint alone (used by [refresh]): explicit
  /// config value when given, OIDC discovery otherwise.
  Future<Result<Uri>> _resolveTokenEndpoint() async {
    final explicit = _hostedConfig.tokenEndpoint;
    if (explicit != null) return Result.ok(explicit);

    final discoveryResult = await _discoverEndpoints(_hostedConfig.issuer);
    if (discoveryResult case Err(:final failure)) {
      return Result.err(failure);
    }
    final tokenEndpoint = _parseUri(
      discoveryResult.valueOrNull!['token_endpoint'],
    );
    if (tokenEndpoint == null) {
      return Result.err(AuthFailure(null, 'Could not discover token endpoint'));
    }
    return Result.ok(tokenEndpoint);
  }

  Uri? _parseUri(Object? value) => value is String ? Uri.parse(value) : null;

  /// Performs OIDC discovery by fetching the .well-known endpoint.
  Future<Result<Map<String, dynamic>>> _discoverEndpoints(Uri issuer) async {
    try {
      final discoveryUrl = issuer.replace(
        path: '/.well-known/openid-configuration',
      );
      final response = await _client
          .get(discoveryUrl)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return Result.err(
          NetworkFailure('Discovery failed with status ${response.statusCode}'),
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Result.ok(json);
    } catch (e, st) {
      return Result.err(UnknownFailure(e, st));
    }
  }
}

/// Maps [preferEphemeralSession] to the corresponding `flutter_appauth`
/// [appauth.ExternalUserAgent] — the ephemeral session variant (no shared
/// browser cookies/cache) when true, the OS-preferred agent otherwise.
///
/// Pure mapping, no plugin/platform-channel call — kept out of the
/// `coverage:ignore` block below and unit-tested directly. Not exported by
/// the `penguin_auth` barrel: it's an internal detail of the
/// [FlutterAppAuthFacade] adapter, not public package API.
appauth.ExternalUserAgent externalUserAgentFor(bool preferEphemeralSession) =>
    preferEphemeralSession
    ? appauth.ExternalUserAgent.ephemeralAsWebAuthenticationSession
    : appauth.ExternalUserAgent.asWebAuthenticationSession;

/// Normalizes an empty scopes list to `null` for `flutter_appauth`'s
/// request types, which treat `null` (not `[]`) as "no explicit scopes
/// requested" — sending an empty list would emit a blank `scope=`
/// parameter instead of omitting it.
///
/// Pure mapping, no plugin/platform-channel call — kept out of the
/// `coverage:ignore` block below and unit-tested directly. Not exported by
/// the `penguin_auth` barrel: it's an internal detail of the
/// [FlutterAppAuthFacade] adapter, not public package API.
List<String>? normalizeScopes(List<String> scopes) =>
    scopes.isEmpty ? null : scopes;

// The lines below only wrap `package:flutter_appauth`'s method-channel
// calls, which throw MissingPluginException outside a real device/emulator
// and so cannot be exercised by `flutter test`. This block is straight
// delegation only: no try/catch, no conditionals of any kind (including
// `?:`/`??`/`?.`) — every decision point (external-user-agent mapping,
// empty-scopes normalization, cancellation translation) lives outside it,
// in HostedLoginBackend and the two functions above, all fully covered via
// a fake AppAuthFacade.
// coverage:ignore-start

/// Production [AppAuthFacade] adapter delegating to the real
/// `flutter_appauth` plugin, with no error handling of its own — every
/// exception (including a cancelled browser flow) propagates to
/// [HostedLoginBackend], which is where cancellation and failures are
/// translated and tested.
class FlutterAppAuthFacade implements AppAuthFacade {
  /// Creates a facade backed by the real flutter_appauth plugin.
  const FlutterAppAuthFacade();

  static const _client = appauth.FlutterAppAuth();

  @override
  AppAuthTokenResult get emptyTokenResponse => (
    accessToken: null,
    refreshToken: null,
    accessTokenExpirationDateTime: null,
  );

  @override
  Future<AppAuthTokenResult> authorizeAndExchangeCode({
    required String clientId,
    required String redirectUrl,
    required Uri authorizationEndpoint,
    required Uri tokenEndpoint,
    List<String> scopes = const [],
    bool preferEphemeralSession = false,
  }) async {
    // No try/catch: a cancelled browser flow throws
    // FlutterAppAuthUserCancelledException, which propagates to
    // HostedLoginBackend and is translated there (testable without a real
    // platform channel) instead of being swallowed into emptyTokenResponse
    // here.
    final response = await _client.authorizeAndExchangeCode(
      appauth.AuthorizationTokenRequest(
        clientId,
        redirectUrl,
        serviceConfiguration: appauth.AuthorizationServiceConfiguration(
          authorizationEndpoint: authorizationEndpoint.toString(),
          tokenEndpoint: tokenEndpoint.toString(),
        ),
        scopes: normalizeScopes(scopes),
        externalUserAgent: externalUserAgentFor(preferEphemeralSession),
      ),
    );
    return (
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      accessTokenExpirationDateTime: response.accessTokenExpirationDateTime,
    );
  }

  @override
  Future<AppAuthTokenResult> token({
    required String clientId,
    required String redirectUrl,
    required String refreshToken,
    required Uri tokenEndpoint,
    List<String> scopes = const [],
  }) async {
    final response = await _client.token(
      appauth.TokenRequest(
        clientId,
        redirectUrl,
        refreshToken: refreshToken,
        // AppAuth's service configuration always requires both endpoints;
        // only tokenEndpoint is actually used for a refresh grant.
        serviceConfiguration: appauth.AuthorizationServiceConfiguration(
          authorizationEndpoint: tokenEndpoint.toString(),
          tokenEndpoint: tokenEndpoint.toString(),
        ),
        scopes: normalizeScopes(scopes),
      ),
    );
    return (
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      accessTokenExpirationDateTime: response.accessTokenExpirationDateTime,
    );
  }

  @override
  Future<bool> endSession({
    required String idTokenHint,
    required Uri endSessionEndpoint,
    required String redirectUrl,
    bool preferEphemeralSession = false,
  }) async {
    // No try/catch: a plugin failure here must reach HostedLoginBackend's
    // own catch (which preserves the error/stack trace as an
    // UnknownFailure) rather than being swallowed into a bare `false` that
    // discards why end-session failed.
    await _client.endSession(
      appauth.EndSessionRequest(
        idTokenHint: idTokenHint,
        postLogoutRedirectUrl: redirectUrl,
        // Only endSessionEndpoint is used for RP-initiated logout; the
        // other two are filled in to satisfy the required config shape.
        serviceConfiguration: appauth.AuthorizationServiceConfiguration(
          authorizationEndpoint: endSessionEndpoint.toString(),
          tokenEndpoint: endSessionEndpoint.toString(),
          endSessionEndpoint: endSessionEndpoint.toString(),
        ),
        externalUserAgent: externalUserAgentFor(preferEphemeralSession),
      ),
    );
    return true;
  }
}

// coverage:ignore-end
