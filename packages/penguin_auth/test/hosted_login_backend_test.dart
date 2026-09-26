import 'dart:convert';
import 'package:flutter_appauth/flutter_appauth.dart' as appauth;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_auth/src/hosted_login_backend.dart'
    show externalUserAgentFor, normalizeScopes;
import 'package:penguin_core/penguin_core.dart';
import 'support/fake_clock.dart';
import 'support/jwt_test_utils.dart';

class MockAppAuthFacade extends Mock implements AppAuthFacade {}

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  group('HostedLoginBackend', () {
    late MockAppAuthFacade mockAppAuth;
    late MockHttpClient mockClient;
    late FakeClock clock;

    setUp(() {
      mockAppAuth = MockAppAuthFacade();
      mockClient = MockHttpClient();
      clock = FakeClock(startTime: DateTime(2024, 1, 1));
    });

    testWidgets('login: interactive flow returns session on success', (
      tester,
    ) async {
      final expiresAt = clock.now().add(const Duration(hours: 1));
      final jwt = buildTestJwt({
        'sub': 'user-123',
        'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
      });
      when(
        () => mockAppAuth.authorizeAndExchangeCode(
          clientId: any(named: 'clientId'),
          redirectUrl: any(named: 'redirectUrl'),
          authorizationEndpoint: any(named: 'authorizationEndpoint'),
          tokenEndpoint: any(named: 'tokenEndpoint'),
          scopes: any(named: 'scopes'),
          preferEphemeralSession: any(named: 'preferEphemeralSession'),
        ),
      ).thenAnswer(
        (_) async => (
          accessToken: jwt,
          refreshToken: 'refresh-token-123',
          accessTokenExpirationDateTime: expiresAt,
        ),
      );

      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
        authorizationEndpoint: Uri.parse('https://auth.example.com/authorize'),
        tokenEndpoint: Uri.parse('https://auth.example.com/token'),
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
      );

      final result = await backend.login(LoginRequest.interactive());

      expect(result.isOk, isTrue);
      final session = result.valueOrNull!;
      expect(session.accessToken, jwt);
      expect(session.refreshToken, 'refresh-token-123');
      expect(session.expiresAt, expiresAt);

      // Explicit endpoints were given, so the facade must receive them
      // directly rather than triggering another discovery round-trip.
      verify(
        () => mockAppAuth.authorizeAndExchangeCode(
          clientId: 'app-client',
          redirectUrl: 'io.penguintech.app://oauth/callback',
          authorizationEndpoint: Uri.parse(
            'https://auth.example.com/authorize',
          ),
          tokenEndpoint: Uri.parse('https://auth.example.com/token'),
          scopes: any(named: 'scopes'),
          preferEphemeralSession: false,
        ),
      ).called(1);
      verifyNever(() => mockClient.get(any()));
    });

    testWidgets('login: uses discovery when endpoints are null', (
      tester,
    ) async {
      when(() => mockClient.get(any())).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'authorization_endpoint': 'https://auth.example.com/authorize',
            'token_endpoint': 'https://auth.example.com/token',
            'end_session_endpoint': 'https://auth.example.com/logout',
          }),
          200,
        ),
      );

      final expiresAt = clock.now().add(const Duration(hours: 1));
      final jwt = buildTestJwt({
        'sub': 'user-123',
        'exp': expiresAt.millisecondsSinceEpoch ~/ 1000,
      });
      when(
        () => mockAppAuth.authorizeAndExchangeCode(
          clientId: any(named: 'clientId'),
          redirectUrl: any(named: 'redirectUrl'),
          authorizationEndpoint: any(named: 'authorizationEndpoint'),
          tokenEndpoint: any(named: 'tokenEndpoint'),
          scopes: any(named: 'scopes'),
          preferEphemeralSession: any(named: 'preferEphemeralSession'),
        ),
      ).thenAnswer(
        (_) async => (
          accessToken: jwt,
          refreshToken: 'refresh-token-123',
          accessTokenExpirationDateTime: expiresAt,
        ),
      );

      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
        // No explicit endpoints; discovery will be used.
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
        client: mockClient,
      );

      final result = await backend.login(LoginRequest.interactive());

      expect(result.isOk, isTrue);
      verify(
        () => mockClient.get(
          Uri.parse(
            'https://auth.example.com/.well-known/openid-configuration',
          ),
        ),
      ).called(1);
      // The endpoints discovery resolved must be what the facade receives.
      verify(
        () => mockAppAuth.authorizeAndExchangeCode(
          clientId: 'app-client',
          redirectUrl: 'io.penguintech.app://oauth/callback',
          authorizationEndpoint: Uri.parse(
            'https://auth.example.com/authorize',
          ),
          tokenEndpoint: Uri.parse('https://auth.example.com/token'),
          scopes: any(named: 'scopes'),
          preferEphemeralSession: false,
        ),
      ).called(1);
    });

    testWidgets('login: discovery failure propagates as a failure', (
      tester,
    ) async {
      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => http.Response('not found', 404));

      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
        client: mockClient,
      );

      final result = await backend.login(LoginRequest.interactive());

      expect(result.isOk, isFalse);
      verifyNever(
        () => mockAppAuth.authorizeAndExchangeCode(
          clientId: any(named: 'clientId'),
          redirectUrl: any(named: 'redirectUrl'),
          authorizationEndpoint: any(named: 'authorizationEndpoint'),
          tokenEndpoint: any(named: 'tokenEndpoint'),
          scopes: any(named: 'scopes'),
          preferEphemeralSession: any(named: 'preferEphemeralSession'),
        ),
      );
    });

    testWidgets('login: handles cancellation (empty result)', (tester) async {
      when(
        () => mockAppAuth.authorizeAndExchangeCode(
          clientId: any(named: 'clientId'),
          redirectUrl: any(named: 'redirectUrl'),
          authorizationEndpoint: any(named: 'authorizationEndpoint'),
          tokenEndpoint: any(named: 'tokenEndpoint'),
          scopes: any(named: 'scopes'),
          preferEphemeralSession: any(named: 'preferEphemeralSession'),
        ),
      ).thenAnswer(
        (_) async => (
          accessToken: null,
          refreshToken: null,
          accessTokenExpirationDateTime: null,
        ),
      );

      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
        authorizationEndpoint: Uri.parse('https://auth.example.com/authorize'),
        tokenEndpoint: Uri.parse('https://auth.example.com/token'),
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
      );

      final result = await backend.login(LoginRequest.interactive());

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<AuthFailure>());
        expect(failure.message, 'Login was cancelled');
      }
    });

    testWidgets(
      'login: handles cancellation (FlutterAppAuthUserCancelledException)',
      (tester) async {
        // This is how the real flutter_appauth plugin represents
        // cancellation (see the pure-delegation FlutterAppAuthFacade
        // below the coverage:ignore marker) — HostedLoginBackend must
        // translate it the same way it handles an empty result.
        when(
          () => mockAppAuth.authorizeAndExchangeCode(
            clientId: any(named: 'clientId'),
            redirectUrl: any(named: 'redirectUrl'),
            authorizationEndpoint: any(named: 'authorizationEndpoint'),
            tokenEndpoint: any(named: 'tokenEndpoint'),
            scopes: any(named: 'scopes'),
            preferEphemeralSession: any(named: 'preferEphemeralSession'),
          ),
        ).thenThrow(
          appauth.FlutterAppAuthUserCancelledException(
            code: 'cancelled',
            platformErrorDetails: appauth.FlutterAppAuthPlatformErrorDetails(),
          ),
        );

        final config = AuthConfig.hosted(
          issuer: Uri.parse('https://auth.example.com'),
          clientId: 'app-client',
          redirectUri: 'io.penguintech.app://oauth/callback',
          authorizationEndpoint: Uri.parse(
            'https://auth.example.com/authorize',
          ),
          tokenEndpoint: Uri.parse('https://auth.example.com/token'),
        );

        final backend = HostedLoginBackend(
          config,
          appAuth: mockAppAuth,
          clock: clock,
        );

        final result = await backend.login(LoginRequest.interactive());

        expect(result.isOk, isFalse);
        if (result case Err(:final failure)) {
          expect(failure, isA<AuthFailure>());
          expect(failure.message, 'Login was cancelled');
        }
      },
    );

    testWidgets('login: non-interactive request is rejected', (tester) async {
      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
        authorizationEndpoint: Uri.parse('https://auth.example.com/authorize'),
        tokenEndpoint: Uri.parse('https://auth.example.com/token'),
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
      );

      final result = await backend.login(
        const LoginRequest.password(email: 'a@b.com', password: 'x'),
      );

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<AuthFailure>());
      }
    });

    testWidgets('refresh: uses refresh token', (tester) async {
      final jwt = buildTestJwt({
        'sub': 'user-123',
        'iss': 'https://auth.example.com',
        'aud': 'app',
        'exp':
            clock.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000,
      });
      final claims = JwtClaims.decode(jwt);

      final session = Session(
        accessToken: 'old-access-token',
        refreshToken: 'refresh-token-123',
        expiresAt: clock.now().add(const Duration(hours: 1)),
        claims: claims,
      );

      final newExpiresAt = clock.now().add(const Duration(hours: 2));
      when(
        () => mockAppAuth.token(
          clientId: any(named: 'clientId'),
          redirectUrl: any(named: 'redirectUrl'),
          refreshToken: any(named: 'refreshToken'),
          tokenEndpoint: any(named: 'tokenEndpoint'),
          scopes: any(named: 'scopes'),
        ),
      ).thenAnswer(
        (_) async => (
          accessToken: jwt,
          refreshToken: 'new-refresh-token',
          accessTokenExpirationDateTime: newExpiresAt,
        ),
      );

      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
        authorizationEndpoint: Uri.parse('https://auth.example.com/authorize'),
        tokenEndpoint: Uri.parse('https://auth.example.com/token'),
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
      );

      final result = await backend.refresh(session);

      expect(result.isOk, isTrue);
      final newSession = result.valueOrNull!;
      expect(newSession.refreshToken, 'new-refresh-token');
      verify(
        () => mockAppAuth.token(
          clientId: 'app-client',
          redirectUrl: 'io.penguintech.app://oauth/callback',
          refreshToken: 'refresh-token-123',
          tokenEndpoint: Uri.parse('https://auth.example.com/token'),
          scopes: any(named: 'scopes'),
        ),
      ).called(1);
    });

    testWidgets('refresh: keeps prior refresh token when server omits one', (
      tester,
    ) async {
      final jwt = buildTestJwt({'sub': 'user-123', 'exp': 9999999999});
      final claims = JwtClaims.decode(jwt);
      final session = Session(
        accessToken: 'old-access-token',
        refreshToken: 'refresh-token-123',
        expiresAt: clock.now().add(const Duration(hours: 1)),
        claims: claims,
      );

      when(
        () => mockAppAuth.token(
          clientId: any(named: 'clientId'),
          redirectUrl: any(named: 'redirectUrl'),
          refreshToken: any(named: 'refreshToken'),
          tokenEndpoint: any(named: 'tokenEndpoint'),
          scopes: any(named: 'scopes'),
        ),
      ).thenAnswer(
        (_) async => (
          accessToken: jwt,
          refreshToken: null,
          accessTokenExpirationDateTime: clock.now().add(
            const Duration(hours: 2),
          ),
        ),
      );

      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
        authorizationEndpoint: Uri.parse('https://auth.example.com/authorize'),
        tokenEndpoint: Uri.parse('https://auth.example.com/token'),
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
      );

      final result = await backend.refresh(session);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.refreshToken, 'refresh-token-123');
    });

    testWidgets('refresh: returns error when no refresh token', (tester) async {
      final jwt = buildTestJwt({'sub': 'user-123', 'exp': 9999999999});
      final claims = JwtClaims.decode(jwt);

      final session = Session(
        accessToken: jwt,
        refreshToken: null,
        expiresAt: clock.now().add(const Duration(hours: 1)),
        claims: claims,
      );

      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
        authorizationEndpoint: Uri.parse('https://auth.example.com/authorize'),
        tokenEndpoint: Uri.parse('https://auth.example.com/token'),
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
      );

      final result = await backend.refresh(session);

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<AuthFailure>());
      }
    });

    testWidgets('refresh: uses discovery when token endpoint is null', (
      tester,
    ) async {
      when(() => mockClient.get(any())).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'authorization_endpoint': 'https://auth.example.com/authorize',
            'token_endpoint': 'https://auth.example.com/token',
          }),
          200,
        ),
      );
      final jwt = buildTestJwt({'sub': 'user-123', 'exp': 9999999999});
      final claims = JwtClaims.decode(jwt);
      final session = Session(
        accessToken: 'old-access-token',
        refreshToken: 'refresh-token-123',
        expiresAt: clock.now().add(const Duration(hours: 1)),
        claims: claims,
      );

      when(
        () => mockAppAuth.token(
          clientId: any(named: 'clientId'),
          redirectUrl: any(named: 'redirectUrl'),
          refreshToken: any(named: 'refreshToken'),
          tokenEndpoint: any(named: 'tokenEndpoint'),
          scopes: any(named: 'scopes'),
        ),
      ).thenAnswer(
        (_) async => (
          accessToken: jwt,
          refreshToken: 'new-refresh-token',
          accessTokenExpirationDateTime: clock.now().add(
            const Duration(hours: 2),
          ),
        ),
      );

      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
        client: mockClient,
      );

      final result = await backend.refresh(session);

      expect(result.isOk, isTrue);
      verify(
        () => mockAppAuth.token(
          clientId: 'app-client',
          redirectUrl: 'io.penguintech.app://oauth/callback',
          refreshToken: 'refresh-token-123',
          tokenEndpoint: Uri.parse('https://auth.example.com/token'),
          scopes: any(named: 'scopes'),
        ),
      ).called(1);
    });

    testWidgets('logout: calls endSession when available', (tester) async {
      when(
        () => mockAppAuth.endSession(
          idTokenHint: any(named: 'idTokenHint'),
          endSessionEndpoint: any(named: 'endSessionEndpoint'),
          redirectUrl: any(named: 'redirectUrl'),
          preferEphemeralSession: any(named: 'preferEphemeralSession'),
        ),
      ).thenAnswer((_) async => true);

      final jwt = buildTestJwt({'sub': 'user-123', 'exp': 9999999999});
      final claims = JwtClaims.decode(jwt);

      final session = Session(
        accessToken: jwt,
        refreshToken: null,
        expiresAt: clock.now().add(const Duration(hours: 1)),
        claims: claims,
      );

      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
        endSessionEndpoint: Uri.parse('https://auth.example.com/logout'),
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
      );

      final result = await backend.logout(session);

      expect(result.isOk, isTrue);
      verify(
        () => mockAppAuth.endSession(
          idTokenHint: jwt,
          endSessionEndpoint: Uri.parse('https://auth.example.com/logout'),
          redirectUrl: 'io.penguintech.app://oauth/callback',
          preferEphemeralSession: false,
        ),
      ).called(1);
    });

    testWidgets('logout: skips endSession when not configured', (tester) async {
      final jwt = buildTestJwt({'sub': 'user-123', 'exp': 9999999999});
      final claims = JwtClaims.decode(jwt);

      final session = Session(
        accessToken: jwt,
        refreshToken: null,
        expiresAt: clock.now().add(const Duration(hours: 1)),
        claims: claims,
      );

      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
        // No endSessionEndpoint configured.
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
      );

      final result = await backend.logout(session);

      expect(result.isOk, isTrue);
      verifyNever(
        () => mockAppAuth.endSession(
          idTokenHint: any(named: 'idTokenHint'),
          endSessionEndpoint: any(named: 'endSessionEndpoint'),
          redirectUrl: any(named: 'redirectUrl'),
          preferEphemeralSession: any(named: 'preferEphemeralSession'),
        ),
      );
    });

    testWidgets('constructor throws for a non-hosted config', (tester) async {
      expect(
        () => HostedLoginBackend(
          AuthConfig.password(),
          appAuth: mockAppAuth,
          clock: clock,
        ),
        throwsArgumentError,
      );
    });

    testWidgets('login: appAuth throwing is an UnknownFailure', (tester) async {
      when(
        () => mockAppAuth.authorizeAndExchangeCode(
          clientId: any(named: 'clientId'),
          redirectUrl: any(named: 'redirectUrl'),
          authorizationEndpoint: any(named: 'authorizationEndpoint'),
          tokenEndpoint: any(named: 'tokenEndpoint'),
          scopes: any(named: 'scopes'),
          preferEphemeralSession: any(named: 'preferEphemeralSession'),
        ),
      ).thenThrow(Exception('platform error'));

      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
        authorizationEndpoint: Uri.parse('https://auth.example.com/authorize'),
        tokenEndpoint: Uri.parse('https://auth.example.com/token'),
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
      );
      final result = await backend.login(LoginRequest.interactive());

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<UnknownFailure>());
      }
    });

    testWidgets(
      'login: discovery succeeding but missing endpoints is a failure',
      (tester) async {
        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response(jsonEncode({'issuer': 'x'}), 200),
        );

        final config = AuthConfig.hosted(
          issuer: Uri.parse('https://auth.example.com'),
          clientId: 'app-client',
          redirectUri: 'io.penguintech.app://oauth/callback',
        );

        final backend = HostedLoginBackend(
          config,
          appAuth: mockAppAuth,
          clock: clock,
          client: mockClient,
        );

        final result = await backend.login(LoginRequest.interactive());

        expect(result.isOk, isFalse);
        if (result case Err(:final failure)) {
          expect(failure, isA<AuthFailure>());
        }
      },
    );

    testWidgets('login: falls back to a 1h expiry when the plugin omits one', (
      tester,
    ) async {
      final jwt = buildTestJwt({'sub': 'user-123', 'exp': 9999999999});
      when(
        () => mockAppAuth.authorizeAndExchangeCode(
          clientId: any(named: 'clientId'),
          redirectUrl: any(named: 'redirectUrl'),
          authorizationEndpoint: any(named: 'authorizationEndpoint'),
          tokenEndpoint: any(named: 'tokenEndpoint'),
          scopes: any(named: 'scopes'),
          preferEphemeralSession: any(named: 'preferEphemeralSession'),
        ),
      ).thenAnswer(
        (_) async => (
          accessToken: jwt,
          refreshToken: 'refresh-token-123',
          accessTokenExpirationDateTime: null,
        ),
      );

      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
        authorizationEndpoint: Uri.parse('https://auth.example.com/authorize'),
        tokenEndpoint: Uri.parse('https://auth.example.com/token'),
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
      );
      final result = await backend.login(LoginRequest.interactive());

      expect(result.isOk, isTrue);
      expect(
        result.valueOrNull!.expiresAt,
        clock.now().add(const Duration(hours: 1)),
      );
    });

    testWidgets(
      'refresh: discovery failure when token endpoint is not configured',
      (tester) async {
        when(
          () => mockClient.get(any()),
        ).thenAnswer((_) async => http.Response('not found', 404));
        final jwt = buildTestJwt({'sub': 'user-123', 'exp': 9999999999});
        final session = Session(
          accessToken: 'old-token',
          refreshToken: 'refresh-token-123',
          expiresAt: clock.now().add(const Duration(hours: 1)),
          claims: JwtClaims.decode(jwt),
        );

        final config = AuthConfig.hosted(
          issuer: Uri.parse('https://auth.example.com'),
          clientId: 'app-client',
          redirectUri: 'io.penguintech.app://oauth/callback',
        );

        final backend = HostedLoginBackend(
          config,
          appAuth: mockAppAuth,
          clock: clock,
          client: mockClient,
        );

        final result = await backend.refresh(session);

        expect(result.isOk, isFalse);
        if (result case Err(:final failure)) {
          expect(failure, isA<NetworkFailure>());
        }
      },
    );

    testWidgets(
      'refresh: discovery succeeding but missing token_endpoint is a failure',
      (tester) async {
        when(() => mockClient.get(any())).thenAnswer(
          (_) async => http.Response(jsonEncode({'issuer': 'x'}), 200),
        );
        final jwt = buildTestJwt({'sub': 'user-123', 'exp': 9999999999});
        final session = Session(
          accessToken: 'old-token',
          refreshToken: 'refresh-token-123',
          expiresAt: clock.now().add(const Duration(hours: 1)),
          claims: JwtClaims.decode(jwt),
        );

        final config = AuthConfig.hosted(
          issuer: Uri.parse('https://auth.example.com'),
          clientId: 'app-client',
          redirectUri: 'io.penguintech.app://oauth/callback',
        );

        final backend = HostedLoginBackend(
          config,
          appAuth: mockAppAuth,
          clock: clock,
          client: mockClient,
        );

        final result = await backend.refresh(session);

        expect(result.isOk, isFalse);
        if (result case Err(:final failure)) {
          expect(failure, isA<AuthFailure>());
        }
      },
    );

    testWidgets('refresh: appAuth returning no access token is a failure', (
      tester,
    ) async {
      final jwt = buildTestJwt({'sub': 'user-123', 'exp': 9999999999});
      final session = Session(
        accessToken: 'old-token',
        refreshToken: 'refresh-token-123',
        expiresAt: clock.now().add(const Duration(hours: 1)),
        claims: JwtClaims.decode(jwt),
      );

      when(
        () => mockAppAuth.token(
          clientId: any(named: 'clientId'),
          redirectUrl: any(named: 'redirectUrl'),
          refreshToken: any(named: 'refreshToken'),
          tokenEndpoint: any(named: 'tokenEndpoint'),
          scopes: any(named: 'scopes'),
        ),
      ).thenAnswer(
        (_) async => (
          accessToken: null,
          refreshToken: null,
          accessTokenExpirationDateTime: null,
        ),
      );

      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
        authorizationEndpoint: Uri.parse('https://auth.example.com/authorize'),
        tokenEndpoint: Uri.parse('https://auth.example.com/token'),
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
      );
      final result = await backend.refresh(session);

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<AuthFailure>());
      }
    });

    testWidgets('refresh: appAuth throwing is an UnknownFailure', (
      tester,
    ) async {
      final jwt = buildTestJwt({'sub': 'user-123', 'exp': 9999999999});
      final session = Session(
        accessToken: 'old-token',
        refreshToken: 'refresh-token-123',
        expiresAt: clock.now().add(const Duration(hours: 1)),
        claims: JwtClaims.decode(jwt),
      );

      when(
        () => mockAppAuth.token(
          clientId: any(named: 'clientId'),
          redirectUrl: any(named: 'redirectUrl'),
          refreshToken: any(named: 'refreshToken'),
          tokenEndpoint: any(named: 'tokenEndpoint'),
          scopes: any(named: 'scopes'),
        ),
      ).thenThrow(Exception('platform error'));

      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
        authorizationEndpoint: Uri.parse('https://auth.example.com/authorize'),
        tokenEndpoint: Uri.parse('https://auth.example.com/token'),
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
      );
      final result = await backend.refresh(session);

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<UnknownFailure>());
      }
    });

    testWidgets('logout: appAuth.endSession throwing is an UnknownFailure', (
      tester,
    ) async {
      final jwt = buildTestJwt({'sub': 'user-123', 'exp': 9999999999});
      final session = Session(
        accessToken: jwt,
        refreshToken: null,
        expiresAt: clock.now().add(const Duration(hours: 1)),
        claims: JwtClaims.decode(jwt),
      );

      when(
        () => mockAppAuth.endSession(
          idTokenHint: any(named: 'idTokenHint'),
          endSessionEndpoint: any(named: 'endSessionEndpoint'),
          redirectUrl: any(named: 'redirectUrl'),
          preferEphemeralSession: any(named: 'preferEphemeralSession'),
        ),
      ).thenThrow(Exception('platform error'));

      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
        endSessionEndpoint: Uri.parse('https://auth.example.com/logout'),
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
      );
      final result = await backend.logout(session);

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<UnknownFailure>());
      }
    });

    testWidgets('login: discovery HTTP client throwing is an UnknownFailure', (
      tester,
    ) async {
      when(() => mockClient.get(any())).thenThrow(Exception('dns failure'));

      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
        client: mockClient,
      );

      final result = await backend.login(LoginRequest.interactive());

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<UnknownFailure>());
      }
    });

    testWidgets('logout: endSession returning false is a failure', (
      tester,
    ) async {
      when(
        () => mockAppAuth.endSession(
          idTokenHint: any(named: 'idTokenHint'),
          endSessionEndpoint: any(named: 'endSessionEndpoint'),
          redirectUrl: any(named: 'redirectUrl'),
          preferEphemeralSession: any(named: 'preferEphemeralSession'),
        ),
      ).thenAnswer((_) async => false);

      final jwt = buildTestJwt({'sub': 'user-123', 'exp': 9999999999});
      final session = Session(
        accessToken: jwt,
        refreshToken: null,
        expiresAt: clock.now().add(const Duration(hours: 1)),
        claims: JwtClaims.decode(jwt),
      );

      final config = AuthConfig.hosted(
        issuer: Uri.parse('https://auth.example.com'),
        clientId: 'app-client',
        redirectUri: 'io.penguintech.app://oauth/callback',
        endSessionEndpoint: Uri.parse('https://auth.example.com/logout'),
      );

      final backend = HostedLoginBackend(
        config,
        appAuth: mockAppAuth,
        clock: clock,
      );

      final result = await backend.logout(session);

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<AuthFailure>());
      }
    });
  });

  group('externalUserAgentFor', () {
    test('maps preferEphemeralSession to the matching ExternalUserAgent', () {
      expect(
        externalUserAgentFor(true),
        appauth.ExternalUserAgent.ephemeralAsWebAuthenticationSession,
      );
      expect(
        externalUserAgentFor(false),
        appauth.ExternalUserAgent.asWebAuthenticationSession,
      );
    });
  });

  group('normalizeScopes', () {
    test('maps an empty list to null', () {
      expect(normalizeScopes(const []), isNull);
    });

    test('passes a non-empty list through unchanged', () {
      expect(normalizeScopes(const ['openid', 'profile']), [
        'openid',
        'profile',
      ]);
    });
  });
}
