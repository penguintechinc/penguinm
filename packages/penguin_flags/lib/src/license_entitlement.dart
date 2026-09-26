import 'license_tier.dart';

/// A single validated entitlement response from the license server
/// (`POST /api/v2/validate`): the resolved [tier], optional expiry, and any
/// feature-level flags the server returned alongside the tier.
class LicenseEntitlement {
  /// Creates a license entitlement.
  const LicenseEntitlement({
    required this.tier,
    this.expiresAt,
    this.features = const {},
  });

  /// The license tier this installation is entitled to.
  final LicenseTier tier;

  /// When the license expires, if the server reported one; null means no
  /// expiry was provided (e.g. a perpetual or bypass-domain entitlement).
  final DateTime? expiresAt;

  /// Feature-specific entitlements (e.g. `{'whitelabelling': true}`),
  /// distinct from the general PostHog flags served by [FlagSource].
  final Map<String, Object?> features;

  /// Parses an entitlement from the license server's JSON response body;
  /// an unrecognised or missing `tier` falls back to [LicenseTier.free] so
  /// a malformed response never grants more than the narrowest tier.
  factory LicenseEntitlement.fromJson(Map<String, Object?> json) {
    final tierStr = json['tier'] as String?;
    final tier = switch (tierStr) {
      'free' => LicenseTier.free,
      'professional' => LicenseTier.professional,
      'enterprise' => LicenseTier.enterprise,
      _ => LicenseTier.free,
    };

    DateTime? expiresAt;
    if (json['expiresAt'] is String) {
      expiresAt = DateTime.tryParse(json['expiresAt'] as String);
    }

    return LicenseEntitlement(
      tier: tier,
      expiresAt: expiresAt,
      features: (json['features'] as Map<String, Object?>?) ?? {},
    );
  }
}
