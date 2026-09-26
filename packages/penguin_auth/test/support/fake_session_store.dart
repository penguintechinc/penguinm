import 'dart:async';

import 'package:penguin_auth/penguin_auth.dart';

/// In-memory [SessionStore] stand-in for tests — never touches
/// `flutter_secure_storage`, so tests can run as plain `test()` blocks with
/// fully microtask-bound (not platform-channel-bound) async behaviour.
class FakeSessionStore extends SessionStore {
  /// Creates a fake store, optionally pre-seeded with [initial].
  FakeSessionStore({Session? initial}) : _stored = initial;

  Session? _stored;
  Completer<void>? _pendingSave;
  Completer<void>? _pendingLoad;

  /// The session currently held, for test assertions.
  Session? get stored => _stored;

  /// Makes the *next* [save] call suspend until the returned [Completer]
  /// is completed — used to force a TOCTOU window between `state = ...`
  /// and the save actually landing, so a concurrent `logout()`/`login()`
  /// can run in between.
  Completer<void> pauseNextSave() {
    final completer = Completer<void>();
    _pendingSave = completer;
    return completer;
  }

  /// Makes the *next* [load] call suspend until the returned [Completer]
  /// is completed — used to force a window during `initialize()`'s load
  /// where a concurrent `login()`/`logout()` can run and change what's in
  /// the store before this call returns. The value returned is snapshotted
  /// at call time (before suspending), matching a real read that already
  /// fetched its data before a concurrent write/clear landed — this is
  /// what makes the resulting race worth guarding against.
  Completer<void> pauseNextLoad() {
    final completer = Completer<void>();
    _pendingLoad = completer;
    return completer;
  }

  @override
  Future<Session?> load() async {
    final snapshot = _stored;
    final pending = _pendingLoad;
    _pendingLoad = null;
    if (pending != null) {
      await pending.future;
    }
    return snapshot;
  }

  @override
  Future<void> save(Session session) async {
    final pending = _pendingSave;
    _pendingSave = null;
    if (pending != null) {
      await pending.future;
    }
    _stored = session;
  }

  @override
  Future<void> clear() async {
    _stored = null;
  }
}
