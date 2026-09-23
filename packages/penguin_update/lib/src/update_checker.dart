import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:pub_semver/pub_semver.dart';

import 'update_status.dart';

/// Checks for app updates by comparing versions against the API.
///
/// Makes a non-blocking call to the version endpoint, parses semantic
/// versions, and determines whether an update is available or required.
/// Never throws; timeouts and API errors are converted to Unknown status.
class UpdateChecker {
  /// Creates an update checker with the given API client and logger.
  UpdateChecker({required this._api, required this._log});

  final PenguinApiClient _api;
  final PenguinLogger _log;

  /// Checks for updates against the version API.
  ///
  /// Compares the [currentVersion] (parsed as semantic version) against the
  /// version info from /api/v1/client/version. Returns the appropriate status:
  /// upToDate, updateAvailable, updateRequired, or unknown (on any error).
  ///
  /// The check is non-blocking and times out after 5 seconds, returning
  /// unknown if the API does not respond in time. Never throws.
  Future<UpdateStatus> check({required String currentVersion}) async {
    try {
      // Parse current version, stripping +build suffix
      final currentVersionStr = currentVersion.split('+').first;
      final current = Version.parse(currentVersionStr);

      // Fetch version info with 5-second timeout
      final resultFuture = _api.fetchClientVersion();
      final timeoutFuture = Future<Result<ClientVersionInfo>>.delayed(
        const Duration(seconds: 5),
        () => Result.err(NetworkFailure('Update check timed out')),
      );

      final result = await Future.any([resultFuture, timeoutFuture]);

      return result.fold((info) => _checkVersions(current, info), (failure) {
        _log.debug(
          'Update check failed',
          attributes: {'error': failure.message},
        );
        return UpdateStatus.unknown(failure);
      });
    } catch (e, st) {
      _log.log(LogLevel.debug, 'Update check error', error: e, stackTrace: st);
      return UpdateStatus.unknown(UnknownFailure(e, st));
    }
  }

  /// Compares versions and returns the appropriate status.
  UpdateStatus _checkVersions(Version current, ClientVersionInfo info) {
    try {
      // Parse latest version, stripping +build suffix
      final latestStr = info.latestVersion.split('+').first;
      final latest = Version.parse(latestStr);

      // Check if minimum version is specified and parse it
      Version? minimum;
      if (info.minimumVersion != null && info.minimumVersion!.isNotEmpty) {
        final minimumStr = info.minimumVersion!.split('+').first;
        minimum = Version.parse(minimumStr);
      }

      // Check if update is required (below minimum)
      if (minimum != null && current < minimum) {
        return UpdateStatus.updateRequired(info);
      }

      // Check if update is available (below latest)
      if (current < latest) {
        return UpdateStatus.updateAvailable(info);
      }

      // Current version is up to date
      return const UpdateStatus.upToDate();
    } catch (e, st) {
      _log.log(
        LogLevel.debug,
        'Version comparison error',
        error: e,
        stackTrace: st,
      );
      return UpdateStatus.unknown(UnknownFailure(e, st));
    }
  }
}
