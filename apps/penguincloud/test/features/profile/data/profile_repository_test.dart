import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_testing/penguin_testing.dart';
import 'package:penguincloud/features/profile/data/profile_repository.dart';

import '../../../fixtures/users.dart';

AppConfig _config() => AppConfig(
  productKey: 'penguincloud',
  appVersion: '0.1.0',
  environment: PenguinEnvironment.prealpha,
  apiBaseUrl: Uri.parse('https://api.penguincloud.example'),
  licenseServerUrl: 'https://license.penguintech.io',
);

final _userJson = profileJsonFixtures[0];

void main() {
  group('ProfileRepository.fetchProfile', () {
    test('decodes a successful response into a User', () async {
      final httpClient = ScriptedHttpClient()
        ..queueResponse(statusCode: 200, body: jsonEncode(_userJson));
      final api = PenguinApiClient(
        config: _config(),
        tokens: FakeTokenProvider(initialToken: 'valid-token'),
        inner: httpClient,
      );
      final repository = ProfileRepository(api: api);

      final result = await repository.fetchProfile();

      expect(result.isOk, isTrue);
      final user = result.valueOrNull!;
      expect(user.id, 'user-0001');
      expect(user.email, 'penny.waddle@example.com');
      expect(user.name, 'Penny Waddle');
      expect(user.roles, ['admin']);
      expect(httpClient.seenRequests.single.url.path, '/api/v1/auth/profile');
    });

    test(
      'retries after a 401 by refreshing the token and replaying the request',
      () async {
        final httpClient = ScriptedHttpClient()
          ..queueResponse(statusCode: 401, body: '{}')
          ..queueResponse(statusCode: 200, body: jsonEncode(_userJson));
        final tokens = FakeTokenProvider(initialToken: 'expired-token');
        final api = PenguinApiClient(
          config: _config(),
          tokens: tokens,
          inner: httpClient,
        );
        final repository = ProfileRepository(api: api);

        final result = await repository.fetchProfile();

        expect(result.isOk, isTrue);
        expect(result.valueOrNull!.email, 'penny.waddle@example.com');
        expect(tokens.refreshCallCount, 1);
        expect(httpClient.seenRequests, hasLength(2));
        // The replayed request carries the freshly refreshed token, not
        // the original expired one.
        expect(
          httpClient.seenRequests[1].headers['authorization'],
          isNot(contains('expired-token')),
        );
      },
    );

    test('surfaces AuthFailure when refresh also fails after a 401', () async {
      final httpClient = ScriptedHttpClient()
        ..queueResponse(statusCode: 401, body: '{}');
      final tokens = FakeTokenProvider(
        initialToken: 'expired-token',
        refreshSucceeds: false,
      );
      final api = PenguinApiClient(
        config: _config(),
        tokens: tokens,
        inner: httpClient,
      );
      final repository = ProfileRepository(api: api);

      final result = await repository.fetchProfile();

      expect(result.isOk, isFalse);
      result.fold(
        (_) => fail('expected an error'),
        (failure) => expect(failure, isA<AuthFailure>()),
      );
      // No replay attempted — refresh failed, so only the original
      // request was sent.
      expect(httpClient.seenRequests, hasLength(1));
    });

    test('surfaces a server failure for a 500 response', () async {
      final httpClient = ScriptedHttpClient()
        ..queueResponse(statusCode: 500, body: '{"error":"boom"}');
      final api = PenguinApiClient(
        config: _config(),
        tokens: FakeTokenProvider(initialToken: 'tok'),
        inner: httpClient,
        retry: const RetryPolicy(maxAttempts: 1),
      );
      final repository = ProfileRepository(api: api);

      final result = await repository.fetchProfile();

      expect(result.isOk, isFalse);
      result.fold(
        (_) => fail('expected an error'),
        (failure) => expect(failure, isA<ServerFailure>()),
      );
    });

    test('decodes a fixture with no name field (name stays null)', () async {
      final httpClient = ScriptedHttpClient()
        ..queueResponse(
          statusCode: 200,
          body: jsonEncode(profileJsonFixtures[3]),
        );
      final api = PenguinApiClient(
        config: _config(),
        tokens: FakeTokenProvider(initialToken: 'tok'),
        inner: httpClient,
      );
      final repository = ProfileRepository(api: api);

      final result = await repository.fetchProfile();

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.name, isNull);
      expect(result.valueOrNull!.roles, isEmpty);
    });

    test('uses the configured profilePath', () async {
      final httpClient = ScriptedHttpClient()
        ..queueResponse(statusCode: 200, body: jsonEncode(_userJson));
      final api = PenguinApiClient(
        config: _config(),
        tokens: FakeTokenProvider(initialToken: 'tok'),
        inner: httpClient,
      );
      final repository = ProfileRepository(
        api: api,
        profilePath: '/custom/profile',
      );

      await repository.fetchProfile();

      expect(httpClient.seenRequests.single.url.path, '/custom/profile');
    });
  });
}
