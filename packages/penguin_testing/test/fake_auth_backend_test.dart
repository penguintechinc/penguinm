import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_testing/penguin_testing.dart';

Session _session(String sub) {
  return Session(
    accessToken: 'access-$sub',
    refreshToken: 'refresh-$sub',
    expiresAt: DateTime.utc(2026, 12),
    claims: JwtClaims.fromJson(<String, dynamic>{'sub': sub}),
  );
}

void main() {
  group('FakeAuthBackend', () {
    test(
      'login returns the next queued result and records the request',
      () async {
        final backend = FakeAuthBackend();
        final session = _session('user-0001');
        backend.queueLogin(Result.ok(session));

        const request = LoginRequest.interactive();
        final result = await backend.login(request);

        expect(result.isOk, isTrue);
        expect(result.valueOrNull, session);
        expect(backend.loginRequests, [request]);
      },
    );

    test('login throws when no result is queued', () async {
      final backend = FakeAuthBackend();
      await expectLater(
        () => backend.login(const LoginRequest.interactive()),
        throwsStateError,
      );
    });

    test('login drains queued results in FIFO order', () async {
      final backend = FakeAuthBackend();
      final first = _session('user-0001');
      final second = _session('user-0002');
      backend.queueLogin(Result.ok(first));
      backend.queueLogin(Result.ok(second));

      final firstResult = await backend.login(const LoginRequest.interactive());
      final secondResult = await backend.login(
        const LoginRequest.interactive(),
      );

      expect(firstResult.valueOrNull, first);
      expect(secondResult.valueOrNull, second);
    });

    test('refresh returns the queued result and records the session', () async {
      final backend = FakeAuthBackend();
      final oldSession = _session('user-0001');
      final refreshed = _session('user-0001');
      backend.queueRefresh(Result.ok(refreshed));

      final result = await backend.refresh(oldSession);

      expect(result.valueOrNull, refreshed);
      expect(backend.refreshedSessions, [oldSession]);
    });

    test('refresh throws when no result is queued', () async {
      final backend = FakeAuthBackend();
      await expectLater(
        () => backend.refresh(_session('user-0001')),
        throwsStateError,
      );
    });

    test('refresh can be scripted to fail', () async {
      final backend = FakeAuthBackend();
      backend.queueRefresh(
        const Result.err(AuthFailure(401, 'refresh token expired')),
      );
      final result = await backend.refresh(_session('user-0001'));
      expect(result.isOk, isFalse);
    });

    test('logout defaults to ok(null) when nothing is queued', () async {
      final backend = FakeAuthBackend();
      final session = _session('user-0001');
      final result = await backend.logout(session);
      expect(result.isOk, isTrue);
      expect(backend.loggedOutSessions, [session]);
    });

    test('logout returns the queued result when scripted', () async {
      final backend = FakeAuthBackend();
      backend.queueLogout(const Result.err(NetworkFailure('offline')));
      final result = await backend.logout(_session('user-0001'));
      expect(result.isOk, isFalse);
    });
  });
}
