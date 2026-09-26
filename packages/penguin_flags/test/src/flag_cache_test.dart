import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_flags/src/cached_flags.dart';
import 'package:penguin_flags/src/flag_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FlagCache', () {
    test('loads empty when nothing cached', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = FlagCache();

      final result = await cache.load();
      expect(result, isNull);
    });

    test('returns null when the cached value is corrupt JSON', () async {
      SharedPreferences.setMockInitialValues({
        'penguin_flags_cache': 'not valid json {{{',
      });
      final cache = FlagCache();

      final result = await cache.load();
      expect(result, isNull);
    });

    test('saves and loads cached flags', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = FlagCache();

      final cached = CachedFlags(
        flags: {'penguinm.springboard': true, 'penguinm.analytics': false},
        tier: 'professional',
        lastFetched: DateTime(2026, 1, 1),
      );

      await cache.save(cached);

      final loaded = await cache.load();
      expect(loaded, isNotNull);
      expect(loaded!.flags, cached.flags);
      expect(loaded.tier, 'professional');
    });

    test('preserves flag values through cache round-trip', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = FlagCache();

      final cached = CachedFlags(
        flags: {
          'penguinm.bool': true,
          'penguinm.string': 'variant-a',
          'penguinm.false': false,
        },
        tier: 'free',
        lastFetched: DateTime(2026, 1, 1, 12, 30),
      );

      await cache.save(cached);
      final loaded = await cache.load();

      expect(loaded!.flags['penguinm.bool'], isTrue);
      expect(loaded.flags['penguinm.string'], 'variant-a');
      expect(loaded.flags['penguinm.false'], isFalse);
    });
  });
}
