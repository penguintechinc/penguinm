import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:penguin_auth/penguin_auth.dart';

class MockGoRouterState extends Mock implements GoRouterState {}

void main() {
  group('authRedirect', () {
    test('redirects unauthenticated user to login', () {
      final state = const AuthState.unauthenticated();
      final routeState = MockGoRouterState();
      when(
        () => routeState.uri,
      ).thenReturn(Uri.parse('https://example.com/home'));

      final redirect = authRedirect(
        state,
        routeState,
        loginPath: '/login',
        homePath: '/home',
      );

      expect(redirect, '/login');
    });

    test('redirects expired user to login', () {
      final state = const AuthState.expired();
      final routeState = MockGoRouterState();
      when(
        () => routeState.uri,
      ).thenReturn(Uri.parse('https://example.com/home'));

      final redirect = authRedirect(
        state,
        routeState,
        loginPath: '/login',
        homePath: '/home',
      );

      expect(redirect, '/login');
    });

    test('redirects authenticated user away from login', () {
      final header =
          'eyJhbGciOiJIUzI1NiJ9'; // {"alg":"HS256"} (hardcoded, no padding)
      final claimsJson = jsonEncode({
        'sub': 'user-123',
        'iss': 'https://auth.example.com',
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
        expiresAt: DateTime(2099, 12, 31),
        claims: claims,
      );

      final state = AuthState.authenticated(session);
      final routeState = MockGoRouterState();
      when(
        () => routeState.uri,
      ).thenReturn(Uri.parse('https://example.com/login'));

      final redirect = authRedirect(
        state,
        routeState,
        loginPath: '/login',
        homePath: '/home',
      );

      expect(redirect, '/home');
    });

    test('allows unauthenticated user to stay on login', () {
      final state = const AuthState.unauthenticated();
      final routeState = MockGoRouterState();
      when(
        () => routeState.uri,
      ).thenReturn(Uri.parse('https://example.com/login'));

      final redirect = authRedirect(
        state,
        routeState,
        loginPath: '/login',
        homePath: '/home',
      );

      expect(redirect, isNull);
    });

    test('allows authenticated user to stay on protected route', () {
      final header = 'eyJhbGciOiJIUzI1NiJ9';
      final claimsJson = jsonEncode({
        'sub': 'user-123',
        'iss': 'https://auth.example.com',
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
        expiresAt: DateTime(2099, 12, 31),
        claims: claims,
      );

      final state = AuthState.authenticated(session);
      final routeState = MockGoRouterState();
      when(
        () => routeState.uri,
      ).thenReturn(Uri.parse('https://example.com/home'));

      final redirect = authRedirect(
        state,
        routeState,
        loginPath: '/login',
        homePath: '/home',
      );

      expect(redirect, isNull);
    });
  });
}
