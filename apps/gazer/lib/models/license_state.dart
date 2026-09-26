/// Result of the most recent license/feature-flag validation.
///
/// `unknown` means no successful fetch has ever completed and no usable
/// cache exists (blocks streaming per the first-launch rule); `gracePeriod`
/// means the server is unreachable but the cache is within its 7-day grace
/// window.
enum LicenseStatus { unknown, valid, gracePeriod, invalid }

/// Cached license/feature-flag state, persisted as JSON by `LicenseCache`.
///
/// [flags] holds every flag key the server has ever returned; a key absent
/// from this map is treated as OFF by `FeatureFlags`, never as an error.
///
/// Hand-written immutable value class (no code generation): const
/// constructor, value equality, `copyWith`, and manual JSON codec.
class LicenseState {
  /// Creates an immutable license state snapshot.
  const LicenseState({
    required this.status,
    required this.flags,
    this.lastFetched,
    required this.deviceId,
  });

  /// Deserializes a [LicenseState] from JSON (`LicenseCache` reads this
  /// back from `shared_preferences` key `gazer.license.state`).
  factory LicenseState.fromJson(Map<String, dynamic> json) => LicenseState(
    status: LicenseStatus.values.byName(json['status'] as String),
    flags: Map<String, bool>.from(json['flags'] as Map),
    lastFetched: json['lastFetched'] == null
        ? null
        : DateTime.parse(json['lastFetched'] as String),
    deviceId: json['deviceId'] as String,
  );

  /// Pre-first-fetch state for a freshly resolved [deviceId]: unknown
  /// status, no flags, never fetched.
  factory LicenseState.initial(String deviceId) => LicenseState(
    status: LicenseStatus.unknown,
    flags: const {},
    lastFetched: null,
    deviceId: deviceId,
  );

  /// Most recent validation outcome.
  final LicenseStatus status;

  /// Every flag key the server has ever returned.
  final Map<String, bool> flags;

  /// When [flags] was last refreshed from the server, or `null` if never.
  final DateTime? lastFetched;

  /// This install's resolved device id.
  final String deviceId;

  /// Serializes this instance to JSON.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'status': status.name,
    'flags': flags,
    'lastFetched': lastFetched?.toIso8601String(),
    'deviceId': deviceId,
  };

  /// Returns a copy with the given fields replaced.
  LicenseState copyWith({
    LicenseStatus? status,
    Map<String, bool>? flags,
    DateTime? lastFetched,
    String? deviceId,
  }) => LicenseState(
    status: status ?? this.status,
    flags: flags ?? this.flags,
    lastFetched: lastFetched ?? this.lastFetched,
    deviceId: deviceId ?? this.deviceId,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LicenseState) return false;
    if (other.status != status ||
        other.lastFetched != lastFetched ||
        other.deviceId != deviceId) {
      return false;
    }
    if (other.flags.length != flags.length) return false;
    for (final MapEntry<String, bool> entry in flags.entries) {
      if (other.flags[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    status,
    Object.hashAllUnordered(
      flags.entries.map(
        (MapEntry<String, bool> e) => Object.hash(e.key, e.value),
      ),
    ),
    lastFetched,
    deviceId,
  );

  @override
  String toString() =>
      'LicenseState(status: $status, flags: $flags, lastFetched: $lastFetched, '
      'deviceId: $deviceId)';
}
