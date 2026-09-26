import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_auth/penguin_auth.dart';

void main() {
  group('SessionStore', () {
    test('saves and loads a session', () async {
      // Use setMockInitialValues to mock flutter_secure_storage.
      FlutterSecureStorage.setMockInitialValues({});

      final store = SessionStore();

      // Create a session
      final header =
          'eyJhbGciOiJIUzI1NiJ9'; // {"alg":"HS256"} (no padding for simplicity)
      final payload =
          'eyJzdWIiOiJ1c2VyLTEyMyIsImlzcyI6Imh0dHBzOi8vYXV0aC5leGFtcGxlLmNvbSIsImV4cCI6OTk5OTk5OTk5OX0'; // no padding
      const sig = 'dummy';
      final jwt = '$header.$payload.$sig';

      final claims = JwtClaims.decode(jwt);
      final session = Session(
        accessToken: jwt,
        refreshToken: 'refresh-token-123',
        expiresAt: DateTime(2099, 12, 31),
        claims: claims,
      );

      // Save session
      await store.save(session);

      // Load session
      final loaded = await store.load();

      expect(loaded, isNotNull);
      expect(loaded!.accessToken, session.accessToken);
      expect(loaded.refreshToken, session.refreshToken);
      expect(loaded.expiresAt, session.expiresAt);
      expect(loaded.claims.sub, session.claims.sub);
    });

    test('returns null when no session is saved', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = SessionStore();

      final loaded = await store.load();
      expect(loaded, isNull);
    });

    test('clears a saved session', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = SessionStore();

      // Create and save a session
      final header = 'eyJhbGciOiJIUzI1NiJ9';
      final payload =
          'eyJzdWIiOiJ1c2VyLTEyMyIsImlzcyI6Imh0dHBzOi8vYXV0aC5leGFtcGxlLmNvbSIsImV4cCI6OTk5OTk5OTk5OX0';
      const sig = 'dummy';
      final jwt = '$header.$payload.$sig';
      final claims = JwtClaims.decode(jwt);
      final session = Session(
        accessToken: jwt,
        refreshToken: 'refresh-token-123',
        expiresAt: DateTime(2099, 12, 31),
        claims: claims,
      );

      await store.save(session);
      var loaded = await store.load();
      expect(loaded, isNotNull);

      // Clear the session
      await store.clear();
      loaded = await store.load();
      expect(loaded, isNull);
    });
  });
}
