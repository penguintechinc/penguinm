import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_flags/src/license_tier.dart';

void main() {
  group('LicenseTier', () {
    test('free satisfies only free', () {
      expect(LicenseTier.free.satisfies(LicenseTier.free), isTrue);
      expect(LicenseTier.free.satisfies(LicenseTier.professional), isFalse);
      expect(LicenseTier.free.satisfies(LicenseTier.enterprise), isFalse);
    });

    test('professional satisfies free and professional', () {
      expect(LicenseTier.professional.satisfies(LicenseTier.free), isTrue);
      expect(
        LicenseTier.professional.satisfies(LicenseTier.professional),
        isTrue,
      );
      expect(
        LicenseTier.professional.satisfies(LicenseTier.enterprise),
        isFalse,
      );
    });

    test('enterprise satisfies all', () {
      expect(LicenseTier.enterprise.satisfies(LicenseTier.free), isTrue);
      expect(
        LicenseTier.enterprise.satisfies(LicenseTier.professional),
        isTrue,
      );
      expect(LicenseTier.enterprise.satisfies(LicenseTier.enterprise), isTrue);
    });
  });
}
