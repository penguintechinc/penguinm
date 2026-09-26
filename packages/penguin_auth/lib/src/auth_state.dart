import 'session.dart';

/// Lifecycle state of authentication: unknown (loading), unauthenticated,
/// authenticating (mid-flow), authenticated (with session), or expired
/// (refresh failed).
sealed class AuthState {
  const AuthState();

  /// Initial state before the session is loaded from storage.
  const factory AuthState.unknown() = Unknown;

  /// User is not authenticated.
  const factory AuthState.unauthenticated() = Unauthenticated;

  /// Login or refresh is in progress.
  const factory AuthState.authenticating() = Authenticating;

  /// User is authenticated with a valid session.
  const factory AuthState.authenticated(Session session) = Authenticated;

  /// The session expired and could not be refreshed.
  const factory AuthState.expired() = Expired;
}

/// Initial state before the session is loaded.
class Unknown extends AuthState {
  /// Creates an unknown state.
  const Unknown();
}

/// User is not authenticated.
class Unauthenticated extends AuthState {
  /// Creates an unauthenticated state.
  const Unauthenticated();
}

/// Login or refresh is in progress.
class Authenticating extends AuthState {
  /// Creates an authenticating state.
  const Authenticating();
}

/// User is authenticated.
class Authenticated extends AuthState {
  /// Creates an authenticated state with a session.
  const Authenticated(this.session);

  /// The active session.
  final Session session;
}

/// Session expired and could not be refreshed.
class Expired extends AuthState {
  /// Creates an expired state.
  const Expired();
}
