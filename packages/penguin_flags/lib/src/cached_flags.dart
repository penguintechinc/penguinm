/// Snapshot of flags and license tier persisted by [FlagCache] so a fresh
/// app launch has an immediately usable value before the first network
/// refresh completes. Not itself secret — flag names and a tier string are
/// safe in plain `SharedPreferences`.
class CachedFlags {
  /// Creates a cached-flags snapshot.
  const CachedFlags({
    required this.flags,
    required this.tier,
    required this.lastFetched,
  });

  /// The cached feature flags map (flag key → bool or variant string).
  final Map<String, Object?> flags;

  /// The cached license tier string (`'free'`, `'professional'`, or
  /// `'enterprise'`); stored as a string so cache format stays independent
  /// of the [Object] enum's internal representation.
  final String tier;

  /// When the flags were last fetched successfully.
  final DateTime lastFetched;

  /// Converts to a JSON-safe map for persistence via [FlagCache.save].
  Map<String, Object?> toJson() {
    return {
      'flags': flags,
      'tier': tier,
      'lastFetched': lastFetched.toIso8601String(),
    };
  }

  /// Rebuilds a snapshot from JSON produced by [toJson]; missing or
  /// malformed fields fall back to safe defaults (empty flags, free tier,
  /// now) rather than throwing, so a corrupted cache degrades gracefully.
  factory CachedFlags.fromJson(Map<String, Object?> json) {
    return CachedFlags(
      flags: (json['flags'] as Map<String, Object?>?) ?? {},
      tier: json['tier'] as String? ?? 'free',
      lastFetched:
          DateTime.tryParse(json['lastFetched'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
