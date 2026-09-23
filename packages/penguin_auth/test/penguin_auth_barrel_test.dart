/// Verifies that the penguin_auth barrel exports all public types.
library;

import 'package:penguin_auth/penguin_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('barrel exports all public types', () {
    // Verify types can be instantiated/accessed
    expect(
      () => AuthConfig.hosted(
        issuer: Uri.parse('https://example.com'),
        clientId: 'test',
        redirectUri: 'io.test://callback',
      ),
      returnsNormally,
    );

    expect(() => AuthConfig.password(), returnsNormally);

    // Verify the AuthState sealed class and its variants are exported
    // (they fail to compile if the export is missing) and construct as the
    // expected type.
    expect(const AuthState.unknown(), isA<AuthState>());
    expect(const AuthState.unauthenticated(), isA<AuthState>());
    expect(const AuthState.authenticating(), isA<AuthState>());

    // Verify the LoginRequest sealed class and its variants are exported.
    expect(const LoginRequest.interactive(), isA<LoginRequest>());
    expect(
      const LoginRequest.password(email: 'test', password: 'test'),
      isA<LoginRequest>(),
    );
  });
}
