/// Token/claims returned by an [AppAuthFacade] exchange or refresh call.
/// All-null fields (see [AppAuthFacade.emptyTokenResponse]) mean the flow
/// was cancelled or failed at the facade level rather than throwing.
typedef AppAuthTokenResult = ({
  String? accessToken,
  String? refreshToken,
  DateTime? accessTokenExpirationDateTime,
});

/// Abstraction over `package:flutter_appauth`'s authorization code + PKCE
/// flow, letting [HostedLoginBackend] be unit-tested without the real
/// plugin (which requires platform channels unavailable outside a device).
///
/// Endpoint discovery (explicit config vs `.well-known/openid-configuration`)
/// is always resolved by the caller before these methods are invoked, so
/// every method here receives concrete endpoint URIs — this facade never
/// performs discovery itself.
abstract interface class AppAuthFacade {
  /// An all-null result — a convenience fakes/mocks can return for a
  /// cancelled or failed flow.
  AppAuthTokenResult get emptyTokenResponse;

  /// Initiates an authorization code + PKCE flow in the system browser
  /// against [authorizationEndpoint]/[tokenEndpoint]. A fake/mock may
  /// represent cancellation as [emptyTokenResponse]; the real plugin
  /// instead throws (`FlutterAppAuthUserCancelledException`) — callers
  /// must handle both, since this facade does not normalize the two.
  Future<AppAuthTokenResult> authorizeAndExchangeCode({
    required String clientId,
    required String redirectUrl,
    required Uri authorizationEndpoint,
    required Uri tokenEndpoint,
    List<String> scopes = const [],
    bool preferEphemeralSession = false,
  });

  /// Exchanges a refresh token for a new access token at [tokenEndpoint].
  /// Returns [emptyTokenResponse] if the refresh is rejected or fails.
  Future<AppAuthTokenResult> token({
    required String clientId,
    required String redirectUrl,
    required String refreshToken,
    required Uri tokenEndpoint,
    List<String> scopes = const [],
  });

  /// Ends the user's session at [endSessionEndpoint]. Returns true on
  /// success; a facade may return false for a handled rejection or throw
  /// for an unexpected error — [HostedLoginBackend.logout] treats both as
  /// failure and neither is swallowed silently.
  Future<bool> endSession({
    required String idTokenHint,
    required Uri endSessionEndpoint,
    required String redirectUrl,
    bool preferEphemeralSession = false,
  });
}
