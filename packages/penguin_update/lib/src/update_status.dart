import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';

/// The result of an update check against the version API.
///
/// Sealed class with four variants: up to date, update available, update
/// required (below minimum), or unknown (check failed).
sealed class UpdateStatus {
  /// No update available; the current version is up to date.
  const factory UpdateStatus.upToDate() = UpToDate;

  /// An update is available; the current version is >= minimum (if specified).
  const factory UpdateStatus.updateAvailable(ClientVersionInfo info) =
      UpdateAvailable;

  /// An update is required; the current version is < minimum.
  const factory UpdateStatus.updateRequired(ClientVersionInfo info) =
      UpdateRequired;

  /// The check failed and no status is available.
  const factory UpdateStatus.unknown(Failure failure) = Unknown;
}

/// The app is up to date.
class UpToDate implements UpdateStatus {
  /// Creates an up-to-date status.
  const UpToDate();

  @override
  bool operator ==(Object other) => other is UpToDate;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// An update is available.
class UpdateAvailable implements UpdateStatus {
  /// Creates an update-available status with version info.
  const UpdateAvailable(this.info);

  /// Version information including latest, store URL, and release notes.
  final ClientVersionInfo info;

  @override
  bool operator ==(Object other) =>
      other is UpdateAvailable && other.info == info;

  @override
  int get hashCode => Object.hash(runtimeType, info);
}

/// An update is required (current version is below minimum).
class UpdateRequired implements UpdateStatus {
  /// Creates an update-required status with version info.
  const UpdateRequired(this.info);

  /// Version information including minimum version and store URL.
  final ClientVersionInfo info;

  @override
  bool operator ==(Object other) =>
      other is UpdateRequired && other.info == info;

  @override
  int get hashCode => Object.hash(runtimeType, info);
}

/// The update check failed.
class Unknown implements UpdateStatus {
  /// Creates an unknown status with the failure that occurred.
  const Unknown(this.failure);

  /// The failure that prevented the check from completing.
  final Failure failure;

  @override
  bool operator ==(Object other) =>
      other is Unknown && other.failure == failure;

  @override
  int get hashCode => Object.hash(runtimeType, failure);
}
