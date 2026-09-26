import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_auth/penguin_auth.dart';

void main() {
  group('authBackendProvider', () {
    test('throws when not overridden by the app', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Riverpod wraps a provider's create-time throw before it reaches the
      // caller, so this asserts on the underlying message rather than the
      // exact wrapper type.
      Object? caught;
      try {
        container.read(authBackendProvider);
      } catch (e) {
        caught = e;
      }

      expect(caught, isNotNull);
      expect(
        caught.toString(),
        contains('authBackendProvider must be overridden'),
      );
    });
  });
}
