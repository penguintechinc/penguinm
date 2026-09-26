import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';

import 'support/fake_clock.dart';
import 'support/fake_session_store.dart';
import 'support/fake_timer_factory.dart';
import 'support/jwt_test_utils.dart';

class MockAuthBackend extends Mock implements AuthBackend {}

/// A hand-written [AppAuthFacade] fake for exercising [HostedLoginBackend]
/// end-to-end through a real [AuthController] — `endSessionResult`
/// controls whether `endSession` reports success.
class FakeAppAuthFacade implements AppAuthFacade {
  bool endSessionResult = true;

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
  }) async => emptyTokenResponse;

  @override
  Future<AppAuthTokenResult> token({
    required String clientId,
    required String redirectUrl,
    required String refreshToken,
    required Uri tokenEndpoint,
    List<String> scopes = const [],
  }) async => emptyTokenResponse;

  @override
  Future<bool> endSession({
    required String idTokenHint,
    required Uri endSessionEndpoint,
    required String redirectUrl,
    bool preferEphemeralSession = false,
  }) async => endSessionResult;
}

/// A [SessionStore] whose `load()` always throws — exercises
/// [AuthController.initialize]'s defensive catch block.
class ThrowingSessionStore extends SessionStore {
  @override
  Future<Session?> load() async => throw StateError('storage unavailable');
}

/// Waits for any already-queued microtask chains (mock `Future`s, the fake
/// session store) to finish — Dart fully drains the microtask queue before
/// a zero-duration `Timer`/`Future.delayed` callback runs, so this is
/// sufficient to observe the result of firing a captured timer callback
/// with no real waiting.
Future<void> flushMicrotasks() => Future<void>.delayed(Duration.zero);

Session _buildSession({
  required FakeClock clock,
  String sub = 'user-123',
  Duration expiresIn = const Duration(hours: 1),
  String? refreshToken = 'refresh-123',
}) {
  final expiresAt = clock.now().add(expiresIn);
  final jwt = buildTestJwt({
    'sub': sub,
    'iss': 'https://auth.example.com',
    'aud': 'app',
    'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
  });
  return Session(
    accessToken: jwt,
    refreshToken: refreshToken,
    expiresAt: expiresAt,
    claims: JwtClaims.decode(jwt),
  );
}

void main() {
  setUpAll(() {
    final clock = FakeClock();
    registerFallbackValue(const LoginRequest.interactive());
    registerFallbackValue(_buildSession(clock: clock));
  });

  group('AuthController', () {
    late FakeClock clock;
    late MockAuthBackend backend;
    late FakeTimerFactory timerFactory;
    late FakeSessionStore sessionStore;
    late List<String> logLines;

    ProviderContainer buildContainer() {
      final container = ProviderContainer(
        overrides: [
          authBackendProvider.overrideWithValue(backend),
          clockProvider.overrideWithValue(clock),
          sessionStoreProvider.overrideWithValue(sessionStore),
          timerFactoryProvider.overrideWithValue(timerFactory.call),
          loggerProvider.overrideWithValue(
            ConsoleLogger(clock: clock, sink: logLines.add),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      clock = FakeClock(startTime: DateTime(2024, 1, 1));
      backend = MockAuthBackend();
      timerFactory = FakeTimerFactory();
      sessionStore = FakeSessionStore();
      logLines = [];
    });

    group('initialize', () {
      test(
        'unknown before initialize; unauthenticated once store is empty',
        () async {
          final container = buildContainer();
          expect(container.read(authControllerProvider), isA<Unknown>());

          final controller = container.read(authControllerProvider.notifier);
          await controller.initialize();

          expect(
            container.read(authControllerProvider),
            isA<Unauthenticated>(),
          );
        },
      );

      test(
        'stored valid session becomes authenticated and schedules refresh',
        () async {
          final session = _buildSession(
            clock: clock,
            expiresIn: const Duration(hours: 1),
          );
          sessionStore = FakeSessionStore(initial: session);
          final container = buildContainer();

          await container.read(authControllerProvider.notifier).initialize();

          final state = container.read(authControllerProvider);
          expect(state, isA<Authenticated>());
          expect(
            (state as Authenticated).session.accessToken,
            session.accessToken,
          );
          expect(timerFactory.calls, hasLength(1));
          expect(
            timerFactory.last!.duration,
            const Duration(hours: 1) - const Duration(seconds: 60),
          );
        },
      );

      test(
        'stored expired session with refresh token refreshes to authenticated',
        () async {
          final expired = _buildSession(
            clock: clock,
            expiresIn: const Duration(seconds: -30),
          );
          sessionStore = FakeSessionStore(initial: expired);
          final refreshed = _buildSession(
            clock: clock,
            expiresIn: const Duration(hours: 2),
          );
          when(
            () => backend.refresh(any()),
          ).thenAnswer((_) async => Result.ok(refreshed));

          final container = buildContainer();
          await container.read(authControllerProvider.notifier).initialize();

          final state = container.read(authControllerProvider);
          expect(state, isA<Authenticated>());
          expect(
            (state as Authenticated).session.accessToken,
            refreshed.accessToken,
          );
          expect(sessionStore.stored?.accessToken, refreshed.accessToken);
        },
      );

      test('stored expired session, refresh failure becomes expired', () async {
        final expired = _buildSession(
          clock: clock,
          expiresIn: const Duration(seconds: -30),
        );
        sessionStore = FakeSessionStore(initial: expired);
        when(() => backend.refresh(any())).thenAnswer(
          (_) async => Result.err(AuthFailure(401, 'invalid_grant')),
        );

        final container = buildContainer();
        await container.read(authControllerProvider.notifier).initialize();

        expect(container.read(authControllerProvider), isA<Expired>());
      });

      test(
        'stored expired session with no refresh token becomes expired directly',
        () async {
          final expired = _buildSession(
            clock: clock,
            expiresIn: const Duration(seconds: -30),
            refreshToken: null,
          );
          sessionStore = FakeSessionStore(initial: expired);

          final container = buildContainer();
          await container.read(authControllerProvider.notifier).initialize();

          expect(container.read(authControllerProvider), isA<Expired>());
          verifyNever(() => backend.refresh(any()));
        },
      );

      test(
        'a thrown error from the store degrades to unauthenticated',
        () async {
          final container = ProviderContainer(
            overrides: [
              authBackendProvider.overrideWithValue(backend),
              clockProvider.overrideWithValue(clock),
              sessionStoreProvider.overrideWithValue(ThrowingSessionStore()),
              timerFactoryProvider.overrideWithValue(timerFactory.call),
              loggerProvider.overrideWithValue(
                ConsoleLogger(clock: clock, sink: logLines.add),
              ),
            ],
          );
          addTearDown(container.dispose);

          await container.read(authControllerProvider.notifier).initialize();

          expect(
            container.read(authControllerProvider),
            isA<Unauthenticated>(),
          );
          expect(logLines.any((l) => l.contains('"level":"error"')), isTrue);
        },
      );
    });

    group('login', () {
      test(
        'interactive login success becomes authenticated and persists session',
        () async {
          final session = _buildSession(clock: clock);
          when(
            () => backend.login(any()),
          ).thenAnswer((_) async => Result.ok(session));

          final container = buildContainer();
          final controller = container.read(authControllerProvider.notifier);

          final result = await controller.login(
            const LoginRequest.interactive(),
          );

          expect(result.isOk, isTrue);
          final state = container.read(authControllerProvider);
          expect(state, isA<Authenticated>());
          expect(
            (state as Authenticated).session.accessToken,
            session.accessToken,
          );
          expect(sessionStore.stored?.accessToken, session.accessToken);
          expect(timerFactory.calls, hasLength(1));
        },
      );

      test('failed login restores prior Unauthenticated state', () async {
        when(() => backend.login(any())).thenAnswer(
          (_) async => Result.err(AuthFailure(401, 'Login was cancelled')),
        );

        final container = buildContainer();
        final controller = container.read(authControllerProvider.notifier);
        await controller.initialize(); // -> Unauthenticated

        final result = await controller.login(const LoginRequest.interactive());

        expect(result.isOk, isFalse);
        result.fold((_) {}, (failure) => expect(failure, isA<AuthFailure>()));
        expect(container.read(authControllerProvider), isA<Unauthenticated>());
      });

      test(
        'failed re-login does not corrupt an existing authenticated session',
        () async {
          final existing = _buildSession(clock: clock, sub: 'existing-user');
          sessionStore = FakeSessionStore(initial: existing);
          when(() => backend.login(any())).thenAnswer(
            (_) async => Result.err(AuthFailure(null, 'Login was cancelled')),
          );

          final container = buildContainer();
          final controller = container.read(authControllerProvider.notifier);
          await controller.initialize(); // -> Authenticated(existing)

          final result = await controller.login(
            const LoginRequest.interactive(),
          );

          expect(result.isOk, isFalse);
          final state = container.read(authControllerProvider);
          expect(state, isA<Authenticated>());
          expect(
            (state as Authenticated).session.accessToken,
            existing.accessToken,
          );
        },
      );

      test(
        'login exception restores prior state and returns a failure',
        () async {
          when(() => backend.login(any())).thenThrow(StateError('boom'));

          final container = buildContainer();
          final controller = container.read(authControllerProvider.notifier);
          await controller.initialize();

          final result = await controller.login(
            const LoginRequest.interactive(),
          );

          expect(result.isOk, isFalse);
          expect(
            container.read(authControllerProvider),
            isA<Unauthenticated>(),
          );
        },
      );
    });

    group('logout', () {
      test(
        'calls backend logout then clears store and notifies unauthenticated',
        () async {
          final session = _buildSession(clock: clock);
          sessionStore = FakeSessionStore(initial: session);
          when(
            () => backend.logout(any()),
          ).thenAnswer((_) async => const Result.ok(null));

          final container = buildContainer();
          final controller = container.read(authControllerProvider.notifier);
          await controller.initialize();

          final events = <AuthEvent>[];
          final sub = controller.events.listen(events.add);

          await controller.logout();
          await flushMicrotasks(); // let the broadcast stream deliver the event

          expect(
            container.read(authControllerProvider),
            isA<Unauthenticated>(),
          );
          expect(sessionStore.stored, isNull);
          verify(() => backend.logout(any())).called(1);
          expect(events, contains(AuthEvent.unauthenticated));
          await sub.cancel();
        },
      );

      test(
        'still clears the store and logs a WARN when backend logout fails',
        () async {
          final session = _buildSession(clock: clock);
          sessionStore = FakeSessionStore(initial: session);
          when(
            () => backend.logout(any()),
          ).thenAnswer((_) async => Result.err(NetworkFailure('unreachable')));

          final container = buildContainer();
          final controller = container.read(authControllerProvider.notifier);
          await controller.initialize();
          await controller.logout();

          expect(
            container.read(authControllerProvider),
            isA<Unauthenticated>(),
          );
          expect(sessionStore.stored, isNull);
          expect(logLines.any((l) => l.contains('"level":"warn"')), isTrue);
        },
      );

      test(
        'still clears the store and logs a WARN when backend logout throws',
        () async {
          final session = _buildSession(clock: clock);
          sessionStore = FakeSessionStore(initial: session);
          when(() => backend.logout(any())).thenThrow(Exception('boom'));

          final container = buildContainer();
          final controller = container.read(authControllerProvider.notifier);
          await controller.initialize();
          await controller.logout();

          expect(
            container.read(authControllerProvider),
            isA<Unauthenticated>(),
          );
          expect(sessionStore.stored, isNull);
          expect(logLines.any((l) => l.contains('"level":"warn"')), isTrue);
        },
      );

      test('no tokens appear in any emitted log line', () async {
        final session = _buildSession(clock: clock);
        sessionStore = FakeSessionStore(initial: session);
        when(
          () => backend.logout(any()),
        ).thenAnswer((_) async => Result.err(NetworkFailure('unreachable')));

        final container = buildContainer();
        final controller = container.read(authControllerProvider.notifier);
        await controller.initialize();
        await controller.logout();

        expect(logLines, isNotEmpty);
        for (final line in logLines) {
          expect(line.contains(session.accessToken), isFalse);
          expect(line.contains(session.refreshToken!), isFalse);
        }
      });
    });

    group('TokenProvider', () {
      test(
        'accessToken returns the current token, null when unauthenticated',
        () async {
          final session = _buildSession(clock: clock);
          sessionStore = FakeSessionStore(initial: session);
          final container = buildContainer();
          final controller = container.read(authControllerProvider.notifier);

          await controller.initialize();
          expect(await controller.accessToken(), session.accessToken);

          await controller.logout();
          expect(await controller.accessToken(), isNull);
        },
      );

      test('refresh() returns false with no authenticated session', () async {
        final container = buildContainer();
        final controller = container.read(authControllerProvider.notifier);
        await controller.initialize(); // empty store -> Unauthenticated

        expect(await controller.refresh(), isFalse);
        verifyNever(() => backend.refresh(any()));
      });

      test('refresh() success emits AuthEvent.refreshed', () async {
        final session = _buildSession(clock: clock);
        sessionStore = FakeSessionStore(initial: session);
        final refreshed = _buildSession(
          clock: clock,
          expiresIn: const Duration(hours: 3),
        );
        when(
          () => backend.refresh(any()),
        ).thenAnswer((_) async => Result.ok(refreshed));

        final container = buildContainer();
        final controller = container.read(authControllerProvider.notifier);
        await controller.initialize();

        final events = <AuthEvent>[];
        final sub = controller.events.listen(events.add);

        final ok = await controller.refresh();
        await flushMicrotasks(); // let the broadcast stream deliver the event

        expect(ok, isTrue);
        expect(events, [AuthEvent.refreshed]);
        await sub.cancel();
      });

      test(
        'refresh() failure emits AuthEvent.unauthenticated and expires',
        () async {
          final session = _buildSession(clock: clock);
          sessionStore = FakeSessionStore(initial: session);
          when(() => backend.refresh(any())).thenAnswer(
            (_) async => Result.err(AuthFailure(401, 'invalid_grant')),
          );

          final container = buildContainer();
          final controller = container.read(authControllerProvider.notifier);
          await controller.initialize();

          final events = <AuthEvent>[];
          final sub = controller.events.listen(events.add);

          final ok = await controller.refresh();
          await flushMicrotasks(); // let the broadcast stream deliver the event

          expect(ok, isFalse);
          expect(container.read(authControllerProvider), isA<Expired>());
          expect(events, [AuthEvent.unauthenticated]);
          await sub.cancel();
        },
      );

      test(
        'refresh() backend throwing still expires and emits unauthenticated',
        () async {
          final session = _buildSession(clock: clock);
          sessionStore = FakeSessionStore(initial: session);
          when(() => backend.refresh(any())).thenThrow(StateError('boom'));

          final container = buildContainer();
          final controller = container.read(authControllerProvider.notifier);
          await controller.initialize();

          final events = <AuthEvent>[];
          final sub = controller.events.listen(events.add);

          final ok = await controller.refresh();
          await flushMicrotasks();

          expect(ok, isFalse);
          expect(container.read(authControllerProvider), isA<Expired>());
          expect(events, [AuthEvent.unauthenticated]);
          await sub.cancel();
        },
      );
    });

    group('scheduled refresh', () {
      test(
        'schedules a timer at exp - 60s and firing it triggers a refresh',
        () async {
          final session = _buildSession(
            clock: clock,
            expiresIn: const Duration(seconds: 120),
          );
          sessionStore = FakeSessionStore(initial: session);
          final refreshed = _buildSession(
            clock: clock,
            expiresIn: const Duration(hours: 1),
          );
          when(
            () => backend.refresh(any()),
          ).thenAnswer((_) async => Result.ok(refreshed));

          final container = buildContainer();
          await container.read(authControllerProvider.notifier).initialize();

          expect(timerFactory.calls, hasLength(1));
          expect(timerFactory.last!.duration, const Duration(seconds: 60));
          expect(timerFactory.last!.timer.isActive, isTrue);

          await timerFactory.fireLast();
          await flushMicrotasks();

          verify(() => backend.refresh(any())).called(1);
          expect(container.read(authControllerProvider), isA<Authenticated>());
        },
      );

      test(
        'fires immediately (zero delay) when the deadline already passed',
        () async {
          // exp - 60s is already in the past.
          final session = _buildSession(
            clock: clock,
            expiresIn: const Duration(seconds: 30),
          );
          sessionStore = FakeSessionStore(initial: session);
          when(() => backend.refresh(any())).thenAnswer(
            (_) async => Result.ok(
              _buildSession(clock: clock, expiresIn: const Duration(hours: 1)),
            ),
          );

          final container = buildContainer();
          await container.read(authControllerProvider.notifier).initialize();

          expect(timerFactory.calls, hasLength(1));
          expect(timerFactory.last!.duration, Duration.zero);
        },
      );

      test('logout cancels the pending scheduled timer', () async {
        final session = _buildSession(
          clock: clock,
          expiresIn: const Duration(seconds: 120),
        );
        sessionStore = FakeSessionStore(initial: session);
        when(
          () => backend.logout(any()),
        ).thenAnswer((_) async => const Result.ok(null));

        final container = buildContainer();
        final controller = container.read(authControllerProvider.notifier);
        await controller.initialize();

        final scheduled = timerFactory.last!;
        expect(scheduled.timer.isActive, isTrue);

        await controller.logout();

        expect(scheduled.timer.isActive, isFalse);
      });
    });

    group('race conditions and coalescing', () {
      test(
        'a refresh in flight when logout() runs never resurrects the session',
        () async {
          final session = _buildSession(clock: clock);
          sessionStore = FakeSessionStore(initial: session);

          final refreshCompleter = Completer<Result<Session>>();
          when(
            () => backend.refresh(any()),
          ).thenAnswer((_) => refreshCompleter.future);
          when(
            () => backend.logout(any()),
          ).thenAnswer((_) async => const Result.ok(null));

          final container = buildContainer();
          final controller = container.read(authControllerProvider.notifier);
          await controller.initialize();
          expect(container.read(authControllerProvider), isA<Authenticated>());

          // Start a refresh but do not await it — it suspends on
          // backend.refresh(), which we control via refreshCompleter.
          final refreshFuture = controller.refresh();

          // The user logs out while that refresh is still in flight.
          await controller.logout();
          expect(
            container.read(authControllerProvider),
            isA<Unauthenticated>(),
          );
          expect(sessionStore.stored, isNull);

          // The stale refresh now completes successfully — its result
          // must be discarded; logout() already won.
          final staleSession = _buildSession(
            clock: clock,
            expiresIn: const Duration(hours: 2),
          );
          refreshCompleter.complete(Result.ok(staleSession));
          final refreshed = await refreshFuture;

          expect(refreshed, isFalse);
          expect(
            container.read(authControllerProvider),
            isA<Unauthenticated>(),
          );
          expect(sessionStore.stored, isNull);
        },
      );

      test(
        'a refresh in flight when login() runs never resurrects the old session',
        () async {
          final oldSession = _buildSession(clock: clock, sub: 'old-user');
          sessionStore = FakeSessionStore(initial: oldSession);

          final refreshCompleter = Completer<Result<Session>>();
          when(
            () => backend.refresh(any()),
          ).thenAnswer((_) => refreshCompleter.future);

          final newSession = _buildSession(clock: clock, sub: 'new-user');
          when(
            () => backend.login(any()),
          ).thenAnswer((_) async => Result.ok(newSession));

          final container = buildContainer();
          final controller = container.read(authControllerProvider.notifier);
          await controller.initialize();

          final refreshFuture = controller.refresh();

          final loginResult = await controller.login(
            const LoginRequest.interactive(),
          );
          expect(loginResult.isOk, isTrue);
          expect(
            (container.read(authControllerProvider) as Authenticated)
                .session
                .accessToken,
            newSession.accessToken,
          );

          // The superseded refresh (for the OLD session) completes after
          // the new login already replaced it — it must not overwrite the
          // freshly logged-in session.
          final staleSession = _buildSession(
            clock: clock,
            sub: 'old-user',
            expiresIn: const Duration(hours: 2),
          );
          refreshCompleter.complete(Result.ok(staleSession));
          final refreshed = await refreshFuture;

          expect(refreshed, isFalse);
          expect(
            (container.read(authControllerProvider) as Authenticated)
                .session
                .accessToken,
            newSession.accessToken,
          );
          expect(sessionStore.stored?.accessToken, newSession.accessToken);
        },
      );

      test(
        'concurrent refresh() calls share one backend call and result',
        () async {
          final session = _buildSession(clock: clock);
          sessionStore = FakeSessionStore(initial: session);

          final refreshCompleter = Completer<Result<Session>>();
          when(
            () => backend.refresh(any()),
          ).thenAnswer((_) => refreshCompleter.future);

          final container = buildContainer();
          final controller = container.read(authControllerProvider.notifier);
          await controller.initialize();

          final first = controller.refresh();
          final second = controller.refresh();

          final refreshedSession = _buildSession(
            clock: clock,
            expiresIn: const Duration(hours: 2),
          );
          refreshCompleter.complete(Result.ok(refreshedSession));

          final results = await Future.wait([first, second]);

          expect(results, [isTrue, isTrue]);
          verify(() => backend.refresh(any())).called(1);
          expect(container.read(authControllerProvider), isA<Authenticated>());
        },
      );

      test(
        'a second refresh burst after the first settles calls the backend again',
        () async {
          final session = _buildSession(clock: clock);
          sessionStore = FakeSessionStore(initial: session);

          var calls = 0;
          when(() => backend.refresh(any())).thenAnswer((_) async {
            calls++;
            return Result.ok(
              _buildSession(clock: clock, expiresIn: const Duration(hours: 2)),
            );
          });

          final container = buildContainer();
          final controller = container.read(authControllerProvider.notifier);
          await controller.initialize();

          await controller.refresh();
          await controller.refresh();

          expect(calls, 2);
        },
      );

      test(
        'HostedLoginBackend endSession failure still clears the store and warns',
        () async {
          final session = _buildSession(clock: clock);
          sessionStore = FakeSessionStore(initial: session);

          final fakeFacade = FakeAppAuthFacade()..endSessionResult = false;
          final hostedConfig = AuthConfig.hosted(
            issuer: Uri.parse('https://auth.example.com'),
            clientId: 'app-client',
            redirectUri: 'io.penguintech.app://oauth/callback',
            endSessionEndpoint: Uri.parse('https://auth.example.com/logout'),
          );
          final hostedBackend = HostedLoginBackend(
            hostedConfig,
            appAuth: fakeFacade,
            clock: clock,
          );

          final container = ProviderContainer(
            overrides: [
              authBackendProvider.overrideWithValue(hostedBackend),
              clockProvider.overrideWithValue(clock),
              sessionStoreProvider.overrideWithValue(sessionStore),
              timerFactoryProvider.overrideWithValue(timerFactory.call),
              loggerProvider.overrideWithValue(
                ConsoleLogger(clock: clock, sink: logLines.add),
              ),
            ],
          );
          addTearDown(container.dispose);

          final controller = container.read(authControllerProvider.notifier);
          await controller.initialize();
          await controller.logout();

          expect(
            container.read(authControllerProvider),
            isA<Unauthenticated>(),
          );
          expect(sessionStore.stored, isNull);
          expect(logLines.any((l) => l.contains('"level":"warn"')), isTrue);
        },
      );

      test(
        'a login in flight when logout() runs never resurrects the session',
        () async {
          final existing = _buildSession(clock: clock, sub: 'existing-user');
          sessionStore = FakeSessionStore(initial: existing);

          final loginCompleter = Completer<Result<Session>>();
          when(
            () => backend.login(any()),
          ).thenAnswer((_) => loginCompleter.future);
          when(
            () => backend.logout(any()),
          ).thenAnswer((_) async => const Result.ok(null));

          final container = buildContainer();
          final controller = container.read(authControllerProvider.notifier);
          await controller.initialize();
          expect(container.read(authControllerProvider), isA<Authenticated>());

          // Start a re-login but don't await it — it suspends on
          // backend.login(), which we control via loginCompleter.
          final loginFuture = controller.login(
            const LoginRequest.interactive(),
          );

          // The user logs out while that login attempt is still in flight.
          await controller.logout();
          expect(
            container.read(authControllerProvider),
            isA<Unauthenticated>(),
          );
          expect(sessionStore.stored, isNull);
          final timerCallsAfterLogout = timerFactory.calls.length;

          // The stale login now completes successfully — its result must
          // be discarded; logout() already won.
          final staleSession = _buildSession(clock: clock, sub: 'stale-user');
          loginCompleter.complete(Result.ok(staleSession));
          final loginResult = await loginFuture;

          expect(loginResult.isOk, isFalse);
          expect(
            container.read(authControllerProvider),
            isA<Unauthenticated>(),
          );
          expect(sessionStore.stored, isNull);
          // No new refresh timer was scheduled for the discarded session.
          expect(timerFactory.calls.length, timerCallsAfterLogout);
        },
      );

      test('a login that throws after being superseded is discarded without '
          'restoring stale state', () async {
        final existing = _buildSession(clock: clock, sub: 'existing-user');
        sessionStore = FakeSessionStore(initial: existing);

        final loginCompleter = Completer<Result<Session>>();
        when(
          () => backend.login(any()),
        ).thenAnswer((_) => loginCompleter.future);
        when(
          () => backend.logout(any()),
        ).thenAnswer((_) async => const Result.ok(null));

        final container = buildContainer();
        final controller = container.read(authControllerProvider.notifier);
        await controller.initialize();

        final loginFuture = controller.login(const LoginRequest.interactive());
        await controller.logout();
        expect(container.read(authControllerProvider), isA<Unauthenticated>());

        loginCompleter.completeError(StateError('boom'));
        final loginResult = await loginFuture;

        expect(loginResult.isOk, isFalse);
        if (loginResult case Err(:final failure)) {
          expect(failure, isA<UnknownFailure>());
        }
        // Must still reflect logout()'s outcome, not be reverted to
        // whatever login() snapshotted as its "previous" state.
        expect(container.read(authControllerProvider), isA<Unauthenticated>());
      });

      test('a new-generation refresh() starts its own backend call instead of '
          'joining a doomed one', () async {
        final session = _buildSession(clock: clock);
        sessionStore = FakeSessionStore(initial: session);

        final firstRefreshCompleter = Completer<Result<Session>>();
        final secondSession = _buildSession(
          clock: clock,
          sub: 'second-refresh',
          expiresIn: const Duration(hours: 3),
        );
        var refreshCalls = 0;
        when(() => backend.refresh(any())).thenAnswer((_) {
          refreshCalls++;
          if (refreshCalls == 1) return firstRefreshCompleter.future;
          return Future.value(Result.ok(secondSession));
        });

        final newLoginSession = _buildSession(
          clock: clock,
          sub: 'new-login-user',
        );
        when(
          () => backend.login(any()),
        ).thenAnswer((_) async => Result.ok(newLoginSession));

        final container = buildContainer();
        final controller = container.read(authControllerProvider.notifier);
        await controller.initialize();

        // Refresh A starts in generation 1 and stays pending.
        final refreshA = controller.refresh();
        expect(refreshCalls, 1);

        // login() bumps to generation 2 and replaces the session.
        final loginResult = await controller.login(
          const LoginRequest.interactive(),
        );
        expect(loginResult.isOk, isTrue);

        // A refresh() call now, in generation 2, must NOT just return
        // refreshA's doomed future — it must make its own backend call.
        final refreshB = controller.refresh();
        expect(refreshCalls, 2);

        final resultB = await refreshB;
        expect(resultB, isTrue);
        expect(
          (container.read(authControllerProvider) as Authenticated)
              .session
              .accessToken,
          secondSession.accessToken,
        );

        // Finish off refreshA — it's stale and must be discarded with no
        // side effects, leaving refreshB's session in place.
        firstRefreshCompleter.complete(
          Result.ok(_buildSession(clock: clock, sub: 'stale-refresh')),
        );
        final resultA = await refreshA;
        expect(resultA, isFalse);
        expect(
          (container.read(authControllerProvider) as Authenticated)
              .session
              .accessToken,
          secondSession.accessToken,
        );
      });

      test(
        'a stale refresh undoes its own write if superseded during the save',
        () async {
          final session = _buildSession(clock: clock);
          sessionStore = FakeSessionStore(initial: session);
          final refreshedSession = _buildSession(
            clock: clock,
            expiresIn: const Duration(hours: 2),
          );
          when(
            () => backend.refresh(any()),
          ).thenAnswer((_) async => Result.ok(refreshedSession));
          when(
            () => backend.logout(any()),
          ).thenAnswer((_) async => const Result.ok(null));

          final container = buildContainer();
          final controller = container.read(authControllerProvider.notifier);
          await controller.initialize();

          final pauseCompleter = sessionStore.pauseNextSave();
          final refreshFuture = controller.refresh();

          // Let backend.refresh() resolve and _refreshSession reach (and
          // suspend on) the paused save.
          await flushMicrotasks();

          // logout() runs to completion entirely while the refresh's save
          // is still paused.
          await controller.logout();
          expect(sessionStore.stored, isNull);

          // Now let the stale save proceed — without the post-save
          // re-check, this would leave the superseded session in storage
          // even though the user already logged out.
          pauseCompleter.complete();
          final refreshed = await refreshFuture;

          expect(refreshed, isFalse);
          expect(
            container.read(authControllerProvider),
            isA<Unauthenticated>(),
          );
          expect(sessionStore.stored, isNull);
        },
      );

      test(
        'a stale login undoes its own write if superseded during the save',
        () async {
          final newSession = _buildSession(clock: clock, sub: 'new-user');
          when(
            () => backend.login(any()),
          ).thenAnswer((_) async => Result.ok(newSession));

          final container = buildContainer();
          final controller = container.read(authControllerProvider.notifier);
          await controller.initialize();

          final pauseCompleter = sessionStore.pauseNextSave();
          final loginFuture = controller.login(
            const LoginRequest.interactive(),
          );

          await flushMicrotasks();

          // logout() runs to completion while the login's save is still
          // paused. At this point `state` is `Authenticating` (not
          // `Authenticated`), so logout() finds no session to call the
          // backend with and skips that step — but it still applies its
          // local effects (state/store/timer) immediately, which is what
          // supersedes this login.
          await controller.logout();

          pauseCompleter.complete();
          final loginResult = await loginFuture;

          expect(loginResult.isOk, isFalse);
          expect(
            container.read(authControllerProvider),
            isA<Unauthenticated>(),
          );
          expect(sessionStore.stored, isNull);
        },
      );

      test('a slow backend logout cannot clobber a session logged into '
          'afterwards', () async {
        final oldSession = _buildSession(clock: clock, sub: 'old-user');
        sessionStore = FakeSessionStore(initial: oldSession);

        final backendLogoutCompleter = Completer<Result<void>>();
        when(
          () => backend.logout(any()),
        ).thenAnswer((_) => backendLogoutCompleter.future);

        final newSession = _buildSession(clock: clock, sub: 'new-user');
        when(
          () => backend.login(any()),
        ).thenAnswer((_) async => Result.ok(newSession));

        final container = buildContainer();
        final controller = container.read(authControllerProvider.notifier);
        await controller.initialize();
        expect(container.read(authControllerProvider), isA<Authenticated>());

        // logout() applies its local effects synchronously and then
        // suspends on the (held-open) backend call.
        final logoutFuture = controller.logout();
        await flushMicrotasks();
        expect(container.read(authControllerProvider), isA<Unauthenticated>());
        expect(sessionStore.stored, isNull);

        // The user logs into a new session while the old logout's
        // backend call is still pending.
        final loginResult = await controller.login(
          const LoginRequest.interactive(),
        );
        expect(loginResult.isOk, isTrue);
        final timerCallsAfterLogin = timerFactory.calls.length;
        expect(timerCallsAfterLogin, greaterThan(0));

        // The old, slow backend logout now finally resolves.
        backendLogoutCompleter.complete(const Result.ok(null));
        await logoutFuture;

        // The new session's state, stored session, and refresh timer
        // must all still be intact — untouched by the stale logout.
        final state = container.read(authControllerProvider);
        expect(state, isA<Authenticated>());
        expect(
          (state as Authenticated).session.accessToken,
          newSession.accessToken,
        );
        expect(sessionStore.stored?.accessToken, newSession.accessToken);
        expect(timerFactory.calls.length, timerCallsAfterLogin);
        expect(timerFactory.calls.last.timer.isActive, isTrue);
      });

      test('initialize() superseded by logout() during the load discards its '
          'result', () async {
        final storedSession = _buildSession(clock: clock);
        sessionStore = FakeSessionStore(initial: storedSession);
        when(
          () => backend.logout(any()),
        ).thenAnswer((_) async => const Result.ok(null));

        final container = buildContainer();
        final controller = container.read(authControllerProvider.notifier);

        final pauseCompleter = sessionStore.pauseNextLoad();
        final initFuture = controller.initialize();

        await flushMicrotasks();

        // logout() runs to completion while initialize()'s load() is
        // still suspended.
        await controller.logout();
        expect(container.read(authControllerProvider), isA<Unauthenticated>());
        expect(sessionStore.stored, isNull);

        // The paused load() now resolves — with the session it had
        // already snapshotted before logout() ran, per a real read that
        // fetched its data before a concurrent write landed.
        pauseCompleter.complete();
        await initFuture;

        // initialize()'s stale result must be discarded entirely: no
        // resurrected state, and no refresh timer scheduled for a
        // session the app already logged out of.
        expect(container.read(authControllerProvider), isA<Unauthenticated>());
        expect(timerFactory.calls, isEmpty);
        expect(sessionStore.stored, isNull);
      });

      test('initialize() superseded by login() during the load discards its '
          'result', () async {
        final storedSession = _buildSession(clock: clock, sub: 'stored-user');
        sessionStore = FakeSessionStore(initial: storedSession);

        final newSession = _buildSession(clock: clock, sub: 'new-user');
        when(
          () => backend.login(any()),
        ).thenAnswer((_) async => Result.ok(newSession));

        final container = buildContainer();
        final controller = container.read(authControllerProvider.notifier);

        final pauseCompleter = sessionStore.pauseNextLoad();
        final initFuture = controller.initialize();

        await flushMicrotasks();

        final loginResult = await controller.login(
          const LoginRequest.interactive(),
        );
        expect(loginResult.isOk, isTrue);

        // The paused load() now resolves with the (now stale) session
        // it had already snapshotted before the login landed.
        pauseCompleter.complete();
        await initFuture;

        // The login's session must stand — untouched by the stale
        // initialize().
        final state = container.read(authControllerProvider);
        expect(state, isA<Authenticated>());
        expect(
          (state as Authenticated).session.accessToken,
          newSession.accessToken,
        );
        expect(sessionStore.stored?.accessToken, newSession.accessToken);
      });
    });
  });
}
