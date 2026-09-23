import 'package:penguin_core/penguin_core.dart';
import 'license_entitlement.dart';

/// Source of license tier entitlement for a product installation.
/// Implemented by [PenguinLicenseSource] in production and by a local test
/// fake in package tests — [FeatureFlags] depends only on this interface.
abstract interface class LicenseSource {
  /// Fetches the current entitlement for [productKey]/[installationId],
  /// optionally passing a [licenseKey] when the app holds one.
  Future<Result<LicenseEntitlement>> fetch({
    required String productKey,
    String? licenseKey,
    required String installationId,
  });
}
