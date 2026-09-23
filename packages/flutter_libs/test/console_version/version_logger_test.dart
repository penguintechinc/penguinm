import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';

void main() {
  group('logVersionToConsole', () {
    test('logs with no optional fields set', () {
      const info = VersionInfo(full: '1.0.0', major: 1, minor: 0, patch: 0);

      expect(() => logVersionToConsole('Elder', info), returnsNormally);
    });

    test('logs with build date, build epoch, environment and metadata', () {
      const info = VersionInfo(
        full: 'v1.2.3.1700000000',
        major: 1,
        minor: 2,
        patch: 3,
        buildEpoch: 1700000000,
        buildDate: '2023-11-14T22:13:20.000Z',
      );

      expect(
        () => logVersionToConsole(
          'Elder',
          info,
          environment: 'beta',
          metadata: const {'source': 'API', 'build': 'ci-42'},
        ),
        returnsNormally,
      );
    });

    test('logs with build date only (no epoch)', () {
      const info = VersionInfo(
        full: 'v2.0.0',
        major: 2,
        minor: 0,
        patch: 0,
        buildDate: '2024-01-01T00:00:00.000Z',
      );

      expect(() => logVersionToConsole('Elder', info), returnsNormally);
    });

    test('logs with build epoch only (no build date)', () {
      const info = VersionInfo(
        full: 'v3.0.0',
        major: 3,
        minor: 0,
        patch: 0,
        buildEpoch: 1700000000,
      );

      expect(() => logVersionToConsole('Elder', info), returnsNormally);
    });

    test('logs with an empty metadata map', () {
      const info = VersionInfo(full: '1.0.0', major: 1, minor: 0, patch: 0);

      expect(
        () => logVersionToConsole(
          'Elder',
          info,
          environment: 'dev',
          metadata: const {},
        ),
        returnsNormally,
      );
    });

    test('uses parseVersion output end to end', () {
      final info = parseVersion('v4.5.6.1710000000');

      expect(
        () => logVersionToConsole('ParsedApp', info, environment: 'prod'),
        returnsNormally,
      );
    });
  });
}
