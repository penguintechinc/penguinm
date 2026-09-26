import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_flags/penguin_flags.dart';
import 'package:penguin_testing/penguin_testing.dart';

void main() {
  group('InMemoryFlagCache', () {
    test('load returns null when nothing was ever saved', () async {
      final cache = InMemoryFlagCache();
      expect(await cache.load(), isNull);
    });

    test('load returns the pre-populated initial snapshot', () async {
      final initial = CachedFlags(
        flags: const {'waddlebot.chat': true},
        tier: 'professional',
        lastFetched: DateTime.utc(2026),
      );
      final cache = InMemoryFlagCache(initial: initial);
      expect(await cache.load(), initial);
    });

    test('save then load round-trips the snapshot', () async {
      final cache = InMemoryFlagCache();
      final snapshot = CachedFlags(
        flags: const {'waddlebot.chat': true},
        tier: 'enterprise',
        lastFetched: DateTime.utc(2026, 2),
      );
      await cache.save(snapshot);

      final loaded = await cache.load();
      expect(loaded?.flags, snapshot.flags);
      expect(loaded?.tier, snapshot.tier);
      expect(loaded?.lastFetched, snapshot.lastFetched);
      expect(cache.saveCallCount, 1);
    });

    test(
      'save overwrites the previous snapshot and increments the count',
      () async {
        final cache = InMemoryFlagCache();
        await cache.save(
          CachedFlags(
            flags: const {},
            tier: 'free',
            lastFetched: DateTime.utc(2026),
          ),
        );
        await cache.save(
          CachedFlags(
            flags: const {'x': true},
            tier: 'professional',
            lastFetched: DateTime.utc(2026, 3),
          ),
        );

        expect(cache.saveCallCount, 2);
        expect((await cache.load())?.tier, 'professional');
      },
    );
  });
}
