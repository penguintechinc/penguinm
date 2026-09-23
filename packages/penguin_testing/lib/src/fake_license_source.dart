import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_flags/penguin_flags.dart';

/// Scripted [LicenseSource] fake: [fetch] returns a settable [Result]
/// instead of calling the license server, recording every request it was
/// called with.
class FakeLicenseSource implements LicenseSource {
  /// Creates a fake license source that returns [initialResult] (defaults
  /// to a successful free-tier entitlement) until [setResult] changes it.
  FakeLicenseSource({Result<LicenseEntitlement>? initialResult})
    : _result =
          initialResult ??
          const Result.ok(LicenseEntitlement(tier: LicenseTier.free));

  Result<LicenseEntitlement> _result;

  /// Every request passed to [fetch] so far, in order.
  final List<({String productKey, String? licenseKey, String installationId})>
  requests =
      <({String productKey, String? licenseKey, String installationId})>[];

  /// Changes the [Result] the next [fetch] call returns.
  void setResult(Result<LicenseEntitlement> result) {
    _result = result;
  }

  @override
  Future<Result<LicenseEntitlement>> fetch({
    required String productKey,
    String? licenseKey,
    required String installationId,
  }) async {
    requests.add((
      productKey: productKey,
      licenseKey: licenseKey,
      installationId: installationId,
    ));
    return _result;
  }
}
