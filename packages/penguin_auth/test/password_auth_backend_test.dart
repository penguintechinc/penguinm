import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'support/fake_clock.dart';

void main() {
  group('PasswordAuthBackend', () {
    late FakeClock clock;

    setUp(() {
      clock = FakeClock(startTime: DateTime(2024, 1, 1));
    });

    testWidgets('login: password flow posts to login endpoint', (tester) async {
      final header =
          'eyJhbGciOiJIUzI1NiJ9'; // {"alg":"HS256"} (hardcoded, no padding)
      final claimsJson = jsonEncode({
        'sub': 'user-123',
        'iss': 'https://api.example.com',
        'aud': 'app',
        'exp':
            clock.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
            1000,
      });
      final payload = base64Url.encode(utf8.encode(claimsJson));
      const sig = 'dummy';
      final jwt = '$header.$payload.$sig';

      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/login');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'user@example.com');
        expect(body['password'], 'password123');

        return http.Response(
          jsonEncode({
            'access_token': jwt,
            'refresh_token': 'refresh-token-123',
            'expires_in': 3600,
          }),
          200,
        );
      });

      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        client: mockClient,
        clock: clock,
      );

      final request = LoginRequest.password(
        email: 'user@example.com',
        password: 'password123',
      );

      final result = await backend.login(request);

      expect(result.isOk, isTrue);
      final session = result.valueOrNull!;
      expect(session.accessToken, jwt);
      expect(session.refreshToken, 'refresh-token-123');
    });

    testWidgets('login: handles LoginResponse format', (tester) async {
      final header = 'eyJhbGciOiJIUzI1NiJ9';
      final claimsJson = jsonEncode({
        'sub': 'user-123',
        'iss': 'https://api.example.com',
        'aud': 'app',
        'exp': 9999999999,
      });
      final payload = base64Url.encode(utf8.encode(claimsJson));
      const sig = 'dummy';
      final jwt = '$header.$payload.$sig';

      final response = LoginResponse(
        success: true,
        token: jwt,
        refreshToken: 'refresh-token',
        user: LoginUser(id: 'user-123', email: 'user@example.com'),
      );

      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        clock: clock,
      );

      final request = LoginRequest.fromLoginResponse(response);
      final result = await backend.login(request);

      expect(result.isOk, isTrue);
      final session = result.valueOrNull!;
      expect(session.accessToken, jwt);
    });

    testWidgets('login: handles failed LoginResponse', (tester) async {
      final response = LoginResponse(
        success: false,
        error: 'Invalid credentials',
      );

      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        clock: clock,
      );

      final request = LoginRequest.fromLoginResponse(response);
      final result = await backend.login(request);

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<AuthFailure>());
      }
    });

    testWidgets('login: includes mfa_code when provided', (tester) async {
      final header = 'eyJhbGciOiJIUzI1NiJ9';
      final claimsJson = jsonEncode({
        'sub': 'user-123',
        'iss': 'https://api.example.com',
        'aud': 'app',
        'exp': 9999999999,
      });
      final payload = base64Url.encode(utf8.encode(claimsJson));
      const sig = 'dummy';
      final jwt = '$header.$payload.$sig';

      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['mfa_code'], '123456');

        return http.Response(
          jsonEncode({
            'access_token': jwt,
            'refresh_token': 'refresh-token-123',
            'expires_in': 3600,
          }),
          200,
        );
      });

      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        client: mockClient,
        clock: clock,
      );

      final request = LoginRequest.password(
        email: 'user@example.com',
        password: 'password123',
        mfaCode: '123456',
      );

      final result = await backend.login(request);
      expect(result.isOk, isTrue);
    });

    testWidgets('login: handles server errors', (tester) async {
      final mockClient = MockClient(
        (_) async => http.Response(jsonEncode({'error': 'Server error'}), 500),
      );

      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        client: mockClient,
        clock: clock,
      );

      final request = LoginRequest.password(
        email: 'user@example.com',
        password: 'password123',
      );

      final result = await backend.login(request);

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<ServerFailure>());
      }
    });

    testWidgets('refresh: posts refresh_token to refresh endpoint', (
      tester,
    ) async {
      final header = 'eyJhbGciOiJIUzI1NiJ9';
      final claimsJson = jsonEncode({
        'sub': 'user-123',
        'iss': 'https://api.example.com',
        'aud': 'app',
        'exp': 9999999999,
      });
      final payload = base64Url.encode(utf8.encode(claimsJson));
      const sig = 'dummy';
      final jwt = '$header.$payload.$sig';

      final claims = JwtClaims.decode(jwt);
      final session = Session(
        accessToken: 'old-token',
        refreshToken: 'refresh-token-123',
        expiresAt: clock.now().add(const Duration(hours: 1)),
        claims: claims,
      );

      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/refresh');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['refresh_token'], 'refresh-token-123');

        return http.Response(
          jsonEncode({
            'access_token': jwt,
            'refresh_token': 'new-refresh-token',
            'expires_in': 3600,
          }),
          200,
        );
      });

      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        client: mockClient,
        clock: clock,
      );

      final result = await backend.refresh(session);

      expect(result.isOk, isTrue);
      final newSession = result.valueOrNull!;
      expect(newSession.refreshToken, 'new-refresh-token');
    });

    testWidgets('refresh: returns error when no refresh token', (tester) async {
      final header = 'eyJhbGciOiJIUzI1NiJ9';
      final claimsJson = jsonEncode({
        'sub': 'user-123',
        'iss': 'https://api.example.com',
        'aud': 'app',
        'exp': 9999999999,
      });
      final payload = base64Url.encode(utf8.encode(claimsJson));
      const sig = 'dummy';
      final jwt = '$header.$payload.$sig';

      final claims = JwtClaims.decode(jwt);
      final session = Session(
        accessToken: jwt,
        refreshToken: null,
        expiresAt: clock.now().add(const Duration(hours: 1)),
        claims: claims,
      );

      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        clock: clock,
      );

      final result = await backend.refresh(session);

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<AuthFailure>());
      }
    });

    testWidgets('logout: posts access_token to logout endpoint', (
      tester,
    ) async {
      final header = 'eyJhbGciOiJIUzI1NiJ9';
      final claimsJson = jsonEncode({
        'sub': 'user-123',
        'iss': 'https://api.example.com',
        'aud': 'app',
        'exp': 9999999999,
      });
      final payload = base64Url.encode(utf8.encode(claimsJson));
      const sig = 'dummy';
      final jwt = '$header.$payload.$sig';

      final claims = JwtClaims.decode(jwt);
      final session = Session(
        accessToken: jwt,
        refreshToken: null,
        expiresAt: clock.now().add(const Duration(hours: 1)),
        claims: claims,
      );

      bool logoutCalled = false;
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/logout');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['access_token'], jwt);

        logoutCalled = true;
        return http.Response(jsonEncode({'success': true}), 200);
      });

      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        client: mockClient,
        clock: clock,
      );

      final result = await backend.logout(session);

      expect(result.isOk, isTrue);
      expect(logoutCalled, isTrue);
    });

    testWidgets('constructor throws for a non-password config', (tester) async {
      expect(
        () => PasswordAuthBackend(
          AuthConfig.hosted(
            issuer: Uri.parse('https://auth.example.com'),
            clientId: 'client',
            redirectUri: 'io.test://callback',
          ),
          apiBaseUrl: Uri.parse('https://api.example.com'),
        ),
        throwsArgumentError,
      );
    });

    testWidgets('login: rejects an interactive request', (tester) async {
      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        clock: clock,
      );

      final result = await backend.login(const LoginRequest.interactive());

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<AuthFailure>());
      }
    });

    testWidgets('login: server replies with LoginResponse-shaped JSON', (
      tester,
    ) async {
      final mockClient = MockClient(
        (_) async => http.Response(
          jsonEncode({'success': false, 'error': 'Invalid credentials'}),
          200,
        ),
      );

      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        client: mockClient,
        clock: clock,
      );

      final result = await backend.login(
        const LoginRequest.password(
          email: 'user@example.com',
          password: 'password123',
        ),
      );

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<AuthFailure>());
      }
    });

    testWidgets('login: malformed LoginResponse JSON is an UnknownFailure', (
      tester,
    ) async {
      final mockClient = MockClient(
        (_) async => http.Response(jsonEncode({'success': 'not-a-bool'}), 200),
      );

      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        client: mockClient,
        clock: clock,
      );

      final result = await backend.login(
        const LoginRequest.password(
          email: 'user@example.com',
          password: 'password123',
        ),
      );

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<UnknownFailure>());
      }
    });

    testWidgets('login: unrecognized response shape is a failure', (
      tester,
    ) async {
      final mockClient = MockClient(
        (_) async => http.Response(jsonEncode({'unexpected': true}), 200),
      );

      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        client: mockClient,
        clock: clock,
      );

      final result = await backend.login(
        const LoginRequest.password(
          email: 'user@example.com',
          password: 'password123',
        ),
      );

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<AuthFailure>());
      }
    });

    testWidgets('login: a thrown client exception is an UnknownFailure', (
      tester,
    ) async {
      final mockClient = MockClient((_) async => throw Exception('offline'));

      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        client: mockClient,
        clock: clock,
      );

      final result = await backend.login(
        const LoginRequest.password(
          email: 'user@example.com',
          password: 'password123',
        ),
      );

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<UnknownFailure>());
      }
    });

    testWidgets('login: a non-JWT access token is an UnknownFailure', (
      tester,
    ) async {
      final mockClient = MockClient(
        (_) async => http.Response(
          jsonEncode({'access_token': 'not-a-jwt', 'expires_in': 3600}),
          200,
        ),
      );

      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        client: mockClient,
        clock: clock,
      );

      final result = await backend.login(
        const LoginRequest.password(
          email: 'user@example.com',
          password: 'password123',
        ),
      );

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<UnknownFailure>());
      }
    });

    testWidgets(
      'login: a LoginResponse with a non-JWT token is an UnknownFailure',
      (tester) async {
        final response = LoginResponse(success: true, token: 'not-a-jwt');

        final config = AuthConfig.password();
        final backend = PasswordAuthBackend(
          config,
          apiBaseUrl: Uri.parse('https://api.example.com'),
          clock: clock,
        );

        final result = await backend.login(
          LoginRequest.fromLoginResponse(response),
        );

        expect(result.isOk, isFalse);
        if (result case Err(:final failure)) {
          expect(failure, isA<UnknownFailure>());
        }
      },
    );

    testWidgets('refresh: server error is a ServerFailure', (tester) async {
      final header = 'eyJhbGciOiJIUzI1NiJ9';
      final claimsJson = jsonEncode({'sub': 'user-123', 'exp': 9999999999});
      final payload = base64Url.encode(utf8.encode(claimsJson));
      const sig = 'dummy';
      final jwt = '$header.$payload.$sig';
      final claims = JwtClaims.decode(jwt);
      final session = Session(
        accessToken: jwt,
        refreshToken: 'refresh-token-123',
        expiresAt: clock.now().add(const Duration(hours: 1)),
        claims: claims,
      );

      final mockClient = MockClient(
        (_) async => http.Response(jsonEncode({'error': 'down'}), 503),
      );

      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        client: mockClient,
        clock: clock,
      );

      final result = await backend.refresh(session);

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<ServerFailure>());
      }
    });

    testWidgets(
      'refresh: missing access token in a 200 response is a failure',
      (tester) async {
        final header = 'eyJhbGciOiJIUzI1NiJ9';
        final claimsJson = jsonEncode({'sub': 'user-123', 'exp': 9999999999});
        final payload = base64Url.encode(utf8.encode(claimsJson));
        const sig = 'dummy';
        final jwt = '$header.$payload.$sig';
        final claims = JwtClaims.decode(jwt);
        final session = Session(
          accessToken: jwt,
          refreshToken: 'refresh-token-123',
          expiresAt: clock.now().add(const Duration(hours: 1)),
          claims: claims,
        );

        final mockClient = MockClient((_) async => http.Response('{}', 200));

        final config = AuthConfig.password();
        final backend = PasswordAuthBackend(
          config,
          apiBaseUrl: Uri.parse('https://api.example.com'),
          client: mockClient,
          clock: clock,
        );

        final result = await backend.refresh(session);

        expect(result.isOk, isFalse);
        if (result case Err(:final failure)) {
          expect(failure, isA<AuthFailure>());
        }
      },
    );

    testWidgets('refresh: a thrown client exception is an UnknownFailure', (
      tester,
    ) async {
      final header = 'eyJhbGciOiJIUzI1NiJ9';
      final claimsJson = jsonEncode({'sub': 'user-123', 'exp': 9999999999});
      final payload = base64Url.encode(utf8.encode(claimsJson));
      const sig = 'dummy';
      final jwt = '$header.$payload.$sig';
      final claims = JwtClaims.decode(jwt);
      final session = Session(
        accessToken: jwt,
        refreshToken: 'refresh-token-123',
        expiresAt: clock.now().add(const Duration(hours: 1)),
        claims: claims,
      );

      final mockClient = MockClient((_) async => throw Exception('offline'));

      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        client: mockClient,
        clock: clock,
      );

      final result = await backend.refresh(session);

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<UnknownFailure>());
      }
    });

    testWidgets('logout: a thrown client exception is an UnknownFailure', (
      tester,
    ) async {
      final header = 'eyJhbGciOiJIUzI1NiJ9';
      final claimsJson = jsonEncode({'sub': 'user-123', 'exp': 9999999999});
      final payload = base64Url.encode(utf8.encode(claimsJson));
      const sig = 'dummy';
      final jwt = '$header.$payload.$sig';
      final claims = JwtClaims.decode(jwt);
      final session = Session(
        accessToken: jwt,
        refreshToken: null,
        expiresAt: clock.now().add(const Duration(hours: 1)),
        claims: claims,
      );

      final mockClient = MockClient((_) async => throw Exception('offline'));

      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        client: mockClient,
        clock: clock,
      );

      final result = await backend.logout(session);

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<UnknownFailure>());
      }
    });

    testWidgets('logout: a non-2xx status is a ServerFailure', (tester) async {
      final header = 'eyJhbGciOiJIUzI1NiJ9';
      final claimsJson = jsonEncode({'sub': 'user-123', 'exp': 9999999999});
      final payload = base64Url.encode(utf8.encode(claimsJson));
      const sig = 'dummy';
      final jwt = '$header.$payload.$sig';
      final claims = JwtClaims.decode(jwt);
      final session = Session(
        accessToken: jwt,
        refreshToken: null,
        expiresAt: clock.now().add(const Duration(hours: 1)),
        claims: claims,
      );

      final mockClient = MockClient(
        (_) async => http.Response(jsonEncode({'error': 'nope'}), 401),
      );

      final config = AuthConfig.password();
      final backend = PasswordAuthBackend(
        config,
        apiBaseUrl: Uri.parse('https://api.example.com'),
        client: mockClient,
        clock: clock,
      );

      final result = await backend.logout(session);

      expect(result.isOk, isFalse);
      if (result case Err(:final failure)) {
        expect(failure, isA<ServerFailure>());
        expect((failure as ServerFailure).statusCode, 401);
      }
    });
  });
}
