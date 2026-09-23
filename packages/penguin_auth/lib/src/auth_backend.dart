import 'package:penguin_core/penguin_core.dart';
import 'login_request.dart';
import 'session.dart';

/// Authentication backend: performs login, refresh, and logout operations.
abstract interface class AuthBackend {
  /// Attempts to log in via the given [request] (interactive browser,
  /// password credentials, or LoginPageBuilder response).
  /// Returns the resulting session or a failure.
  Future<Result<Session>> login(LoginRequest request);

  /// Attempts to refresh an expired [session] using its refresh token.
  /// Returns a new session or a failure.
  Future<Result<Session>> refresh(Session session);

  /// Attempts to logout, revoking the [session]. The session is cleared
  /// locally regardless of this result (failures are logged as warnings).
  Future<Result<void>> logout(Session session);
}
