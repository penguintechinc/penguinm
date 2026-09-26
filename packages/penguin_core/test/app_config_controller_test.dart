import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppConfig _config() {
  return AppConfig(
    productKey: 'gazer',
    appVersion: '1.0.0',
    environment: PenguinEnvironment.prealpha,
    apiBaseUrl: Uri.parse('https://gazer.example.com'),
    licenseServerUrl: 'https://license.penguintech.io',
  );
}

ProviderContainer _buildContainer(KeyValueStore store) {
  return ProviderContainer(
    overrides: [
      initialAppConfigProvider.overrideWithValue(_config()),
      keyValueStoreProvider.overrideWithValue(store),
    ],
  );
}

void main() {
  test(
    'AppConfigController.setApiBaseUrl persists and updates state',
    () async {
      final store = InMemoryKeyValueStore();
      final container = _buildContainer(store);
      addTearDown(container.dispose);

      await container
          .read(appConfigProvider.notifier)
          .setApiBaseUrl(Uri.parse('https://custom.example.com'));

      expect(
        container.read(appConfigProvider).apiBaseUrl,
        Uri.parse('https://custom.example.com'),
      );
      expect(
        await store.read(apiBaseUrlOverrideKey),
        'https://custom.example.com',
      );
    },
  );

  test(
    'AppConfigController.resetApiBaseUrl clears persisted override and restores default',
    () async {
      final store = InMemoryKeyValueStore();
      final container = _buildContainer(store);
      addTearDown(container.dispose);
      final notifier = container.read(appConfigProvider.notifier);

      await notifier.setApiBaseUrl(Uri.parse('https://custom.example.com'));
      await notifier.resetApiBaseUrl();

      expect(
        container.read(appConfigProvider).apiBaseUrl,
        Uri.parse('https://gazer.example.com'),
      );
      expect(await store.read(apiBaseUrlOverrideKey), isNull);
    },
  );

  test('keyValueStoreProvider throws when left unoverridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(keyValueStoreProvider),
      throwsA(
        predicate<Object>((e) => e.toString().contains('UnimplementedError')),
      ),
    );
  });

  test('initialAppConfigProvider throws when left unoverridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(initialAppConfigProvider),
      throwsA(
        predicate<Object>((e) => e.toString().contains('UnimplementedError')),
      ),
    );
  });

  test('SharedPreferencesStore reads, writes, and removes values', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SharedPreferencesStore(prefs);

    expect(await store.read('missing'), isNull);
    await store.write('key', 'value');
    expect(await store.read('key'), 'value');
    await store.remove('key');
    expect(await store.read('key'), isNull);
  });
}
