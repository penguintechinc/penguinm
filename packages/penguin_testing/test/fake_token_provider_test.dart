import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_testing/penguin_testing.dart';

void main() {
  group('FakeTokenProvider', () {
    test('accessToken returns the initial token', () async {
      final provider = FakeTokenProvider(initialToken: 'tok-abc');
      expect(await provider.accessToken(), 'tok-abc');
    });

    test('accessToken returns null when unauthenticated', () async {
      final provider = FakeTokenProvider();
      expect(await provider.accessToken(), isNull);
    });

    test(
      'refresh succeeds by default, emits refreshed, updates token',
      () async {
        final provider = FakeTokenProvider(initialToken: 'tok-1');
        final ok = await provider.refresh();
        expect(ok, isTrue);
        expect(provider.refreshCallCount, 1);
        expect(await provider.accessToken(), isNot('tok-1'));
        expect(provider.emittedEvents, [AuthEvent.refreshed]);
      },
    );

    test(
      'refresh emits unauthenticated and clears the token when configured to fail',
      () async {
        final provider = FakeTokenProvider(
          initialToken: 'tok-1',
          refreshSucceeds: false,
        );
        final ok = await provider.refresh();
        expect(ok, isFalse);
        expect(await provider.accessToken(), isNull);
        expect(provider.emittedEvents, [AuthEvent.unauthenticated]);
      },
    );

    test('setRefreshSucceeds changes future refresh outcomes', () async {
      final provider = FakeTokenProvider(refreshSucceeds: false);
      expect(await provider.refresh(), isFalse);
      provider.setRefreshSucceeds(true);
      expect(await provider.refresh(), isTrue);
    });

    test('setToken overrides the token directly', () async {
      final provider = FakeTokenProvider();
      provider.setToken('manual-token');
      expect(await provider.accessToken(), 'manual-token');
    });

    test('events stream receives emitted events', () async {
      final provider = FakeTokenProvider();
      final future = provider.events.first;
      provider.emit(AuthEvent.unauthenticated);
      expect(await future, AuthEvent.unauthenticated);
      await provider.dispose();
    });
  });
}
