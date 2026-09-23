/// Redacts sensitive values (tokens, secrets, passwords, etc.) from
/// attribute maps before they reach logs or telemetry, recursing into
/// nested maps and lists so no secret can hide inside structured data.
class LogSanitizer {
  /// Case-insensitive regular expression pattern matching key names
  /// considered sensitive (tokens, secrets, passwords, cookies, ...).
  static const sensitiveKeyPattern =
      r'(token|secret|password|passwd|authorization|api[_-]?key|mfa|otp|cookie|session|private[_-]?key)';

  static final RegExp _keyPattern = RegExp(
    sensitiveKeyPattern,
    caseSensitive: false,
  );

  static final RegExp _bearerPattern = RegExp(
    r'Bearer\s+([A-Za-z0-9._\-]+)',
    caseSensitive: false,
  );

  static final RegExp _jwtPattern = RegExp(
    r'[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+',
  );

  /// Returns a copy of [attrs] with sensitive values masked via
  /// [maskValue] and nested maps/lists sanitized recursively;
  /// non-sensitive values pass through unchanged.
  static Map<String, Object?> sanitize(Map<String, Object?> attrs) {
    return attrs.map((key, value) => MapEntry(key, _sanitizeEntry(key, value)));
  }

  static Object? _sanitizeEntry(String key, Object? value) {
    if (_keyPattern.hasMatch(key)) {
      return value == null ? null : maskValue(value.toString());
    }
    return _sanitizeValue(value);
  }

  static Object? _sanitizeValue(Object? value) {
    if (value is Map<String, Object?>) {
      return sanitize(value);
    }
    if (value is Map<Object?, Object?>) {
      return sanitize(value.map((k, v) => MapEntry(k.toString(), v)));
    }
    if (value is List<Object?>) {
      return value.map(_sanitizeValue).toList();
    }
    if (value is Set<Object?>) {
      return value.map(_sanitizeValue).toSet();
    }
    if (value is Iterable<Object?>) {
      return value.map(_sanitizeValue).toList();
    }
    return value;
  }

  /// Masks a sensitive string value, keeping only the last 4 characters
  /// visible (`abcdef1234` → `****1234`); values of 4 characters or fewer
  /// become `****` since there is nothing safe left to reveal.
  static String maskValue(String v) {
    if (v.length <= 4) return '****';
    return '****${v.substring(v.length - 4)}';
  }

  /// Redacts sensitive patterns embedded in free text: `key=value` and
  /// `key: value` pairs matching [sensitiveKeyPattern], JSON `"key":"value"`
  /// pairs, `Bearer <token>` headers, and JWT-shaped strings (three base64url
  /// segments separated by dots). Harmless text is unchanged.
  static String scrubText(String text) {
    if (text.isEmpty) return text;

    var result = text;

    // Mask JSON "key":"value" patterns first to avoid interfering with others
    result = result.replaceAllMapped(
      RegExp(
        r'"(' + sensitiveKeyPattern + r')":\s*"([^"]*)"',
        caseSensitive: false,
      ),
      (match) => '"${match.group(1)}":"${maskValue(match.group(2)!)}"',
    );

    // Mask key=value patterns (e.g., token=abc123)
    result = result.replaceAllMapped(
      RegExp(
        r'(' + sensitiveKeyPattern + r')=([^\s,}\]"]+)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}=${maskValue(match.group(2)!)}',
    );

    // Mask key: value patterns (e.g., password: hunter2)
    result = result.replaceAllMapped(
      RegExp(
        r'(' + sensitiveKeyPattern + r'):\s*([^\s,}\]"]+)',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}: ${maskValue(match.group(2)!)}',
    );

    // Mask Bearer tokens
    result = result.replaceAllMapped(_bearerPattern, (match) {
      return 'Bearer ${maskValue(match.group(1)!)}';
    });

    // Mask JWT-shaped strings
    result = result.replaceAllMapped(_jwtPattern, (match) {
      final jwt = match.group(0)!;
      final parts = jwt.split('.');
      if (parts.length == 3) {
        return '${maskValue(parts[0])}.${maskValue(parts[1])}.${maskValue(parts[2])}';
      }
      return jwt;
    });

    return result;
  }
}
