import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_testing/penguin_testing.dart';
import 'package:penguincloud/features/profile/data/profile_repository.dart';
import 'package:penguincloud/features/profile/presentation/profile_providers.dart';

import '../../../fixtures/users.dart';

AppConfig _config() => AppConfig(
  productKey: 'penguincloud',
  appVersion: '0.1.0',
  environment: PenguinEnvironment.prealpha,
  apiBaseUrl: Uri.parse('https://api.penguincloud.example'),
  licenseServerUrl: 'https://license.penguintech.io',
);

void main() {
  group('profileRepositoryProvider', () {
    test('builds a ProfileRepository wired to apiClientProvider', () {
      final api = PenguinApiClient(
        config: _config(),
        tokens: FakeTokenProvider(initialToken: 'tok'),
        inner: ScriptedHttpClient(),
      );
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      final repository = container.read(profileRepositoryProvider);

      expect(repository, isA<ProfileRepository>());
      expect(repository.api, same(api));
      expect(repository.profilePath, '/api/v1/auth/profile');
    });
  });

  group('profileProvider', () {
    test(
      'resolves by calling the real ProfileRepository.fetchProfile',
      () async {
        final httpClient = ScriptedHttpClient()
          ..queueResponse(
            statusCode: 200,
            body: jsonEncode(profileJsonFixtures[0]),
          );
        final api = PenguinApiClient(
          config: _config(),
          tokens: FakeTokenProvider(initialToken: 'tok'),
          inner: httpClient,
        );
        final container = ProviderContainer(
          overrides: [apiClientProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);

        final result = await container.read(profileProvider.future);

        expect(result.isOk, isTrue);
        expect(result.valueOrNull!.email, 'penny.waddle@example.com');
        expect(httpClient.seenRequests.single.url.path, '/api/v1/auth/profile');
      },
    );
  });
}
