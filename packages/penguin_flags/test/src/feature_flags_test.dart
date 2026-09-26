import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_flags/src/config.dart';
import 'package:penguin_flags/src/feature_flags.dart';
import 'package:penguin_flags/src/flag_cache.dart';
import 'package:penguin_flags/src/license_tier.dart';
import 'package:penguin_testing/penguin_testing.dart'
    hide FakeFlagSource, FakeLicenseSource;
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

void main() {
  group('FeatureFlags', () {
    late FakeFlagSource flagSource;
    late FakeLicenseSource licenseSource;
    late ConsoleLogger logger;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      flagSource = FakeFlagSource();
      licenseSource = FakeLicenseSource();
      logger = ConsoleLogger(sink: (_) {});
    });

    FlagsConfig config({bool bypassDomain = false}) => FlagsConfig(
      productKey: 'penguinm',
      posthogHost: 'https://posthog.example.com',
      posthogProjectKey: 'test-key',
      licenseServerUrl: Uri.parse('https://license.example.com'),
      bypassDomain: bypassDomain,
    );

    test('unseen flag returns false', () async {
      final flags = FeatureFlags(
        config: config(),
        flags: flagSource,
        license: licenseSource,
        cache: FlagCache(),
        log: logger,
      );

      await flags.initialize(distinctId: 'user-123');
      expect(flags.isEnabled('penguinm.unknown'), isFalse);
    });

    test('enabled bool flag returns true', () async {
      flagSource.setFlagValue('penguinm.springboard', true);

      final flags = FeatureFlags(
        config: config(),
        flags: flagSource,
        license: licenseSource,
        cache: FlagCache(),
        log: logger,
      );

      await flags.initialize(distinctId: 'user-123');
      await Future<void>.delayed(Duration.zero);
      expect(flags.isEnabled('penguinm.springboard'), isTrue);
    });

    test('disabled bool flag returns false', () async {
      flagSource.setFlagValue('penguinm.analytics', false);

      final flags = FeatureFlags(
        config: config(),
        flags: flagSource,
        license: licenseSource,
        cache: FlagCache(),
        log: logger,
      );

      await flags.initialize(distinctId: 'user-123');
      await Future<void>.delayed(Duration.zero);
      expect(flags.isEnabled('penguinm.analytics'), isFalse);
    });

    test('variant string flag returns enabled', () async {
      flagSource.setFlagValue('penguinm.search', 'variant-a');

      final flags = FeatureFlags(
        config: config(),
        flags: flagSource,
        license: licenseSource,
        cache: FlagCache(),
        log: logger,
      );

      await flags.initialize(distinctId: 'user-123');
      await Future<void>.delayed(Duration.zero);
      expect(flags.isEnabled('penguinm.search'), isTrue);
    });

    test('empty variant string flag returns disabled', () async {
      flagSource.setFlagValue('penguinm.search', '');

      final flags = FeatureFlags(
        config: config(),
        flags: flagSource,
        license: licenseSource,
        cache: FlagCache(),
        log: logger,
      );

      await flags.initialize(distinctId: 'user-123');
      await Future<void>.delayed(Duration.zero);
      expect(flags.isEnabled('penguinm.search'), isFalse);
    });

    test('cached flags served before refresh completes', () async {
      SharedPreferences.setMockInitialValues({
        'penguin_flags_cache':
            '{"flags":{"penguinm.cached":true},"tier":"professional",'
            '"lastFetched":"2026-01-01T00:00:00.000Z"}',
      });

      final gate = Completer<void>();
      flagSource
        ..fetchGate = gate.future
        ..setFlagValue('penguinm.cached', false);

      final flags = FeatureFlags(
        config: config(),
        flags: flagSource,
        license: licenseSource,
        cache: FlagCache(),
        log: logger,
      );

      await flags.initialize(distinctId: 'user-123');

      // Background refresh is still awaiting the gate — the cached
      // snapshot (loaded synchronously by initialize) must already be
      // visible, not the pending network value.
      expect(flags.isEnabled('penguinm.cached'), isTrue);
      expect(flags.tier, LicenseTier.professional);

      gate.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Refresh has now completed and overwritten the cached value.
      expect(flags.isEnabled('penguinm.cached'), isFalse);
    });

    test('refresh failure keeps cache intact', () async {
      flagSource.setFlagValue('penguinm.springboard', true);

      final flags = FeatureFlags(
        config: config(),
        flags: flagSource,
        license: licenseSource,
        cache: FlagCache(),
        log: logger,
      );

      await flags.initialize(distinctId: 'user-123');
      await Future<void>.delayed(Duration.zero);
      expect(flags.isEnabled('penguinm.springboard'), isTrue);
      final lastRefreshed = flags.lastRefreshed;
      expect(lastRefreshed, isNotNull);

      flagSource.throwOnFetch = true;
      await flags.refresh();

      expect(flags.isEnabled('penguinm.springboard'), isTrue);
      expect(flags.lastRefreshed, lastRefreshed);
    });

    test('initialize never throws when the cache fails to load', () async {
      final flags = FeatureFlags(
        config: config(),
        flags: flagSource,
        license: licenseSource,
        cache: ThrowingFlagCache(),
        log: logger,
      );

      await flags.initialize(distinctId: 'user-123');
      expect(flags.isEnabled('penguinm.unknown'), isFalse);
      expect(flags.tier, LicenseTier.free);
    });

    test('isEnabled asserts key prefix in debug', () {
      final flags = FeatureFlags(
        config: config(),
        flags: flagSource,
        license: licenseSource,
        cache: FlagCache(),
        log: logger,
      );

      expect(() => flags.isEnabled('waddlebot.feature'), throwsAssertionError);
    });

    test('tier returns enterprise for bypass domain', () async {
      final flags = FeatureFlags(
        config: config(bypassDomain: true),
        flags: flagSource,
        license: licenseSource,
        cache: FlagCache(),
        log: logger,
      );

      await flags.initialize(distinctId: 'user-123');
      expect(flags.tier, LicenseTier.enterprise);
      expect(flags.hasTier(LicenseTier.enterprise), isTrue);
    });

    test('tier returns license entitlement when available', () async {
      licenseSource.setTier(LicenseTier.professional);

      final flags = FeatureFlags(
        config: config(),
        flags: flagSource,
        license: licenseSource,
        cache: FlagCache(),
        log: logger,
      );

      await flags.initialize(distinctId: 'user-123');
      await Future<void>.delayed(Duration.zero);
      expect(flags.tier, LicenseTier.professional);
    });

    test('tier returns free when nothing available', () async {
      final flags = FeatureFlags(
        config: config(),
        flags: flagSource,
        license: licenseSource,
        cache: FlagCache(),
        log: logger,
      );

      await flags.initialize(distinctId: 'user-123');
      expect(flags.tier, LicenseTier.free);
    });

    test('hasTier checks tier satisfaction ordering', () async {
      licenseSource.setTier(LicenseTier.professional);

      final flags = FeatureFlags(
        config: config(),
        flags: flagSource,
        license: licenseSource,
        cache: FlagCache(),
        log: logger,
      );

      await flags.initialize(distinctId: 'user-123');
      await Future<void>.delayed(Duration.zero);

      expect(flags.hasTier(LicenseTier.free), isTrue);
      expect(flags.hasTier(LicenseTier.professional), isTrue);
      expect(flags.hasTier(LicenseTier.enterprise), isFalse);
    });

    test('changes stream emits on successful refresh', () async {
      final flags = FeatureFlags(
        config: config(),
        flags: flagSource,
        license: licenseSource,
        cache: FlagCache(),
        log: logger,
      );

      await flags.initialize(distinctId: 'user-123');
      await Future<void>.delayed(Duration.zero);

      var emitted = false;
      flags.changes.listen((_) => emitted = true);

      flagSource.setFlagValue('penguinm.analytics', true);
      await flags.refresh();
      // `changes` is a broadcast StreamController: `add()` delivers to
      // listeners on a microtask, so the listener hasn't run yet the
      // instant `refresh()` returns — flush the microtask queue first.
      await Future<void>.delayed(Duration.zero);

      expect(emitted, isTrue);
    });

    test('refresh defaults distinctId to system when omitted', () async {
      final flags = FeatureFlags(
        config: config(),
        flags: flagSource,
        license: licenseSource,
        cache: FlagCache(),
        log: logger,
      );

      await flags.initialize(distinctId: 'user-123');
      await flags.refresh();
      expect(flags.lastRefreshed, isNotNull);
    });

    test('refresh saves cache and notifies when flags succeed but license '
        'fails', () async {
      final clock = FakeClock(DateTime.utc(2026, 1, 1));
      licenseSource.setTier(LicenseTier.professional);

      final flags = FeatureFlags(
        config: config(),
        flags: flagSource,
        license: licenseSource,
        cache: FlagCache(),
        log: logger,
        clock: clock,
      );

      // Baseline: both sources succeed once, establishing a last-known
      // professional tier and a first lastRefreshed timestamp.
      await flags.initialize(distinctId: 'user-123');
      await Future<void>.delayed(Duration.zero);
      expect(flags.tier, LicenseTier.professional);
      final baselineRefreshed = flags.lastRefreshed;
      expect(baselineRefreshed, isNotNull);

      // Flags succeed with a new value; license now fails.
      clock.advance(const Duration(minutes: 15));
      flagSource.setFlagValue('penguinm.new_feature', true);
      licenseSource.returnErrorOnFetch = true;

      var emitted = false;
      flags.changes.listen((_) => emitted = true);

      await flags.refresh();
      await Future<void>.delayed(Duration.zero);

      // The successful flags fetch must still commit: new flag visible,
      // last-known (professional) tier kept, refresh timestamp advances,
      // and listeners are notified — none of this may be gated behind
      // the failed license fetch.
      expect(flags.isEnabled('penguinm.new_feature'), isTrue);
      expect(flags.tier, LicenseTier.professional);
      expect(flags.lastRefreshed, isNot(baselineRefreshed));
      expect(emitted, isTrue);

      // The on-disk cache must not be stale either — a cold start after
      // this refresh must see the new flag, not the pre-refresh state.
      final reloaded = await FlagCache().load();
      expect(reloaded, isNotNull);
      expect(reloaded!.flags['penguinm.new_feature'], isTrue);
      expect(reloaded.tier, 'professional');
    });

    test('refresh saves cache and notifies when license succeeds but flags '
        'fail', () async {
      final clock = FakeClock(DateTime.utc(2026, 1, 1));
      flagSource.setFlagValue('penguinm.springboard', true);

      final flags = FeatureFlags(
        config: config(),
        flags: flagSource,
        license: licenseSource,
        cache: FlagCache(),
        log: logger,
        clock: clock,
      );

      await flags.initialize(distinctId: 'user-123');
      await Future<void>.delayed(Duration.zero);
      expect(flags.isEnabled('penguinm.springboard'), isTrue);
      final baselineRefreshed = flags.lastRefreshed;
      expect(baselineRefreshed, isNotNull);

      // License succeeds with a new tier; flags now fail.
      clock.advance(const Duration(minutes: 15));
      flagSource.returnErrorOnFetch = true;
      licenseSource.setTier(LicenseTier.enterprise);

      var emitted = false;
      flags.changes.listen((_) => emitted = true);

      await flags.refresh();
      await Future<void>.delayed(Duration.zero);

      // Last-known flags survive the failed flags fetch; the successful
      // license fetch still commits its new tier, advances the refresh
      // timestamp, and notifies listeners.
      expect(flags.isEnabled('penguinm.springboard'), isTrue);
      expect(flags.tier, LicenseTier.enterprise);
      expect(flags.lastRefreshed, isNot(baselineRefreshed));
      expect(emitted, isTrue);

      final reloaded = await FlagCache().load();
      expect(reloaded, isNotNull);
      expect(reloaded!.flags['penguinm.springboard'], isTrue);
      expect(reloaded.tier, 'enterprise');
    });

    test(
      'refresh keeps cache and does not notify when both sources fail',
      () async {
        final clock = FakeClock(DateTime.utc(2026, 1, 1));
        flagSource.setFlagValue('penguinm.springboard', true);
        licenseSource.setTier(LicenseTier.professional);

        final flags = FeatureFlags(
          config: config(),
          flags: flagSource,
          license: licenseSource,
          cache: FlagCache(),
          log: logger,
          clock: clock,
        );

        await flags.initialize(distinctId: 'user-123');
        await Future<void>.delayed(Duration.zero);
        final baselineRefreshed = flags.lastRefreshed;
        expect(baselineRefreshed, isNotNull);

        clock.advance(const Duration(minutes: 15));
        flagSource.returnErrorOnFetch = true;
        licenseSource.returnErrorOnFetch = true;

        var emitted = false;
        flags.changes.listen((_) => emitted = true);

        await flags.refresh();
        await Future<void>.delayed(Duration.zero);

        // Graceful degradation: both sources failed, so nothing commits —
        // last-known flags/tier are kept, no notification, and
        // lastRefreshed must not silently advance to a refresh that
        // fetched nothing new.
        expect(flags.isEnabled('penguinm.springboard'), isTrue);
        expect(flags.tier, LicenseTier.professional);
        expect(flags.lastRefreshed, baselineRefreshed);
        expect(emitted, isFalse);
      },
    );
  });
}
