import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penguin_core/penguin_core.dart';

import 'auth_state.dart';
import 'login_request.dart';
import 'providers.dart';
import 'session.dart';

/// Injection point for how [AuthController] creates its scheduled-refresh
/// [Timer] — overridden via [timerFactoryProvider] with a fake in tests so
/// refresh scheduling never waits on real time.
typedef TimerFactory =
    Timer Function(Duration duration, void Function() callback);

/// Main authentication controller: manages login/logout, token refresh,
/// and session persistence. Implements `TokenProvider` (from
/// `penguin_core`) so the API client can request access tokens and listen
/// for auth lifecycle events. Schedules automatic refresh at `exp - 60s`
/// via a [Timer] created through the injectable [timerFactoryProvider].
class AuthController extends Notifier<AuthState> implements TokenProvider {
  Timer? _refreshTimer;
  final StreamController<AuthEvent> _eventController =
      StreamController<AuthEvent>.broadcast();

  /// Bumped by every operation that resets or replaces the session
  /// (`initialize`, `login`, `logout`). A refresh captures this value
  /// before calling the backend and discards its result if the value has
  /// since changed — otherwise a refresh that was in flight when the user
  /// logged out (or logged into a different session) could resurrect a
  /// session the app has already moved past.
  int _generation = 0;

  /// The single in-flight refresh, if any — every `refresh()` caller while
  /// one is pending (and still in the same [_generation]) awaits this same
  /// [Future] instead of starting a second `backend.refresh()` call.
  Future<bool>? _inFlightRefresh;

  /// The [_generation] that started [_inFlightRefresh]. A refresh begun in
  /// an older generation is doomed to be discarded (see [_refreshSession])
  /// and must never be handed to a caller in a newer generation — that
  /// caller needs its own backend call. Compared against [_generation] on
  /// entry to [refresh]; the pair is cleared together once the future
  /// settles, but only if nothing newer has already replaced it.
  int? _inFlightRefreshGeneration;

  @override
  AuthState build() {
    ref.onDispose(() {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      unawaited(_eventController.close());
    });
    return const AuthState.unknown();
  }

  /// Loads the session from storage on app startup: no stored session →
  /// unauthenticated; a still-valid session → authenticated (with refresh
  /// scheduled); an expired session carrying a refresh token → attempts a
  /// refresh (authenticated on success, expired on failure); an expired
  /// session with no refresh token → expired directly.
  ///
  /// Captures [_generation] before loading and re-checks it immediately
  /// after: if a concurrent `login()`/`logout()`/second `initialize()` ran
  /// while the load was in flight, that operation's state/store/timer
  /// already stand, and this stale load's outcome (including any refresh
  /// it would otherwise trigger) is discarded without being applied.
  Future<void> initialize() async {
    _generation++;
    final generation = _generation;
    try {
      final session = await ref.read(sessionStoreProvider).load();
      if (generation != _generation) {
        return;
      }

      if (session == null) {
        state = const AuthState.unauthenticated();
        return;
      }

      if (!session.isExpired(ref.read(clockProvider))) {
        state = AuthState.authenticated(session);
        _scheduleRefresh(session);
        return;
      }

      if (session.refreshToken == null) {
        state = const AuthState.expired();
        return;
      }

      await _refreshSession(session);
    } catch (e, st) {
      ref
          .read(loggerProvider)
          .error(
            'AuthController.initialize failed; treating as unauthenticated',
            error: e,
            stackTrace: st,
          );
      if (generation != _generation) {
        return;
      }
      state = const AuthState.unauthenticated();
    }
  }

  /// A stale login/refresh — superseded by a `logout()`/`login()`/
  /// `initialize()` that ran while it was in flight — is discarded with
  /// this failure rather than applied.
  static const _supersededFailure = AuthFailure(
    null,
    'Superseded by a newer auth operation',
  );

  /// Attempts to log in via [request] (interactive browser flow, password
  /// credentials, or a LoginPageBuilder response). On success, state
  /// becomes authenticated and the session is persisted with refresh
  /// scheduled. On cancellation/failure, state is restored to whatever it
  /// was before the attempt — a failed login never corrupts or discards an
  /// existing session.
  ///
  /// Captures [_generation] before calling the backend and re-checks it
  /// both after that call and after persisting the session: if
  /// `logout()`/`login()`/`initialize()` ran while this one was in flight,
  /// its result is discarded outright (state is left exactly as the newer
  /// operation set it, and any session this call already wrote to storage
  /// is removed) — a login must never resurrect a session the app has
  /// already moved past.
  Future<Result<void>> login(LoginRequest request) async {
    _generation++;
    final generation = _generation;
    final previousState = state;
    state = const AuthState.authenticating();

    try {
      final backend = ref.read(authBackendProvider);
      final result = await backend.login(request);

      if (generation != _generation) {
        return const Result.err(_supersededFailure);
      }

      switch (result) {
        case Ok(:final value):
          state = AuthState.authenticated(value);
          await ref.read(sessionStoreProvider).save(value);
          if (generation != _generation) {
            // A newer operation ran during the save; undo the write and
            // leave state exactly as that operation left it.
            await ref.read(sessionStoreProvider).clear();
            return const Result.err(_supersededFailure);
          }
          _scheduleRefresh(value);
          _eventController.add(AuthEvent.refreshed);
          return const Result.ok(null);
        case Err(:final failure):
          state = previousState;
          return Result.err(failure);
      }
    } catch (e, st) {
      if (generation != _generation) {
        return Result.err(UnknownFailure(e, st));
      }
      state = previousState;
      return Result.err(UnknownFailure(e, st));
    }
  }

  /// Logs out: applies every local effect (timer cancelled, store cleared,
  /// state set to unauthenticated) FIRST, then calls the backend's
  /// logout/end-session best-effort — a WARN is logged if that fails or
  /// throws, but nothing after this point ever writes `state`, the store,
  /// or `_refreshTimer` again.
  ///
  /// This ordering removes the race rather than guarding it: the backend
  /// round-trip is the one genuinely slow, unpredictable step, so it runs
  /// last and its outcome can no longer clobber whatever a concurrent
  /// `login()`/`logout()` sets up while it's still in flight — by the time
  /// it's even issued, this logout has already fully applied.
  Future<void> logout() async {
    _generation++;
    final session = switch (state) {
      Authenticated(:final session) => session,
      _ => null,
    };

    _refreshTimer?.cancel();
    _refreshTimer = null;
    state = const AuthState.unauthenticated();
    _eventController.add(AuthEvent.unauthenticated);
    await ref.read(sessionStoreProvider).clear();

    if (session == null) return;

    try {
      final backend = ref.read(authBackendProvider);
      final result = await backend.logout(session);
      if (result case Err(:final failure)) {
        ref
            .read(loggerProvider)
            .warn(
              'Backend logout failed after the local session was already '
              'cleared',
              attributes: {'failureMessage': failure.message},
            );
      }
    } catch (e) {
      ref
          .read(loggerProvider)
          .warn(
            'Backend logout threw after the local session was already '
            'cleared',
            attributes: {'error': e.toString()},
          );
    }
  }

  /// Attempts to refresh the current session's access token — called
  /// automatically by the scheduled timer and by the API client on a 401.
  /// Transitions to [AuthState.expired] and emits
  /// [AuthEvent.unauthenticated] on failure; returns false immediately
  /// when there is no authenticated session to refresh.
  ///
  /// Concurrent callers in the *same* [_generation] (a 401-triggered
  /// refresh racing the scheduled timer, or two API calls both hitting a
  /// 401) share a single in-flight refresh — only one `backend.refresh()`
  /// call is made per burst, and every caller resolves with that call's
  /// result. A call in a *newer* generation never joins an older,
  /// doomed-to-be-discarded refresh — it starts its own.
  @override
  Future<bool> refresh() {
    final inFlight = _inFlightRefresh;
    if (inFlight != null && _inFlightRefreshGeneration == _generation) {
      return inFlight;
    }

    final session = switch (state) {
      Authenticated(:final session) => session,
      _ => null,
    };
    if (session == null) return Future.value(false);

    final generation = _generation;
    final future = _refreshSession(session);
    _inFlightRefresh = future;
    _inFlightRefreshGeneration = generation;
    // Clear the slot once this refresh settles (success, failure, or
    // discarded as stale) — but only if it's still this future occupying
    // it; a newer-generation refresh() may have already replaced it, and
    // clearing then would drop that one's own coalescing.
    unawaited(
      future.whenComplete(() {
        if (identical(_inFlightRefresh, future)) {
          _inFlightRefresh = null;
          _inFlightRefreshGeneration = null;
        }
      }),
    );
    return future;
  }

  @override
  Future<String?> accessToken() async {
    final session = switch (state) {
      Authenticated(:final session) => session,
      _ => null,
    };
    return session?.accessToken;
  }

  @override
  Stream<AuthEvent> get events => _eventController.stream;

  /// Shared refresh implementation used by both [initialize] (an expired
  /// stored session) and [refresh] (scheduled or 401-triggered).
  ///
  /// Captures [_generation] before calling the backend and re-checks it
  /// both after that call and after persisting the session: if
  /// `logout()`/`login()`/`initialize()` ran while either await was in
  /// flight, this refresh is stale and its result is discarded outright —
  /// it must never overwrite a newer state, and a session it already
  /// wrote to storage during the (now-stale) save is removed again rather
  /// than left to linger.
  Future<bool> _refreshSession(Session session) async {
    final generation = _generation;
    try {
      final backend = ref.read(authBackendProvider);
      final result = await backend.refresh(session);
      if (generation != _generation) {
        return false;
      }
      if (result case Ok(:final value)) {
        state = AuthState.authenticated(value);
        await ref.read(sessionStoreProvider).save(value);
        if (generation != _generation) {
          // A newer operation ran during the save; undo the write and
          // leave state exactly as that operation left it.
          await ref.read(sessionStoreProvider).clear();
          return false;
        }
        _scheduleRefresh(value);
        _eventController.add(AuthEvent.refreshed);
        return true;
      }
      state = const AuthState.expired();
      _eventController.add(AuthEvent.unauthenticated);
      return false;
    } catch (_) {
      if (generation != _generation) {
        return false;
      }
      state = const AuthState.expired();
      _eventController.add(AuthEvent.unauthenticated);
      return false;
    }
  }

  /// Schedules automatic token refresh at `exp - 60s`; fires on the next
  /// event-loop turn (zero delay) if that deadline has already passed.
  void _scheduleRefresh(Session session) {
    _refreshTimer?.cancel();
    final now = ref.read(clockProvider).now();
    final refreshAt = session.expiresAt.subtract(const Duration(seconds: 60));
    final delay = refreshAt.isAfter(now)
        ? refreshAt.difference(now)
        : Duration.zero;
    _refreshTimer = ref.read(timerFactoryProvider)(delay, () {
      unawaited(refresh());
    });
  }
}
