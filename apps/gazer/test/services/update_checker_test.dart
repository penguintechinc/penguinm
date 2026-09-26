import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gazer/services/update_checker.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
  });

  late _MockClient client;

  setUp(() {
    client = _MockClient();
  });

  http.Response releasesResponse(List<Map<String, dynamic>> releases) =>
      http.Response(jsonEncode(releases), 200);

  group('UpdateChecker.check', () {
    test('a newer gazer-v tag returns UpdateInfo', () async {
      when(() => client.get(any())).thenAnswer(
        (_) async => releasesResponse([
          {
            'tag_name': 'gazer-v1.3.0',
            'html_url':
                'https://github.com/penguintechinc/waddlebot/releases/tag/gazer-v1.3.0',
          },
        ]),
      );
      final checker = UpdateChecker(client: client, currentVersion: '1.2.0');

      final info = await checker.check();

      expect(info, isNotNull);
      expect(info!.latestVersion, '1.3.0');
      expect(info.currentVersion, '1.2.0');
      expect(
        info.releaseUrl,
        Uri.parse(
          'https://github.com/penguintechinc/waddlebot/releases/tag/gazer-v1.3.0',
        ),
      );
    });

    test('an equal tag returns null', () async {
      when(() => client.get(any())).thenAnswer(
        (_) async => releasesResponse([
          {
            'tag_name': 'gazer-v1.2.0',
            'html_url': 'https://example.com/gazer-v1.2.0',
          },
        ]),
      );
      final checker = UpdateChecker(client: client, currentVersion: '1.2.0');

      expect(await checker.check(), isNull);
    });

    test('non-gazer tags are ignored', () async {
      when(() => client.get(any())).thenAnswer(
        (_) async => releasesResponse([
          {'tag_name': 'v1.9.0', 'html_url': 'https://example.com/v1.9.0'},
          {
            'tag_name': 'backend-v2.0.0',
            'html_url': 'https://example.com/backend-v2.0.0',
          },
        ]),
      );
      final checker = UpdateChecker(client: client, currentVersion: '1.2.0');

      expect(await checker.check(), isNull);
    });

    test('a malformed release list returns null', () async {
      when(() => client.get(any())).thenAnswer(
        // A JSON string, not a list -- the `as List<dynamic>` cast throws,
        // caught by UpdateChecker.check's try-catch.
        (_) async => http.Response(jsonEncode('not-a-list'), 200),
      );
      final checker = UpdateChecker(client: client, currentVersion: '1.2.0');

      expect(await checker.check(), isNull);
    });

    test('a network error returns null', () async {
      when(
        () => client.get(any()),
      ).thenThrow(http.ClientException('connection timed out'));
      final checker = UpdateChecker(client: client, currentVersion: '1.2.0');

      expect(await checker.check(), isNull);
    });

    test('semver compare treats 1.10.0 as newer than 1.9.9', () async {
      when(() => client.get(any())).thenAnswer(
        (_) async => releasesResponse([
          {
            'tag_name': 'gazer-v1.10.0',
            'html_url': 'https://example.com/gazer-v1.10.0',
          },
        ]),
      );
      final checker = UpdateChecker(client: client, currentVersion: '1.9.9');

      final info = await checker.check();

      expect(info, isNotNull);
      expect(info!.latestVersion, '1.10.0');
    });
  });
}
