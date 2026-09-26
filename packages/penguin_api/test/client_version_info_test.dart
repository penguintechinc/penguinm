import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/src/client_version_info.dart';

void main() {
  group('ClientVersionInfo', () {
    test('fromJson parses required fields', () {
      final info = ClientVersionInfo.fromJson({'latestVersion': '1.2.3'});

      expect(info.latestVersion, equals('1.2.3'));
      expect(info.minimumVersion, isNull);
      expect(info.storeUrl, isNull);
      expect(info.releaseNotes, isNull);
    });

    test('fromJson parses all fields', () {
      final info = ClientVersionInfo.fromJson({
        'latestVersion': '1.2.3',
        'minimumVersion': '1.0.0',
        'storeUrl': 'https://example.com/store',
        'releaseNotes': 'Bug fixes',
      });

      expect(info.latestVersion, equals('1.2.3'));
      expect(info.minimumVersion, equals('1.0.0'));
      expect(info.storeUrl, equals(Uri.parse('https://example.com/store')));
      expect(info.releaseNotes, equals('Bug fixes'));
    });

    test('fromJson handles null optional fields', () {
      final info = ClientVersionInfo.fromJson({
        'latestVersion': '1.0.0',
        'minimumVersion': null,
        'storeUrl': null,
        'releaseNotes': null,
      });

      expect(info.latestVersion, equals('1.0.0'));
      expect(info.minimumVersion, isNull);
      expect(info.storeUrl, isNull);
      expect(info.releaseNotes, isNull);
    });

    test('fromJson throws on missing latestVersion', () {
      expect(() => ClientVersionInfo.fromJson({}), throwsFormatException);
    });
  });
}
