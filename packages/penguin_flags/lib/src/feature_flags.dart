import 'dart:async';
import 'package:penguin_core/penguin_core.dart';
import 'cached_flags.dart';
import 'config.dart';
import 'flag_cache.dart';
import 'flag_source.dart';
import 'license_source.dart';
import 'license_tier.dart';

/// Orchestrates PostHog feature flags and license-tier entitlement behind a
/// single offline-safe API: [initialize] serves a cached snapshot
/// instantly, then refreshes from the network in the background. Every
/// method is exception-free — network/server/storage failures degrade to
/// the last-known cached value, never a crash.
class FeatureFlags {
  /// Creates a FeatureFlags instance from its collaborators; call
  /// [initialize] once at app startup before reading flags/tier. [clock]
  /// is overridable in tests, defaulting to the real system clock.
  FeatureFlags({
    required this._config,
    required this._flags,
    required this._license,
    required this._cache,
    required this._log,
    Clock? clock,
  }) : _clock = clock ?? const SystemClock(),
       _changesController = StreamController<void>.broadcast();

  final FlagsConfig _config;
  final FlagSource _flags;
  final LicenseSource _license;
  final FlagCache _cache;
  final PenguinLogger _log;
  final Clock _clock;
  final StreamController<void> _changesController;

  Map<String, Object?> _cachedFlags = {};
  LicenseTier _cachedTier = LicenseTier.free;
  DateTime? _lastRefreshed;

  /// Emits an event whenever a successful [refresh] changes flags or tier;
  /// [FeatureGate] watches this (via `flagChangesProvider`) to rebuild.
  Stream<void> get changes => _changesController.stream;

  /// When flags/tier were last successfully refreshed from the network;
  /// null before the first successful refresh completes.
  DateTime? get lastRefreshed => _lastRefreshed;

  /// The current license tier: a bypass domain always reports
  /// [LicenseTier.enterprise]; otherwise the last-known entitlement tier
  /// (cached across restarts, [LicenseTier.free] until anything is known).
  LicenseTier get tier {
    if (_config.bypassDomain) {
      return LicenseTier.enterprise;
    }
    return _cachedTier;
  }

  /// True when the current [tier] satisfies [required] (tiers are
  /// cumulative — see [LicenseTier.satisfies]).
  bool hasTier(LicenseTier required) => tier.satisfies(required);

  /// Loads the cached snapshot (instant) so [isEnabled]/[tier] are usable
  /// immediately, then kicks off a background refresh for [distinctId].
  /// Never throws — a cache-load failure is logged and leaves defaults
  /// (all flags off, free tier) in place.
  Future<void> initialize({required String distinctId}) async {
    try {
      final cached = await _cache.load();
      if (cached != null) {
        _cachedFlags = cached.flags;
        _cachedTier = switch (cached.tier) {
          'professional' => LicenseTier.professional,
          'enterprise' => LicenseTier.enterprise,
          _ => LicenseTier.free,
        };
        _lastRefreshed = cached.lastFetched;
      }

      unawaited(_refreshInternal(distinctId));
    } catch (e, st) {
      _log.log(
        LogLevel.error,
        'Failed to initialize flags',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// True when [key] is enabled: a boolean-true flag or a non-empty variant
  /// string. A never-seen key returns false. [key] must be prefixed with
  /// `${_config.productKey}.` — an assertion enforces this in debug/test
  /// builds; release builds (assertions stripped) simply find no such key
  /// in `_cachedFlags` and fall through to the unseen-key false below.
  bool isEnabled(String key) {
    final prefix = '${_config.productKey}.';
    assert(key.startsWith(prefix), 'Flag key must start with $prefix');

    final value = _cachedFlags[key];
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String && value.isNotEmpty) return true;
    return false;
  }

  /// Manually triggers a refresh for [distinctId] (defaults to `'system'`
  /// when omitted); useful for a pull-to-refresh action or tests. Never
  /// throws — see [_refreshInternal].
  Future<void> refresh({String? distinctId}) async {
    await _refreshInternal(distinctId ?? 'system');
  }

  /// Fetches flags (if PostHog is configured) and the license entitlement
  /// independently — each source commits its own in-memory state on
  /// success regardless of whether the other source failed, so a
  /// PostHog-only or license-only outage never discards the half that
  /// succeeded. Whenever at least one source succeeded, the combined
  /// state (fresh value from the source that succeeded, last-known value
  /// from the one that didn't) is persisted to [_cache] once,
  /// [_lastRefreshed] advances, and [changes] emits. If both fail, nothing
  /// is written and [_lastRefreshed] does not advance — graceful
  /// degradation on the existing cache. Any thrown exception — as opposed
  /// to a [Result.err] returned normally — aborts the whole refresh,
  /// leaving the existing cache/[_lastRefreshed] untouched; either failure
  /// mode is logged at WARN.
  Future<void> _refreshInternal(String distinctId) async {
    try {
      var anySucceeded = false;

      if (_config.posthogHost != null && _config.posthogProjectKey != null) {
        final flagsResult = await _flags.fetch(distinctId: distinctId);

        if (flagsResult.isOk) {
          _cachedFlags = flagsResult.valueOrNull!;
          anySucceeded = true;
        } else {
          _log.log(LogLevel.warn, 'Failed to fetch flags');
        }
      }

      final licenseResult = await _license.fetch(
        productKey: _config.productKey,
        installationId: distinctId,
      );

      if (licenseResult.isOk) {
        _cachedTier = licenseResult.valueOrNull!.tier;
        anySucceeded = true;
      } else {
        _log.log(LogLevel.warn, 'Failed to fetch license');
      }

      if (anySucceeded) {
        _lastRefreshed = _clock.now();

        await _cache.save(
          CachedFlags(
            flags: _cachedFlags,
            tier: _tierToString(_cachedTier),
            lastFetched: _lastRefreshed!,
          ),
        );

        _changesController.add(null);
      }
    } catch (e, st) {
      _log.log(
        LogLevel.warn,
        'Refresh failed, keeping cache',
        error: e,
        stackTrace: st,
      );
    }
  }

  String _tierToString(LicenseTier tier) {
    return switch (tier) {
      LicenseTier.free => 'free',
      LicenseTier.professional => 'professional',
      LicenseTier.enterprise => 'enterprise',
    };
  }

  /// Closes the [changes] stream; call when this instance is no longer
  /// needed (app shells hold one instance for the app's lifetime).
  void dispose() {
    _changesController.close();
  }
}
