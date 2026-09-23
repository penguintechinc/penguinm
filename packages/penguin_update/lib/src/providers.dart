import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';

import 'update_checker.dart';
import 'update_status.dart';

/// Provider for the update status from a non-blocking startup check.
///
/// Fires once at startup and caches the result. Reads the checker from
/// [updateCheckerProvider] (rather than constructing its own) so overriding
/// [updateCheckerProvider] with a fake or differently-configured checker
/// actually changes the status apps see. The check is non-blocking and
/// never throws; if it times out or fails, Unknown status is returned.
final updateStatusProvider = FutureProvider.autoDispose<UpdateStatus>((
  ref,
) async {
  final checker = ref.watch(updateCheckerProvider);
  final config = ref.watch(appConfigProvider);

  // Get the current app version from the config
  final currentVersion = config.appVersion;

  // Perform the check (never throws, times out at 5s)
  return checker.check(currentVersion: currentVersion);
});

/// Provider for the UpdateChecker instance.
///
/// Requires the API client and logger to be available.
final updateCheckerProvider = Provider<UpdateChecker>((ref) {
  final api = ref.watch(apiClientProvider);
  final logger = ref.watch(loggerProvider);
  return UpdateChecker(api: api, log: logger);
});
