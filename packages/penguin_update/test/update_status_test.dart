import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_update/src/update_status.dart';

void main() {
  group('UpdateStatus', () {
    group('UpToDate', () {
      test('can be created with upToDate factory', () {
        const status = UpdateStatus.upToDate();
        expect(status, isA<UpToDate>());
      });

      test('implements equality', () {
        const status1 = UpdateStatus.upToDate();
        const status2 = UpdateStatus.upToDate();
        expect(status1, equals(status2));
      });

      test('implements hashCode', () {
        const status1 = UpdateStatus.upToDate();
        const status2 = UpdateStatus.upToDate();
        expect(status1.hashCode, equals(status2.hashCode));
      });
    });

    group('UpdateAvailable', () {
      test('can be created with updateAvailable factory', () {
        final info = ClientVersionInfo(latestVersion: '2.0.0');
        final status = UpdateStatus.updateAvailable(info);
        expect(status, isA<UpdateAvailable>());
      });

      test('stores version info', () {
        final info = ClientVersionInfo(latestVersion: '2.0.0');
        final status = UpdateStatus.updateAvailable(info) as UpdateAvailable;
        expect(status.info, equals(info));
      });

      test('implements equality', () {
        final info = ClientVersionInfo(latestVersion: '2.0.0');
        final status1 = UpdateStatus.updateAvailable(info);
        final status2 = UpdateStatus.updateAvailable(info);
        expect(status1, equals(status2));
      });

      test('implements hashCode', () {
        final info = ClientVersionInfo(latestVersion: '2.0.0');
        final status1 = UpdateStatus.updateAvailable(info);
        final status2 = UpdateStatus.updateAvailable(info);
        expect(status1.hashCode, equals(status2.hashCode));
      });

      test('inequality with different info', () {
        final info1 = ClientVersionInfo(latestVersion: '2.0.0');
        final info2 = ClientVersionInfo(latestVersion: '2.1.0');
        final status1 = UpdateStatus.updateAvailable(info1);
        final status2 = UpdateStatus.updateAvailable(info2);
        expect(status1, isNot(equals(status2)));
      });
    });

    group('UpdateRequired', () {
      test('can be created with updateRequired factory', () {
        final info = ClientVersionInfo(latestVersion: '2.0.0');
        final status = UpdateStatus.updateRequired(info);
        expect(status, isA<UpdateRequired>());
      });

      test('stores version info', () {
        final info = ClientVersionInfo(latestVersion: '2.0.0');
        final status = UpdateStatus.updateRequired(info) as UpdateRequired;
        expect(status.info, equals(info));
      });

      test('implements equality', () {
        final info = ClientVersionInfo(latestVersion: '2.0.0');
        final status1 = UpdateStatus.updateRequired(info);
        final status2 = UpdateStatus.updateRequired(info);
        expect(status1, equals(status2));
      });

      test('implements hashCode', () {
        final info = ClientVersionInfo(latestVersion: '2.0.0');
        final status1 = UpdateStatus.updateRequired(info);
        final status2 = UpdateStatus.updateRequired(info);
        expect(status1.hashCode, equals(status2.hashCode));
      });
    });

    group('Unknown', () {
      test('can be created with unknown factory', () {
        final failure = NetworkFailure('Connection failed');
        final status = UpdateStatus.unknown(failure);
        expect(status, isA<Unknown>());
      });

      test('stores failure', () {
        final failure = NetworkFailure('Connection failed');
        final status = UpdateStatus.unknown(failure) as Unknown;
        expect(status.failure, equals(failure));
      });

      test('implements equality', () {
        final failure = NetworkFailure('Connection failed');
        final status1 = UpdateStatus.unknown(failure);
        final status2 = UpdateStatus.unknown(failure);
        expect(status1, equals(status2));
      });

      test('implements hashCode', () {
        final failure = NetworkFailure('Connection failed');
        final status1 = UpdateStatus.unknown(failure);
        final status2 = UpdateStatus.unknown(failure);
        expect(status1.hashCode, equals(status2.hashCode));
      });

      test('inequality with different failures', () {
        final failure1 = NetworkFailure('Connection failed');
        final failure2 = NetworkFailure('Timeout');
        final status1 = UpdateStatus.unknown(failure1);
        final status2 = UpdateStatus.unknown(failure2);
        expect(status1, isNot(equals(status2)));
      });
    });

    group('Cross-type inequality', () {
      test('UpToDate != UpdateAvailable', () {
        final info = ClientVersionInfo(latestVersion: '2.0.0');
        final status1 = const UpdateStatus.upToDate();
        final status2 = UpdateStatus.updateAvailable(info);
        expect(status1, isNot(equals(status2)));
      });

      test('UpdateAvailable != UpdateRequired', () {
        final info = ClientVersionInfo(latestVersion: '2.0.0');
        final status1 = UpdateStatus.updateAvailable(info);
        final status2 = UpdateStatus.updateRequired(info);
        expect(status1, isNot(equals(status2)));
      });

      test('UpdateRequired != Unknown', () {
        final info = ClientVersionInfo(latestVersion: '2.0.0');
        final failure = NetworkFailure('Error');
        final status1 = UpdateStatus.updateRequired(info);
        final status2 = UpdateStatus.unknown(failure);
        expect(status1, isNot(equals(status2)));
      });
    });
  });
}
