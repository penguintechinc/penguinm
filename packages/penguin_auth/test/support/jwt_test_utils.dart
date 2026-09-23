import 'dart:convert';

/// Builds a syntactically-valid (unsigned) JWT string from [claims] for
/// tests — `JwtClaims.decode` only reads the base64url payload, so the
/// header and signature segments are fixed placeholders.
String buildTestJwt(Map<String, Object?> claims) {
  const header = 'eyJhbGciOiJIUzI1NiJ9'; // {"alg":"HS256"}
  final payload = base64Url.encode(utf8.encode(jsonEncode(claims)));
  const signature = 'test-signature';
  return '$header.$payload.$signature';
}
