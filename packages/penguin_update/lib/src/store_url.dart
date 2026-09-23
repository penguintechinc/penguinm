import 'package:penguin_api/penguin_api.dart';

/// Returns the store URL for launching an app update from version info.
///
/// If [info.storeUrl] is provided, returns it; otherwise returns the default
/// Android Market URL for the given [applicationId].
Uri storeUrlFor(String applicationId, ClientVersionInfo info) {
  return info.storeUrl ?? Uri.parse('market://details?id=$applicationId');
}
