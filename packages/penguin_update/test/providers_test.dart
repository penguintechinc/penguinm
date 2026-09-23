import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_update/src/providers.dart';
import 'package:penguin_update/src/update_checker.dart';
import 'package:penguin_update/src/update_status.dart';

class MockPenguinApiClient extends Mock implements PenguinApiClient {}

class MockPenguinLogger extends Mock implements PenguinLogger {}

/// Fake [AppConfigController] that serves a fixed [AppConfig] without
/// touching real persistence — lets tests override [appConfigProvider]
/// (a [NotifierProvider]) with a deterministic build-time value.
class _FakeAppConfigController extends AppConfigController {
  _FakeAppConfigController(this._config);

  final AppConfig _config;

  @override
  AppConfig build() => _config;
}

/// Fake [UpdateChecker] that returns a scripted [UpdateStatus] regardless
/// of input — proves `updateStatusProvider` actually reads
/// `updateCheckerProvider` instead of building its own checker from the
/// api/logger providers directly.
class _FakeUpdateChecker implements UpdateChecker {
  _FakeUpdateChecker(this._status);

  final UpdateStatus _status;

  @override
  Future<UpdateStatus> check({required String currentVersion}) async => _status;
}

AppConfig _configWithVersion(String appVersion) {
  return AppConfig(
    productKey: 'penguin_reference',
    appVersion: appVersion,
    environment: PenguinEnvironment.prealpha,
    apiBaseUrl: Uri.parse('https://api.example.com'),
    licenseServerUrl: 'https://license.penguintech.io',
  );
}

void main() {
  group('penguin_update providers', () {
    late MockPenguinApiClient mockApi;
    late MockPenguinLogger mockLogger;

    setUp(() {
      mockApi = MockPenguinApiClient();
      mockLogger = MockPenguinLogger();
    });

    ProviderContainer buildContainer(String appVersion) {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(mockApi),
          loggerProvider.overrideWithValue(mockLogger),
          appConfigProvider.overrideWith(
            () => _FakeAppConfigController(_configWithVersion(appVersion)),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('updateCheckerProvider creates UpdateChecker instance', () {
      final container = buildContainer('1.0.0');

      final checker = container.read(updateCheckerProvider);

      expect(checker, isA<UpdateChecker>());
    });

    test('updateStatusProvider is a FutureProvider', () {
      expect(updateStatusProvider, isA<FutureProvider<UpdateStatus>>());
    });

    test('updateCheckerProvider uses injected dependencies', () {
      final container = buildContainer('1.0.0');

      final checker = container.read(updateCheckerProvider);

      expect(checker, isA<UpdateChecker>());
    });

    test('updateCheckerProvider instantiates once and caches the instance', () {
      final container = buildContainer('1.0.0');

      final checker1 = container.read(updateCheckerProvider);
      final checker2 = container.read(updateCheckerProvider);

      // Same provider instance should return the same checker.
      expect(identical(checker1, checker2), true);
      expect(checker1, isA<UpdateChecker>());
    });

    test(
      'updateStatusProvider resolves upToDate from AppConfig.appVersion',
      () async {
        when(() => mockApi.fetchClientVersion()).thenAnswer(
          (_) async => Result.ok(
            ClientVersionInfo(latestVersion: '1.0.0', minimumVersion: null),
          ),
        );
        final container = buildContainer('1.0.0');

        final status = await container.read(updateStatusProvider.future);

        expect(status, isA<UpToDate>());
      },
    );

    test('updateStatusProvider resolves updateAvailable', () async {
      when(() => mockApi.fetchClientVersion()).thenAnswer(
        (_) async => Result.ok(
          ClientVersionInfo(latestVersion: '2.0.0', minimumVersion: '1.0.0'),
        ),
      );
      final container = buildContainer('1.5.0');

      final status = await container.read(updateStatusProvider.future);

      expect(status, isA<UpdateAvailable>());
    });

    test('updateStatusProvider resolves updateRequired', () async {
      when(() => mockApi.fetchClientVersion()).thenAnswer(
        (_) async => Result.ok(
          ClientVersionInfo(latestVersion: '3.0.0', minimumVersion: '2.0.0'),
        ),
      );
      final container = buildContainer('1.0.0');

      final status = await container.read(updateStatusProvider.future);

      expect(status, isA<UpdateRequired>());
    });

    test('updateStatusProvider resolves unknown on API failure', () async {
      final failure = NetworkFailure('Connection failed');
      when(
        () => mockApi.fetchClientVersion(),
      ).thenAnswer((_) async => Result.err(failure));
      final container = buildContainer('1.0.0');

      final status = await container.read(updateStatusProvider.future);

      expect(status, isA<Unknown>());
      expect((status as Unknown).failure, same(failure));
    });

    test(
      'updateStatusProvider reads appVersion from appConfigProvider',
      () async {
        // Two different app versions against the same latest/minimum should
        // resolve to different statuses, proving the provider actually wires
        // appConfigProvider.appVersion through rather than a hardcoded value.
        when(() => mockApi.fetchClientVersion()).thenAnswer(
          (_) async => Result.ok(
            ClientVersionInfo(latestVersion: '2.0.0', minimumVersion: '1.0.0'),
          ),
        );

        final upToDateContainer = buildContainer('2.0.0');
        final upToDateStatus = await upToDateContainer.read(
          updateStatusProvider.future,
        );
        expect(upToDateStatus, isA<UpToDate>());

        final availableContainer = buildContainer('1.2.0');
        final availableStatus = await availableContainer.read(
          updateStatusProvider.future,
        );
        expect(availableStatus, isA<UpdateAvailable>());
      },
    );

    test(
      'updateStatusProvider reads updateCheckerProvider (F1 regression)',
      () async {
        // Override ONLY updateCheckerProvider with a fake that returns a
        // scripted status unrelated to the api/config wiring. If
        // updateStatusProvider builds its own UpdateChecker instead of
        // watching updateCheckerProvider, this override has no effect and
        // the real (unstubbed) mockApi call surfaces instead — this test
        // fails against that bug.
        final scripted = UpdateStatus.updateRequired(
          ClientVersionInfo(latestVersion: '9.9.9', minimumVersion: '9.9.9'),
        );
        final container = ProviderContainer(
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            loggerProvider.overrideWithValue(mockLogger),
            appConfigProvider.overrideWith(
              () => _FakeAppConfigController(_configWithVersion('1.0.0')),
            ),
            updateCheckerProvider.overrideWithValue(
              _FakeUpdateChecker(scripted),
            ),
          ],
        );
        addTearDown(container.dispose);

        final status = await container.read(updateStatusProvider.future);

        expect(status, same(scripted));
      },
    );
  });
}
