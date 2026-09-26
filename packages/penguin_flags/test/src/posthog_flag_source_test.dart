import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:penguin_flags/src/posthog_flag_source.dart';

void main() {
  group('PostHogFlagSource', () {
    test('parses bool flags', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), contains('/decide?v=3'));
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['api_key'], 'test-project-key');
        expect(body['distinct_id'], 'user-123');
        return http.Response(
          jsonEncode({
            'featureFlags': <String, Object?>{
              'penguinm.springboard': true,
              'penguinm.analytics': false,
            },
          }),
          200,
        );
      });

      final source = PostHogFlagSource(
        host: Uri.parse('https://posthog.example.com'),
        projectKey: 'test-project-key',
        client: client,
      );

      final result = await source.fetch(distinctId: 'user-123');
      expect(result.isOk, isTrue);
      final flags = result.valueOrNull!;
      expect(flags['penguinm.springboard'], isTrue);
      expect(flags['penguinm.analytics'], isFalse);
    });

    test('parses the posthog_decide.json fixture', () async {
      final fixture = File(
        'test/fixtures/posthog_decide.json',
      ).readAsStringSync();

      final client = MockClient((request) async {
        return http.Response(fixture, 200);
      });

      final source = PostHogFlagSource(
        host: Uri.parse('https://posthog.example.com'),
        projectKey: 'test-project-key',
        client: client,
      );

      final result = await source.fetch(distinctId: 'user-123');
      expect(result.isOk, isTrue);
      final flags = result.valueOrNull!;
      expect(flags['penguinm.springboard'], isTrue);
      expect(flags['penguinm.analytics'], isFalse);
      expect(flags['penguinm.advanced_search'], 'variant-a');
    });

    test('parses variant string flags', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'featureFlags': <String, Object?>{'penguinm.search': 'variant-a'},
          }),
          200,
        );
      });

      final source = PostHogFlagSource(
        host: Uri.parse('https://posthog.example.com'),
        projectKey: 'test-project-key',
        client: client,
      );

      final result = await source.fetch(distinctId: 'user-123');
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!['penguinm.search'], 'variant-a');
    });

    test('sends person_properties', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['person_properties'], {'email': 'test@example.com'});
        return http.Response(
          jsonEncode({'featureFlags': <String, Object?>{}}),
          200,
        );
      });

      final source = PostHogFlagSource(
        host: Uri.parse('https://posthog.example.com'),
        projectKey: 'test-project-key',
        client: client,
      );

      await source.fetch(
        distinctId: 'user-123',
        properties: {'email': 'test@example.com'},
      );
    });

    test('returns NetworkFailure on connection error', () async {
      final client = MockClient((request) async {
        throw Exception('Connection failed');
      });

      final source = PostHogFlagSource(
        host: Uri.parse('https://posthog.example.com'),
        projectKey: 'test-project-key',
        client: client,
      );

      final result = await source.fetch(distinctId: 'user-123');
      expect(result.isOk, isFalse);
    });

    test('returns ServerFailure on non-200 response', () async {
      final client = MockClient((request) async {
        return http.Response('{}', 500);
      });

      final source = PostHogFlagSource(
        host: Uri.parse('https://posthog.example.com'),
        projectKey: 'test-project-key',
        client: client,
      );

      final result = await source.fetch(distinctId: 'user-123');
      expect(result.isOk, isFalse);
    });

    test('returns an error result on malformed JSON shape', () async {
      final client = MockClient((request) async {
        // 'featureFlags' is a string, not a map: the `as Map<...>?` cast in
        // PostHogFlagSource throws a TypeError, which must be caught and
        // turned into Result.err rather than escaping.
        return http.Response(jsonEncode({'featureFlags': 'not-a-map'}), 200);
      });

      final source = PostHogFlagSource(
        host: Uri.parse('https://posthog.example.com'),
        projectKey: 'test-project-key',
        client: client,
      );

      final result = await source.fetch(distinctId: 'user-123');
      expect(result.isOk, isFalse);
    });
  });
}
