import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';

/// Scripted [AuthBackend] fake: [login]/[refresh]/[logout] each draw from
/// their own FIFO queue of [Result]s, recording every request/session they
/// were called with so tests can assert on `AuthController` behaviour
/// without a real OIDC/password backend.
///
/// [login]/[refresh] throw [StateError] when called with nothing queued —
/// deliberate fail-fast, since a silent default would mask a test that
/// forgot to script the very call it's exercising. [logout] is the one
/// asymmetric exception: it defaults to a successful no-op when unscripted,
/// because logout is a common, often-incidental teardown step (clearing a
/// session at the end of an unrelated test) rather than the behaviour under
/// test, so requiring it to always be scripted would be pure noise.
class FakeAuthBackend implements AuthBackend {
  final List<Result<Session>> _loginResults = <Result<Session>>[];
  final List<Result<Session>> _refreshResults = <Result<Session>>[];
  final List<Result<void>> _logoutResults = <Result<void>>[];

  /// Every [LoginRequest] passed to [login] so far, in order.
  final List<LoginRequest> loginRequests = <LoginRequest>[];

  /// Every [Session] passed to [refresh] so far, in order.
  final List<Session> refreshedSessions = <Session>[];

  /// Every [Session] passed to [logout] so far, in order.
  final List<Session> loggedOutSessions = <Session>[];

  /// Appends [result] to the queue [login] draws from.
  void queueLogin(Result<Session> result) => _loginResults.add(result);

  /// Appends [result] to the queue [refresh] draws from.
  void queueRefresh(Result<Session> result) => _refreshResults.add(result);

  /// Appends [result] to the queue [logout] draws from; when never called,
  /// [logout] defaults to a successful no-op (matching a backend with
  /// nothing to revoke).
  void queueLogout(Result<void> result) => _logoutResults.add(result);

  @override
  Future<Result<Session>> login(LoginRequest request) async {
    loginRequests.add(request);
    if (_loginResults.isEmpty) {
      throw StateError('FakeAuthBackend.login called with no queued result');
    }
    return _loginResults.removeAt(0);
  }

  @override
  Future<Result<Session>> refresh(Session session) async {
    refreshedSessions.add(session);
    if (_refreshResults.isEmpty) {
      throw StateError('FakeAuthBackend.refresh called with no queued result');
    }
    return _refreshResults.removeAt(0);
  }

  @override
  Future<Result<void>> logout(Session session) async {
    loggedOutSessions.add(session);
    if (_logoutResults.isEmpty) {
      return const Result<void>.ok(null);
    }
    return _logoutResults.removeAt(0);
  }
}
