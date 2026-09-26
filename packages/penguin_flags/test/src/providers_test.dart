import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_flags/src/config.dart';
import 'package:penguin_flags/src/feature_flags.dart';
import 'package:penguin_flags/src/flag_cache.dart';
import 'package:penguin_flags/src/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

void main() {
  group('providers', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    FlagsConfig config() => FlagsConfig(
      productKey: 'penguinm',
      posthogHost: 'https://posthog.example.com',
      posthogProjectKey: 'test-key',
      licenseServerUrl: Uri.parse('https://license.example.com'),
    );

    test('featureFlagsProvider throws when not overridden', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Riverpod 3 wraps a provider-creation-time throw in a
      // ProviderException; assert on the message rather than the wrapper
      // type to avoid a direct `package:riverpod` dependency just for a
      // type check.
      expect(
        () => container.read(featureFlagsProvider),
        throwsA(
          predicate<Object>(
            (e) => e.toString().contains('featureFlagsProvider not configured'),
          ),
        ),
      );
    });

    test(
      'flagProvider evaluates the overridden FeatureFlags instance',
      () async {
        final flagSource = FakeFlagSource()
          ..setFlagValue('penguinm.feature', true);
        final flags = FeatureFlags(
          config: config(),
          flags: flagSource,
          license: FakeLicenseSource(),
          cache: FlagCache(),
          log: ConsoleLogger(sink: (_) {}),
        );
        await flags.initialize(distinctId: 'test');
        // initialize()'s refresh runs via unawaited(); flush the microtask
        // queue so the fake source's fetch has resolved before reading.
        await Future<void>.delayed(Duration.zero);
        addTearDown(flags.dispose);

        final container = ProviderContainer(
          overrides: [featureFlagsProvider.overrideWithValue(flags)],
        );
        addTearDown(container.dispose);

        expect(container.read(flagProvider('penguinm.feature')), isTrue);
        expect(container.read(flagProvider('penguinm.other')), isFalse);
      },
    );

    test('flagChangesProvider streams FeatureFlags.changes events', () async {
      final flags = FeatureFlags(
        config: config(),
        flags: FakeFlagSource(),
        license: FakeLicenseSource(),
        cache: FlagCache(),
        log: ConsoleLogger(sink: (_) {}),
      );
      await flags.initialize(distinctId: 'test');
      addTearDown(flags.dispose);

      final container = ProviderContainer(
        overrides: [featureFlagsProvider.overrideWithValue(flags)],
      );
      addTearDown(container.dispose);

      final events = <AsyncValue<void>>[];
      final sub = container.listen<AsyncValue<void>>(flagChangesProvider, (
        _,
        next,
      ) {
        events.add(next);
      }, fireImmediately: true);
      addTearDown(sub.close);

      await flags.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(events.any((e) => e.hasValue), isTrue);
    });
  });
}
