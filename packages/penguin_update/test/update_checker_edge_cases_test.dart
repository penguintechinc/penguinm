import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_update/src/update_checker.dart';
import 'package:penguin_update/src/update_status.dart';

class MockPenguinApiClient extends Mock implements PenguinApiClient {}

class MockPenguinLogger extends Mock implements PenguinLogger {}

void main() {
  group('UpdateChecker edge cases', () {
    late MockPenguinApiClient mockApi;
    late MockPenguinLogger mockLogger;
    late UpdateChecker checker;

    setUp(() {
      mockApi = MockPenguinApiClient();
      mockLogger = MockPenguinLogger();
      checker = UpdateChecker(api: mockApi, log: mockLogger);
    });

    test('handles empty minimum version as null', () async {
      final versionInfo = ClientVersionInfo(
        latestVersion: '2.0.0',
        minimumVersion: '',
        storeUrl: null,
      );
      when(
        () => mockApi.fetchClientVersion(),
      ).thenAnswer((_) async => Result.ok(versionInfo));

      final status = await checker.check(currentVersion: '1.5.0');

      expect(status, isA<UpdateAvailable>());
    });

    test('returns unknown for auth failure', () async {
      final failure = AuthFailure(401, 'Unauthorized');
      when(
        () => mockApi.fetchClientVersion(),
      ).thenAnswer((_) async => Result.err(failure));

      final status = await checker.check(currentVersion: '1.0.0');

      expect(status, isA<Unknown>());
    });

    test('returns unknown for server failure', () async {
      final failure = ServerFailure(500, 'Internal Server Error');
      when(
        () => mockApi.fetchClientVersion(),
      ).thenAnswer((_) async => Result.err(failure));

      final status = await checker.check(currentVersion: '1.0.0');

      expect(status, isA<Unknown>());
    });

    test('handles null minimum version gracefully', () async {
      final versionInfo = ClientVersionInfo(
        latestVersion: '2.0.0',
        minimumVersion: null,
        storeUrl: Uri.parse('https://example.com'),
      );
      when(
        () => mockApi.fetchClientVersion(),
      ).thenAnswer((_) async => Result.ok(versionInfo));

      final status = await checker.check(currentVersion: '1.0.0');

      expect(status, isA<UpdateAvailable>());
    });

    test(
      'correctly identifies update required when current below minimum',
      () async {
        final versionInfo = ClientVersionInfo(
          latestVersion: '3.0.0',
          minimumVersion: '2.0.0',
          storeUrl: null,
        );
        when(
          () => mockApi.fetchClientVersion(),
        ).thenAnswer((_) async => Result.ok(versionInfo));

        final status = await checker.check(currentVersion: '1.5.0');

        expect(status, isA<UpdateRequired>());
      },
    );

    test('returns unknown for validation failure', () async {
      final failure = ValidationFailure('version', 'malformed response');
      when(
        () => mockApi.fetchClientVersion(),
      ).thenAnswer((_) async => Result.err(failure));

      final status = await checker.check(currentVersion: '1.0.0');

      expect(status, isA<Unknown>());
      expect((status as Unknown).failure, same(failure));
    });

    test('returns unknown for storage failure', () async {
      final failure = StorageFailure('cache read error');
      when(
        () => mockApi.fetchClientVersion(),
      ).thenAnswer((_) async => Result.err(failure));

      final status = await checker.check(currentVersion: '1.0.0');

      expect(status, isA<Unknown>());
      expect((status as Unknown).failure, same(failure));
    });

    test(
      'current exactly equal to minimum is not required (boundary)',
      () async {
        final versionInfo = ClientVersionInfo(
          latestVersion: '3.0.0',
          minimumVersion: '2.0.0',
          storeUrl: null,
        );
        when(
          () => mockApi.fetchClientVersion(),
        ).thenAnswer((_) async => Result.ok(versionInfo));

        // current == minimum: the check is strictly `<`, so this must NOT be
        // updateRequired.
        final status = await checker.check(currentVersion: '2.0.0');

        expect(status, isA<UpdateAvailable>());
      },
    );

    test('current exactly equal to latest is up to date (boundary)', () async {
      final versionInfo = ClientVersionInfo(
        latestVersion: '2.0.0',
        minimumVersion: '1.0.0',
        storeUrl: null,
      );
      when(
        () => mockApi.fetchClientVersion(),
      ).thenAnswer((_) async => Result.ok(versionInfo));

      final status = await checker.check(currentVersion: '2.0.0');

      expect(status, isA<UpToDate>());
    });

    test('handles pre-release version segments correctly', () async {
      final versionInfo = ClientVersionInfo(
        latestVersion: '2.0.0',
        minimumVersion: null,
        storeUrl: null,
      );
      when(
        () => mockApi.fetchClientVersion(),
      ).thenAnswer((_) async => Result.ok(versionInfo));

      // 1.9.0-beta.1 < 2.0.0 per semver pre-release ordering.
      final status = await checker.check(currentVersion: '1.9.0-beta.1');

      expect(status, isA<UpdateAvailable>());
    });

    test('returns unknown for empty current version string', () async {
      final versionInfo = ClientVersionInfo(
        latestVersion: '2.0.0',
        minimumVersion: null,
        storeUrl: null,
      );
      when(
        () => mockApi.fetchClientVersion(),
      ).thenAnswer((_) async => Result.ok(versionInfo));

      final status = await checker.check(currentVersion: '');

      expect(status, isA<Unknown>());
    });
  });
}
