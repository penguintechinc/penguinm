/// Barrel import verification.
library;

import 'package:penguin_flags/penguin_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('barrel exports all public types', () {
    // Verify key types are exported
    expect(LicenseTier.free, isNotNull);
    expect(FlagCache, isNotNull);
    expect(FeatureFlags, isNotNull);
    expect(FeatureGate, isNotNull);
    expect(PostHogFlagSource, isNotNull);
    expect(PenguinLicenseSource, isNotNull);
  });

  test('barrel exports CachedFlags for custom FlagCache implementations', () {
    // A consumer implementing their own FlagCache-compatible storage needs
    // CachedFlags without reaching into `src/` via implementation_imports.
    final cached = CachedFlags(
      flags: const {'penguinm.example': true},
      tier: 'free',
      lastFetched: DateTime(2026, 1, 1),
    );

    expect(cached.flags['penguinm.example'], isTrue);
    expect(cached.tier, 'free');

    final roundTripped = CachedFlags.fromJson(cached.toJson());
    expect(roundTripped.flags, cached.flags);
    expect(roundTripped.tier, cached.tier);
  });
}
