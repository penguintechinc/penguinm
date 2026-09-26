import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gazer_settings.dart';
import '../services/gazer_log.dart';
import '../services/settings_repository.dart';

/// The [SettingsRepository] implementation the app uses; overridden in
/// tests with a fake so [SettingsNotifier] never touches real storage.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SecureSettingsRepository(
    secure: const FlutterSecureStorage(),
    prefs: SharedPreferencesAsync(),
  ),
);

/// Loads, holds, and persists the user's [GazerSettings].
///
/// Not autoDispose: settings must survive navigation between HomeScreen and
/// SettingsScreen without re-reading storage on every visit.
///
/// Bound to `settingsProvider`, not `settingsNotifierProvider`, matching
/// riverpod_generator's `Notifier$`-stripping convention that named this
/// provider before the codegen was removed — every consumer already
/// imports `settingsProvider`.
class SettingsNotifier extends AsyncNotifier<GazerSettings> {
  @override
  Future<GazerSettings> build() async {
    final GazerSettings settings = await ref
        .watch(settingsRepositoryProvider)
        .load();
    GazerLog.verbose = settings.debugLogs;
    return settings;
  }

  /// Persists [s] via the repository and updates provider state so every
  /// listener (HomeScreen enablement, StatusPanel) sees the new settings.
  /// Also re-applies [GazerLog.verbose] so toggling Settings > Developer
  /// > Debug logs takes effect immediately, without an app restart.
  Future<void> save(GazerSettings s) async {
    await ref.read(settingsRepositoryProvider).save(s);
    GazerLog.verbose = s.debugLogs;
    state = AsyncData(s);
  }
}

/// Riverpod entry point for [SettingsNotifier].
final settingsProvider = AsyncNotifierProvider<SettingsNotifier, GazerSettings>(
  SettingsNotifier.new,
);
