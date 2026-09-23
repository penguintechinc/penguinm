import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_testing/penguin_testing.dart';
import 'package:penguin_update/penguin_update.dart';

void main() {
  group('FakeUpdateChecker', () {
    test('defaults to upToDate and records the checked version', () async {
      final checker = FakeUpdateChecker();
      final status = await checker.check(currentVersion: '1.0.0');
      expect(status, const UpdateStatus.upToDate());
      expect(checker.checkedVersions, ['1.0.0']);
    });

    test('honours a custom default status', () async {
      final failure = const UpdateStatus.unknown(NetworkFailure('offline'));
      final checker = FakeUpdateChecker(failure);
      final status = await checker.check(currentVersion: '1.0.0');
      expect(status, failure);
    });

    test(
      'queue drains scripted statuses in FIFO order before falling back',
      () async {
        final checker = FakeUpdateChecker();
        const unknown = UpdateStatus.unknown(NetworkFailure('timeout'));
        checker.queue(unknown);

        final first = await checker.check(currentVersion: '1.0.0');
        final second = await checker.check(currentVersion: '1.0.0');

        expect(first, unknown);
        expect(second, const UpdateStatus.upToDate());
      },
    );

    test('records every currentVersion passed to check', () async {
      final checker = FakeUpdateChecker();
      await checker.check(currentVersion: '1.0.0');
      await checker.check(currentVersion: '1.1.0');
      expect(checker.checkedVersions, ['1.0.0', '1.1.0']);
    });

    test('is substitutable for the real UpdateChecker via '
        'updateCheckerProvider.overrideWithValue', () async {
      const scripted = UpdateStatus.unknown(NetworkFailure('offline'));
      final fake = FakeUpdateChecker()..queue(scripted);

      final container = ProviderContainer(
        overrides: [updateCheckerProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      // Reading the provider returns exactly the fake — the override
      // point (`updateCheckerProvider`) accepts it as a real UpdateChecker,
      // not merely a same-shaped duck type.
      final checker = container.read(updateCheckerProvider);
      expect(checker, same(fake));

      final status = await checker.check(currentVersion: '1.0.0');
      expect(status, scripted);
    });

    test('flows through updateStatusProvider end-to-end (it reads '
        'updateCheckerProvider, per the penguin_update fix routed alongside '
        'this task)', () async {
      const scripted = UpdateStatus.updateRequired(
        ClientVersionInfo(latestVersion: '9.9.9', minimumVersion: '9.0.0'),
      );
      final fake = FakeUpdateChecker()..queue(scripted);

      final container = ProviderContainer(
        overrides: [
          updateCheckerProvider.overrideWithValue(fake),
          initialAppConfigProvider.overrideWithValue(
            AppConfig(
              productKey: 'penguinm',
              appVersion: '1.0.0',
              environment: PenguinEnvironment.prealpha,
              apiBaseUrl: Uri.parse('https://api.example.com'),
              licenseServerUrl: 'https://license.penguintech.io',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final status = await container.read(updateStatusProvider.future);

      expect(status, scripted);
      expect(fake.checkedVersions, ['1.0.0']);
    });
  });
}
