import 'dart:async';

import 'package:penguin_core/penguin_core.dart';

/// Scripted [TokenProvider] fake: [accessToken] returns a settable token
/// and [refresh] succeeds or fails as configured, recording every call and
/// emitted [AuthEvent] so tests can assert on `AuthClient`/`AuthController`
/// interactions without a real token backend.
class FakeTokenProvider implements TokenProvider {
  /// Creates a fake token provider starting with [initialToken] (null means
  /// unauthenticated) and a [refreshSucceeds] policy applied to every
  /// subsequent [refresh] call until changed via [setRefreshSucceeds].
  FakeTokenProvider({String? initialToken, this._refreshSucceeds = true})
    : _token = initialToken;

  String? _token;
  bool _refreshSucceeds;
  final StreamController<AuthEvent> _controller =
      StreamController<AuthEvent>.broadcast();

  /// Number of times [refresh] has been called.
  int refreshCallCount = 0;

  /// Every [AuthEvent] emitted so far, in order.
  final List<AuthEvent> emittedEvents = <AuthEvent>[];

  @override
  Future<String?> accessToken() async => _token;

  @override
  Future<bool> refresh() async {
    refreshCallCount++;
    if (_refreshSucceeds) {
      _token = 'fake-refreshed-token-$refreshCallCount';
      emit(AuthEvent.refreshed);
      return true;
    }
    _token = null;
    emit(AuthEvent.unauthenticated);
    return false;
  }

  @override
  Stream<AuthEvent> get events => _controller.stream;

  /// Directly sets the token [accessToken] will return next, without going
  /// through [refresh].
  void setToken(String? token) {
    _token = token;
  }

  /// Changes whether the next [refresh] call succeeds.
  void setRefreshSucceeds(bool succeeds) {
    _refreshSucceeds = succeeds;
  }

  /// Pushes [event] onto [events] and records it in [emittedEvents], for
  /// tests simulating an out-of-band lifecycle event.
  void emit(AuthEvent event) {
    emittedEvents.add(event);
    if (!_controller.isClosed) _controller.add(event);
  }

  /// Closes the underlying [events] stream.
  Future<void> dispose() => _controller.close();
}
