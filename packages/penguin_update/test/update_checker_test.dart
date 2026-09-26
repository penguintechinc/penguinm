import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_update/src/update_checker.dart';
import 'package:penguin_update/src/update_status.dart';

class MockPenguinApiClient extends Mock implements PenguinApiClient {}

class MockPenguinLogger extends Mock implements PenguinLogger {}

void main() {
  group('UpdateChecker', () {
    late MockPenguinApiClient mockApi;
    late MockPenguinLogger mockLogger;
    late UpdateChecker checker;

    setUp(() {
      mockApi = MockPenguinApiClient();
      mockLogger = MockPenguinLogger();
      checker = UpdateChecker(api: mockApi, log: mockLogger);
    });

    test('returns upToDate when current >= latest', () async {
      when(() => mockApi.fetchClientVersion()).thenAnswer(
        (_) async => Result.ok(
          ClientVersionInfo(
            latestVersion: '1.0.0',
            minimumVersion: null,
            storeUrl: null,
          ),
        ),
      );

      final status = await checker.check(currentVersion: '1.0.0');

      expect(status, isA<UpToDate>());
    });

    test(
      'returns updateAvailable when current < latest and >= minimum',
      () async {
        final versionInfo = ClientVersionInfo(
          latestVersion: '2.0.0',
          minimumVersion: '1.0.0',
          storeUrl: Uri.parse('https://example.com/app'),
        );
        when(
          () => mockApi.fetchClientVersion(),
        ).thenAnswer((_) async => Result.ok(versionInfo));

        final status = await checker.check(currentVersion: '1.5.0');

        expect(status, isA<UpdateAvailable>());
      },
    );

    test('returns updateRequired when current < minimum', () async {
      final versionInfo = ClientVersionInfo(
        latestVersion: '2.0.0',
        minimumVersion: '1.5.0',
        storeUrl: Uri.parse('https://example.com/app'),
      );
      when(
        () => mockApi.fetchClientVersion(),
      ).thenAnswer((_) async => Result.ok(versionInfo));

      final status = await checker.check(currentVersion: '1.0.0');

      expect(status, isA<UpdateRequired>());
    });

    test('returns unknown on API failure', () async {
      final failure = NetworkFailure('Connection failed');
      when(
        () => mockApi.fetchClientVersion(),
      ).thenAnswer((_) async => Result.err(failure));

      final status = await checker.check(currentVersion: '1.0.0');

      expect(status, isA<Unknown>());
    });

    test('returns unknown on unparseable current version', () async {
      final versionInfo = ClientVersionInfo(
        latestVersion: '2.0.0',
        minimumVersion: null,
        storeUrl: null,
      );
      when(
        () => mockApi.fetchClientVersion(),
      ).thenAnswer((_) async => Result.ok(versionInfo));

      final status = await checker.check(currentVersion: 'invalid');

      expect(status, isA<Unknown>());
    });

    test('strips +build suffix from versions', () async {
      final versionInfo = ClientVersionInfo(
        latestVersion: '2.0.0+123',
        minimumVersion: '1.0.0+456',
        storeUrl: null,
      );
      when(
        () => mockApi.fetchClientVersion(),
      ).thenAnswer((_) async => Result.ok(versionInfo));

      final status = await checker.check(currentVersion: '1.5.0+789');

      expect(status, isA<UpdateAvailable>());
    });

    test('completes within 5 seconds timeout', () async {
      when(() => mockApi.fetchClientVersion()).thenAnswer(
        (_) => Future.delayed(
          const Duration(milliseconds: 100),
          () => Result.ok(ClientVersionInfo(latestVersion: '2.0.0')),
        ),
      );

      final stopwatch = Stopwatch()..start();
      await checker.check(currentVersion: '1.0.0');
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
    });

    testWidgets(
      'returns unknown when the API never responds within 5 seconds',
      (WidgetTester tester) async {
        // The API call hangs forever; only the 5s timeout branch can
        // resolve check(). testWidgets runs inside a fake-async test zone,
        // so tester.pump(duration) elapses virtual time without a real
        // wait (no fake_async pubspec dependency required).
        when(
          () => mockApi.fetchClientVersion(),
        ).thenAnswer((_) => Completer<Result<ClientVersionInfo>>().future);

        UpdateStatus? result;
        unawaited(
          checker
              .check(currentVersion: '1.0.0')
              .then((status) => result = status),
        );

        // Not yet resolved before the timeout elapses.
        await tester.pump(const Duration(seconds: 4));
        expect(result, isNull);

        // Crossing the 5s boundary resolves via the timeout branch.
        await tester.pump(const Duration(seconds: 2));

        expect(result, isA<Unknown>());
        expect((result as Unknown).failure, isA<NetworkFailure>());
      },
    );

    test(
      'returns unknown when API response has invalid latest version',
      () async {
        final versionInfo = ClientVersionInfo(
          latestVersion: 'not-a-version',
          minimumVersion: null,
          storeUrl: null,
        );
        when(
          () => mockApi.fetchClientVersion(),
        ).thenAnswer((_) async => Result.ok(versionInfo));

        final status = await checker.check(currentVersion: '1.0.0');

        expect(status, isA<Unknown>());
      },
    );

    test(
      'returns unknown when API response has invalid minimum version',
      () async {
        final versionInfo = ClientVersionInfo(
          latestVersion: '2.0.0',
          minimumVersion: 'not-a-version',
          storeUrl: null,
        );
        when(
          () => mockApi.fetchClientVersion(),
        ).thenAnswer((_) async => Result.ok(versionInfo));

        final status = await checker.check(currentVersion: '1.0.0');

        expect(status, isA<Unknown>());
      },
    );
  });
}
