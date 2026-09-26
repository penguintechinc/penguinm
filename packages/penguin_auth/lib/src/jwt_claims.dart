import 'dart:convert';
import 'package:penguin_core/penguin_core.dart';

/// Standard JWT claims decoded from an access or refresh token.
/// Signature verification is NOT performed on the client (server validates);
/// claims are read for UX (expiry, scope checks) only.
class JwtClaims {
  /// Decodes a JWT payload using base64url (no signature check).
  /// Handles missing padding and parses claims as standard JSON.
  factory JwtClaims.decode(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) throw FormatException('JWT must have 3 parts');

      // Decode payload (add padding if needed for base64url).
      var payload = parts[1];
      final padLength = 4 - (payload.length % 4);
      if (padLength != 4) {
        payload = payload + ('=' * padLength);
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      return JwtClaims._(json);
    } catch (e) {
      throw FormatException('Failed to decode JWT: $e');
    }
  }

  /// Creates a JWT claims object from a decoded JSON map.
  factory JwtClaims.fromJson(Map<String, dynamic> json) => JwtClaims._(json);

  /// Private constructor for internal creation.
  JwtClaims._(Map<String, dynamic> json)
    : sub = json['sub'] as String?,
      iss = json['iss'] as String?,
      tenant = json['tenant'] as String?,
      aud = _parseStringOrList(json['aud']),
      scope = _parseScopeString(json['scope']),
      teams = _parseStringList(json['teams']),
      roles = _parseStringList(json['roles']),
      exp = _parseTimestamp(json['exp']),
      iat = _parseTimestamp(json['iat']),
      raw = json;

  /// Subject (user ID).
  final String? sub;

  /// Issuer (auth server).
  final String? iss;

  /// Tenant ID.
  final String? tenant;

  /// Audience; either a single string or list of strings.
  final List<String> aud;

  /// OAuth2 scopes; either a space-separated string or list.
  final List<String> scope;

  /// Team IDs.
  final List<String> teams;

  /// Roles.
  final List<String> roles;

  /// Expiration time, or null if not set.
  final DateTime? exp;

  /// Issued-at time, or null if not set.
  final DateTime? iat;

  /// Raw decoded JWT claims map.
  final Map<String, dynamic> raw;

  /// Whether this token has expired as of [clock], with optional [leeway].
  bool isExpired(Clock clock, {Duration leeway = const Duration(seconds: 30)}) {
    if (exp == null) return false;
    final deadline = exp!.add(leeway);
    return clock.now().isAfter(deadline);
  }

  /// Whether this token has the given [scope].
  bool hasScope(String s) => scope.contains(s);

  @override
  String toString() =>
      'JwtClaims(sub: $sub, iss: $iss, tenant: $tenant, '
      'aud: $aud, scope: $scope, teams: $teams, roles: $roles, '
      'exp: $exp, iat: $iat)';
}

/// Parses a JSON value that may be a string or list of strings.
List<String> _parseStringOrList(dynamic value) {
  if (value == null) return [];
  if (value is String) return [value];
  if (value is List) {
    return value.whereType<String>().toList();
  }
  return [];
}

/// Parses a space-separated scope string or list of scopes.
List<String> _parseScopeString(dynamic value) {
  if (value == null) return [];
  if (value is String) {
    return value.split(' ').where((s) => s.isNotEmpty).toList();
  }
  if (value is List) {
    return value.whereType<String>().toList();
  }
  return [];
}

/// Parses a list of strings (or empty if not present or not a list).
List<String> _parseStringList(dynamic value) {
  if (value == null) return [];
  if (value is List) {
    return value.whereType<String>().toList();
  }
  return [];
}

/// Parses a Unix timestamp (seconds since epoch) to DateTime.
DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  }
  return null;
}
