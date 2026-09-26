import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'support/fake_clock.dart';

void main() {
  group('JwtClaims.decode', () {
    test('decodes a valid JWT with standard claims', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'sub': 'user-123',
            'iss': 'https://auth.example.com',
            'tenant': 'tenant-456',
            'aud': 'app-client',
            'scope': 'openid profile email',
            'teams': ['team-1', 'team-2'],
            'roles': ['admin', 'user'],
            'exp': 9999999999,
            'iat': 1000000000,
          }),
        ),
      );
      final sig = 'dummy-sig';
      final jwt = '$header.$payload.$sig';

      final claims = JwtClaims.decode(jwt);

      expect(claims.sub, 'user-123');
      expect(claims.iss, 'https://auth.example.com');
      expect(claims.tenant, 'tenant-456');
      expect(claims.aud, ['app-client']);
      expect(claims.scope, ['openid', 'profile', 'email']);
      expect(claims.teams, ['team-1', 'team-2']);
      expect(claims.roles, ['admin', 'user']);
      expect(
        claims.exp,
        DateTime.fromMillisecondsSinceEpoch(9999999999000, isUtc: true),
      );
      expect(
        claims.iat,
        DateTime.fromMillisecondsSinceEpoch(1000000000000, isUtc: true),
      );
    });

    test('handles missing padding in base64url', () {
      // Payload without padding
      final header = 'eyJhbGciOiJIUzI1NiJ9'; // {"alg":"HS256"}
      final payload =
          'eyJzdWIiOiJ1c2VyLTEyMyIsImlzcyI6Imh0dHBzOi8vYXV0aC5leGFtcGxlLmNvbSIsImV4cCI6OTk5OTk5OTk5OX0'; // payload without padding
      const sig = 'dummy';
      final jwt = '$header.$payload.$sig';

      final claims = JwtClaims.decode(jwt);
      expect(claims.sub, 'user-123');
      expect(claims.iss, 'https://auth.example.com');
    });

    test('parses aud as a single string', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'aud': 'single-audience', 'exp': 9999999999})),
      );
      final jwt = '$header.$payload.sig';

      final claims = JwtClaims.decode(jwt);
      expect(claims.aud, ['single-audience']);
    });

    test('parses aud as a list', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'aud': ['aud1', 'aud2'],
            'exp': 9999999999,
          }),
        ),
      );
      final jwt = '$header.$payload.sig';

      final claims = JwtClaims.decode(jwt);
      expect(claims.aud, ['aud1', 'aud2']);
    });

    test('parses scope as a space-separated string', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'scope': 'openid profile email offline_access',
            'exp': 9999999999,
          }),
        ),
      );
      final jwt = '$header.$payload.sig';

      final claims = JwtClaims.decode(jwt);
      expect(claims.scope, ['openid', 'profile', 'email', 'offline_access']);
    });

    test('parses scope as a list', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'scope': ['openid', 'profile'],
            'exp': 9999999999,
          }),
        ),
      );
      final jwt = '$header.$payload.sig';

      final claims = JwtClaims.decode(jwt);
      expect(claims.scope, ['openid', 'profile']);
    });

    test('returns empty lists for missing aud/scope/teams/roles', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'exp': 9999999999})),
      );
      final jwt = '$header.$payload.sig';

      final claims = JwtClaims.decode(jwt);
      expect(claims.aud, isEmpty);
      expect(claims.scope, isEmpty);
      expect(claims.teams, isEmpty);
      expect(claims.roles, isEmpty);
    });

    test('throws FormatException on invalid JWT', () {
      expect(() => JwtClaims.decode('invalid'), throwsFormatException);
    });

    test('throws FormatException on invalid base64', () {
      expect(
        () => JwtClaims.decode('header.!!!invalid!!!.sig'),
        throwsFormatException,
      );
    });
  });

  group('JwtClaims.isExpired', () {
    test('returns true when token is expired', () {
      final clock = FakeClock(startTime: DateTime(2024, 1, 15));
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'exp': 1705190400, // 2024-01-14
          }),
        ),
      );
      final jwt = '$header.$payload.sig';

      final claims = JwtClaims.decode(jwt);
      expect(claims.isExpired(clock), isTrue);
    });

    test('returns false when token is not expired', () {
      final clock = FakeClock(startTime: DateTime(2024, 1, 10));
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'exp': 1705190400, // 2024-01-14
          }),
        ),
      );
      final jwt = '$header.$payload.sig';

      final claims = JwtClaims.decode(jwt);
      expect(claims.isExpired(clock), isFalse);
    });

    test('respects leeway when checking expiration', () {
      // exp decodes as UTC (see _parseTimestamp); the clock must be
      // constructed as UTC too so this assertion doesn't depend on the
      // test runner's local timezone offset. Exactly 30s past exp: within
      // the default 30s leeway (not expired), but past a zero leeway.
      final clock = FakeClock(startTime: DateTime.utc(2024, 1, 14, 0, 0, 30));
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'exp': 1705190400, // 2024-01-14 00:00:00 UTC
          }),
        ),
      );
      final jwt = '$header.$payload.sig';

      final claims = JwtClaims.decode(jwt);
      // Without leeway, would be expired; with default 30s leeway, not expired.
      expect(claims.isExpired(clock), isFalse);
      expect(claims.isExpired(clock, leeway: Duration.zero), isTrue);
    });

    test('returns false when exp is missing', () {
      final clock = FakeClock();
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': 'user-123'})),
      );
      final jwt = '$header.$payload.sig';

      final claims = JwtClaims.decode(jwt);
      expect(claims.isExpired(clock), isFalse);
    });
  });

  group('JwtClaims.hasScope', () {
    test('returns true when scope is present', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({'scope': 'openid profile email', 'exp': 9999999999}),
        ),
      );
      final jwt = '$header.$payload.sig';

      final claims = JwtClaims.decode(jwt);
      expect(claims.hasScope('openid'), isTrue);
      expect(claims.hasScope('profile'), isTrue);
      expect(claims.hasScope('email'), isTrue);
    });

    test('returns false when scope is absent', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'scope': 'openid profile', 'exp': 9999999999})),
      );
      final jwt = '$header.$payload.sig';

      final claims = JwtClaims.decode(jwt);
      expect(claims.hasScope('admin'), isFalse);
    });
  });

  group('JwtClaims field parsing edge cases', () {
    test('aud/scope/teams/roles of an unexpected JSON type become empty', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'aud': 12345,
            'scope': true,
            'teams': 'not-a-list',
            'roles': 42,
            'exp': 9999999999,
          }),
        ),
      );
      final jwt = '$header.$payload.sig';

      final claims = JwtClaims.decode(jwt);
      expect(claims.aud, isEmpty);
      expect(claims.scope, isEmpty);
      expect(claims.teams, isEmpty);
      expect(claims.roles, isEmpty);
    });

    test('toString includes the decoded claims', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': 'user-123', 'exp': 9999999999})),
      );
      final jwt = '$header.$payload.sig';

      final text = JwtClaims.decode(jwt).toString();
      expect(text, contains('JwtClaims'));
      expect(text, contains('user-123'));
    });
  });

  group('Session JSON round-trip', () {
    test('serializes and deserializes correctly', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'sub': 'user-123',
            'iss': 'issuer',
            'aud': 'app',
            'exp': 9999999999,
          }),
        ),
      );
      final jwt = '$header.$payload.sig';

      final claims = JwtClaims.decode(jwt);
      final original = Session(
        accessToken: jwt,
        refreshToken: 'refresh-123',
        expiresAt: DateTime(2099, 12, 31),
        claims: claims,
      );

      final json = original.toJson();
      final restored = Session.fromJson(json);

      expect(restored.accessToken, original.accessToken);
      expect(restored.refreshToken, original.refreshToken);
      expect(restored.expiresAt, original.expiresAt);
      expect(restored.claims.sub, original.claims.sub);
    });

    test('toString masks the access and refresh tokens', () {
      final header = base64Url.encode(utf8.encode('{"alg":"HS256"}'));
      final payload = base64Url.encode(
        utf8.encode(jsonEncode({'sub': 'user-123', 'exp': 9999999999})),
      );
      final jwt = '$header.$payload.sig';
      final claims = JwtClaims.decode(jwt);
      final noRefresh = Session(
        accessToken: jwt,
        expiresAt: DateTime(2099, 12, 31),
        claims: claims,
      );
      final withRefresh = Session(
        accessToken: jwt,
        refreshToken: 'refresh-secret-123',
        expiresAt: DateTime(2099, 12, 31),
        claims: claims,
      );

      expect(noRefresh.toString(), isNot(contains(jwt)));
      expect(noRefresh.toString(), contains('refreshToken: null'));
      expect(withRefresh.toString(), isNot(contains(jwt)));
      expect(withRefresh.toString(), isNot(contains('refresh-secret-123')));
    });
  });
}
