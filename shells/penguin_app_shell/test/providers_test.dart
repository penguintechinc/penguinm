import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';

void main() {
  test('goRouterProvider throws until PenguinApp overrides it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Riverpod wraps a provider body's thrown error in a ProviderException.
    expect(
      () => container.read(goRouterProvider),
      throwsA(
        isA<ProviderException>().having(
          (e) => e.exception,
          'exception',
          isA<UnimplementedError>(),
        ),
      ),
    );
  });
}
