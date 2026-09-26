/// Local test doubles for [FlagSource]/[LicenseSource]/[FlagCache] used
/// across `penguin_flags` tests. `penguin_testing` will generalise
/// equivalents of these for every package once it is built (see the
/// T18 task brief); until then they live here.
library;

import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_flags/src/cached_flags.dart';
import 'package:penguin_flags/src/flag_cache.dart';
import 'package:penguin_flags/src/flag_source.dart';
import 'package:penguin_flags/src/license_entitlement.dart';
import 'package:penguin_flags/src/license_source.dart';
import 'package:penguin_flags/src/license_tier.dart';

/// In-memory [FlagSource] double: flags are set directly via
/// [setFlagValue] instead of coming from a real PostHog call. Supports an
/// optional [fetchGate] to hold `fetch()` open (for testing the window
/// before a background refresh completes) and [throwOnFetch] to simulate a
/// network failure.
class FakeFlagSource implements FlagSource {
  final Map<String, Object?> _flags = {};

  /// When set, `fetch()` awaits this before returning — lets a test
  /// observe state while a refresh is still in flight.
  Future<void>? fetchGate;

  /// When true, `fetch()` throws instead of returning a result, simulating
  /// an unrecoverable network failure that should abort the whole refresh.
  bool throwOnFetch = false;

  /// When true, `fetch()` returns a [Result.err] instead of throwing —
  /// simulating an ordinary, recoverable failure (e.g. a non-200 response)
  /// that the caller handles via `Result.isOk`, distinct from
  /// [throwOnFetch]'s unrecoverable-exception path.
  bool returnErrorOnFetch = false;

  /// Sets the value [fetch] will report for flag [key].
  void setFlagValue(String key, Object? value) {
    _flags[key] = value;
  }

  @override
  Future<Result<Map<String, Object?>>> fetch({
    required String distinctId,
    Map<String, String> properties = const {},
  }) async {
    if (fetchGate != null) await fetchGate;
    if (throwOnFetch) {
      throw Exception('Simulated flag source failure');
    }
    if (returnErrorOnFetch) {
      return const Result.err(NetworkFailure('Simulated flag fetch failure'));
    }
    return Result.ok(Map<String, Object?>.from(_flags));
  }
}

/// In-memory [LicenseSource] double: the tier is set directly via
/// [setTier] instead of coming from a real license-server call. Supports
/// the same [fetchGate]/[throwOnFetch] hooks as [FakeFlagSource].
class FakeLicenseSource implements LicenseSource {
  LicenseTier _tier = LicenseTier.free;

  /// When set, `fetch()` awaits this before returning.
  Future<void>? fetchGate;

  /// When true, `fetch()` throws instead of returning a result, simulating
  /// an unrecoverable network failure that should abort the whole refresh.
  bool throwOnFetch = false;

  /// When true, `fetch()` returns a [Result.err] instead of throwing —
  /// simulating an ordinary, recoverable failure (e.g. a non-200 response)
  /// that the caller handles via `Result.isOk`, distinct from
  /// [throwOnFetch]'s unrecoverable-exception path.
  bool returnErrorOnFetch = false;

  /// Sets the tier [fetch] will report.
  void setTier(LicenseTier tier) {
    _tier = tier;
  }

  @override
  Future<Result<LicenseEntitlement>> fetch({
    required String productKey,
    String? licenseKey,
    required String installationId,
  }) async {
    if (fetchGate != null) await fetchGate;
    if (throwOnFetch) {
      throw Exception('Simulated license source failure');
    }
    if (returnErrorOnFetch) {
      return const Result.err(
        NetworkFailure('Simulated license fetch failure'),
      );
    }
    return Result.ok(LicenseEntitlement(tier: _tier));
  }
}

/// [FlagCache] subclass whose [load] always throws, used to exercise
/// [FeatureFlags.initialize]'s outer error handling (a corrupt/unavailable
/// cache must never crash startup).
class ThrowingFlagCache extends FlagCache {
  @override
  Future<CachedFlags?> load() async {
    throw Exception('Simulated cache failure');
  }
}
