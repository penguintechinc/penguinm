/// External source of an access token and refresh capability, implemented
/// by `penguin_auth`. Kept here so `penguin_api`/`penguin_offline` can
/// depend on token behaviour without depending on the auth package itself.
abstract interface class TokenProvider {
  /// Returns the current access token, or null when unauthenticated.
  Future<String?> accessToken();

  /// Attempts to refresh the access token; returns true on success.
  Future<bool> refresh();

  /// Lifecycle events (refreshed, forced sign-out) for listeners to react
  /// to, such as the API client's auth middleware.
  Stream<AuthEvent> get events;
}

/// Lifecycle events a [TokenProvider] emits for listeners — e.g. the API
/// client's `AuthClient` reacting to a completed refresh or an
/// unrecoverable auth failure.
enum AuthEvent {
  /// The access token was successfully refreshed.
  refreshed,

  /// The session could not be refreshed and the user must sign in again.
  unauthenticated,
}
