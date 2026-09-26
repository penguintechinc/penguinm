import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Minimal persistent key-value store abstraction so [AppConfigController]
/// doesn't depend on `SharedPreferences` directly — swappable for
/// [InMemoryKeyValueStore] in tests.
abstract interface class KeyValueStore {
  /// Reads the string stored at [key], or null if absent.
  Future<String?> read(String key);

  /// Writes [value] at [key], overwriting any existing value.
  Future<void> write(String key, String value);

  /// Removes the value stored at [key], if any.
  Future<void> remove(String key);
}

/// [KeyValueStore] backed by [SharedPreferences] for real app use. Only
/// non-secret config (e.g. a URL) belongs here — tokens and credentials
/// use platform secure storage instead.
class SharedPreferencesStore implements KeyValueStore {
  /// Wraps an already-obtained [SharedPreferences] instance.
  SharedPreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<String?> read(String key) async => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}

/// In-memory [KeyValueStore] for tests — never touches platform storage.
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

/// Storage key for the persisted API base URL override.
const String apiBaseUrlOverrideKey = 'penguin_core.api_base_url_override';

/// The persistence backend for [AppConfigController]'s API base URL
/// override; the app shell overrides this with [SharedPreferencesStore] at
/// startup, tests with [InMemoryKeyValueStore].
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => throw UnimplementedError(
    'override keyValueStoreProvider before reading appConfigProvider',
  ),
);

/// The build-time [AppConfig] (with any persisted override already
/// resolved) that seeds [AppConfigController]; injected by `runPenguinApp`.
final initialAppConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError(
    'override initialAppConfigProvider with AppConfig.fromEnvironment(...)',
  ),
);

/// Runtime override of `AppConfig.apiBaseUrl` (e.g. Gazer's
/// user-selectable domain switcher), persisted across restarts via
/// [KeyValueStore]. The initial [AppConfig] is injected by `runPenguinApp`
/// via [initialAppConfigProvider].
class AppConfigController extends Notifier<AppConfig> {
  @override
  AppConfig build() => ref.watch(initialAppConfigProvider);

  /// Applies [url] as the new API base URL, persists it, and updates
  /// state.
  Future<void> setApiBaseUrl(Uri url) async {
    await ref
        .read(keyValueStoreProvider)
        .write(apiBaseUrlOverrideKey, url.toString());
    state = state.copyWith(apiBaseUrl: url);
  }

  /// Clears the persisted override and restores the build-time default.
  Future<void> resetApiBaseUrl() async {
    await ref.read(keyValueStoreProvider).remove(apiBaseUrlOverrideKey);
    final original = ref.read(initialAppConfigProvider);
    state = state.copyWith(apiBaseUrl: original.apiBaseUrl);
  }
}
