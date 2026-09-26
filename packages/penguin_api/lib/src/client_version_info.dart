/// Response from `GET /api/v1/client/version` carrying version info and
/// optional update metadata (store URL, release notes, minimum version).
class ClientVersionInfo {
  /// Creates version info from the fields.
  const ClientVersionInfo({
    required this.latestVersion,
    this.minimumVersion,
    this.storeUrl,
    this.releaseNotes,
  });

  /// The latest version available.
  final String latestVersion;

  /// The minimum version required (if any) — older versions may be blocked
  /// from connecting.
  final String? minimumVersion;

  /// URL to the app store (if any) — used for the update prompt.
  final Uri? storeUrl;

  /// User-facing release notes (if any).
  final String? releaseNotes;

  /// Parses a JSON response into [ClientVersionInfo], requiring only
  /// [latestVersion]; optional fields default to null.
  factory ClientVersionInfo.fromJson(Map<String, Object?> json) {
    final latestVersion = json['latestVersion'] as String?;
    if (latestVersion == null) {
      throw FormatException('Missing required field: latestVersion');
    }

    return ClientVersionInfo(
      latestVersion: latestVersion,
      minimumVersion: json['minimumVersion'] as String?,
      storeUrl: json['storeUrl'] is String
          ? Uri.parse(json['storeUrl'] as String)
          : null,
      releaseNotes: json['releaseNotes'] as String?,
    );
  }
}
