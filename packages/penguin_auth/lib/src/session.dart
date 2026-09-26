import 'package:penguin_core/penguin_core.dart';

import 'jwt_claims.dart';

/// An authenticated session with access token, optional refresh token, and
/// decoded claims. Sessions are persisted in flutter_secure_storage.
class Session {
  /// Creates a session.
  const Session({
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
    required this.claims,
  });

  /// The access token (typically JWT).
  final String accessToken;

  /// The refresh token, or null if not supported by the backend.
  final String? refreshToken;

  /// Expiration time of the access token.
  final DateTime expiresAt;

  /// Decoded JWT claims from the access token.
  final JwtClaims claims;

  /// Whether the access token has passed [expiresAt] as of [clock] — the
  /// basis for the controller's startup decision between using a stored
  /// session as-is and attempting a refresh first.
  bool isExpired(Clock clock) => !clock.now().isBefore(expiresAt);

  /// Serializes to JSON for secure storage.
  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
    'claims': claims.raw,
  };

  /// Deserializes from JSON stored in secure storage.
  factory Session.fromJson(Map<String, dynamic> json) {
    final claims = JwtClaims.fromJson(json['claims'] as Map<String, dynamic>);
    return Session(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      claims: claims,
    );
  }

  @override
  String toString() =>
      'Session(accessToken: ${LogSanitizer.maskValue(accessToken)}, '
      'refreshToken: ${refreshToken == null ? null : LogSanitizer.maskValue(refreshToken!)}, '
      'expiresAt: $expiresAt)';
}
