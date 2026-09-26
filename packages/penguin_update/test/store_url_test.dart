import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_update/src/store_url.dart';

void main() {
  group('storeUrlFor', () {
    test('returns info.storeUrl when provided', () {
      const applicationId = 'io.penguintech.test';
      final expectedUrl = Uri.parse(
        'https://play.google.com/store/apps/details?id=io.penguintech.test',
      );
      final info = ClientVersionInfo(
        latestVersion: '2.0.0',
        storeUrl: expectedUrl,
      );

      final result = storeUrlFor(applicationId, info);

      expect(result, equals(expectedUrl));
    });

    test('returns market:// URL when storeUrl is null', () {
      const applicationId = 'io.penguintech.test';
      final info = ClientVersionInfo(latestVersion: '2.0.0', storeUrl: null);

      final result = storeUrlFor(applicationId, info);

      expect(result.scheme, equals('market'));
      expect(
        result.toString(),
        equals('market://details?id=io.penguintech.test'),
      );
    });

    test('includes applicationId in market URL', () {
      const applicationId = 'io.penguintech.myapp';
      final info = ClientVersionInfo(latestVersion: '2.0.0', storeUrl: null);

      final result = storeUrlFor(applicationId, info);

      expect(result.toString(), contains('myapp'));
    });
  });
}
