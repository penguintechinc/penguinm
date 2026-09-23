import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_flags/penguin_flags.dart';
import 'package:penguin_testing/penguin_testing.dart';

void main() {
  group('FakeLicenseSource', () {
    test('defaults to a successful free-tier entitlement', () async {
      final source = FakeLicenseSource();
      final result = await source.fetch(
        productKey: 'waddlebot',
        installationId: 'installation-1',
      );
      expect(result.isOk, isTrue);
      expect(result.valueOrNull?.tier, LicenseTier.free);
    });

    test('records every request', () async {
      final source = FakeLicenseSource();
      await source.fetch(
        productKey: 'waddlebot',
        licenseKey: 'lic-123',
        installationId: 'installation-1',
      );

      expect(source.requests, [
        (
          productKey: 'waddlebot',
          licenseKey: 'lic-123',
          installationId: 'installation-1',
        ),
      ]);
    });

    test('setResult changes the entitlement returned', () async {
      final source = FakeLicenseSource();
      source.setResult(
        const Result.ok(LicenseEntitlement(tier: LicenseTier.enterprise)),
      );
      final result = await source.fetch(
        productKey: 'waddlebot',
        installationId: 'installation-1',
      );
      expect(result.valueOrNull?.tier, LicenseTier.enterprise);
    });

    test('can be scripted to fail', () async {
      final source = FakeLicenseSource();
      source.setResult(const Result.err(NetworkFailure('unreachable')));
      final result = await source.fetch(
        productKey: 'waddlebot',
        installationId: 'installation-1',
      );
      expect(result.isOk, isFalse);
    });
  });
}
