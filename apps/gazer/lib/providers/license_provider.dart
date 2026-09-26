import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../config/debug_overrides.dart';
import '../models/license_state.dart';
import '../services/device_id.dart';
import '../services/feature_flags.dart';
import '../services/keepalive_scheduler.dart';
import '../services/license_client.dart';

/// Constructs the [LicenseClient] the app talks to; overridden with a fake
/// in tests so no real HTTP call or platform channel is ever hit.
final licenseClientProvider = FutureProvider<LicenseClient>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  final deviceIdProvider = AndroidDeviceIdProvider(
    deviceInfo: DeviceInfoPlugin(),
    packageInfo: packageInfo,
  );
  return LicenseClient(
    client: http.Client(),
    cache: LicenseCache(SharedPreferencesAsync()),
    deviceIdProvider: deviceIdProvider,
    now: DateTime.now,
  );
});

/// Validates the license and fetches feature flags once at startup.
///
/// Not autoDispose: a single validation per app session, not re-fetched on
/// every screen visit — the app shell's separate keepalive timer is what
/// refreshes staleness while foregrounded.
final licenseProvider = FutureProvider<LicenseState>((ref) async {
  final LicenseClient client = await ref.watch(licenseClientProvider.future);
  final LicenseState fetched = await client.validateAndFetchFlags();

  if (!DebugOverrides.enabled) {
    return fetched;
  }

  // Debug-only: force the M1 flags ON so integration tests and local dev
  // don't depend on a reachable license.penguintech.io. Never runs in a
  // release build — DebugOverrides.enabled requires kDebugMode.
  final Map<String, bool> overridden = <String, bool>{...fetched.flags};
  for (final String key in DebugOverrides.flags) {
    overridden[key] = true;
  }
  return fetched.copyWith(
    status: LicenseStatus.valid,
    flags: overridden,
    lastFetched: DateTime.now(),
  );
});

/// Read-only view over [license] for flag checks; never throws — while
/// [license] is loading or has errored, flags default to all-OFF via
/// [LicenseState.initial]'s empty flag map, since [FeatureFlags.isEnabled]
/// treats an absent key as OFF.
final featureFlagsProvider = Provider.autoDispose<FeatureFlags>((ref) {
  final asyncState = ref.watch(licenseProvider);
  final state = asyncState.value ?? LicenseState.initial('');
  return FeatureFlags(state);
});

/// The app-wide [KeepaliveScheduler], pinging the license server every
/// [kLicenseKeepaliveInterval] while foregrounded — [GazerApp] starts it
/// once the first [license] fetch resolves and drives it thereafter via
/// `WidgetsBindingObserver.didChangeAppLifecycleState`.
///
/// `ref.onDispose(scheduler.stop)` guarantees the underlying [Timer] is
/// always cancelled when the provider container is disposed — including
/// in widget tests, where every `pumpGazerApp` call creates a fresh
/// `ProviderScope` that must never leak a pending [Timer] into the next
/// test.
final keepaliveSchedulerProvider = Provider<KeepaliveScheduler>((ref) {
  final scheduler = KeepaliveScheduler(
    ping: () async {
      final LicenseClient client = await ref.read(licenseClientProvider.future);
      await client.keepalive();
    },
    interval: kLicenseKeepaliveInterval,
  );
  ref.onDispose(scheduler.stop);
  return scheduler;
});
