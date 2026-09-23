/// Closed set of typed failures returned via `Result.err` across every
/// penguinm package, letting callers exhaustively switch on failure kind
/// instead of inspecting untyped exceptions.
sealed class Failure {
  /// Creates a failure carrying a human-readable [message].
  const Failure(this.message);

  /// Human-readable description of what went wrong.
  final String message;
}

/// Network-level failure: connectivity loss, timeout, DNS failure, or any
/// error that never reached the server.
class NetworkFailure extends Failure {
  /// Creates a network failure with [message], optionally wrapping the
  /// originating [cause].
  const NetworkFailure(super.message, {this.cause});

  /// The underlying exception that triggered this failure, if any.
  final Object? cause;
}

/// Authentication/authorization failure, typically from a 401/403 HTTP
/// response.
class AuthFailure extends Failure {
  /// Creates an auth failure with the originating [statusCode] (if known)
  /// and [message].
  const AuthFailure(this.statusCode, super.message);

  /// The HTTP status code that triggered this failure, if known.
  final int? statusCode;
}

/// Input validation failure tied to a single [field].
class ValidationFailure extends Failure {
  /// Creates a validation failure for [field] with [message].
  const ValidationFailure(this.field, super.message);

  /// The name of the field that failed validation.
  final String field;
}

/// Local storage failure: SharedPreferences, secure storage, or sqlite
/// error.
class StorageFailure extends Failure {
  /// Creates a storage failure with [message].
  const StorageFailure(super.message);
}

/// Non-2xx HTTP failure carrying the originating status code: any
/// status outside 200-299 except 401/403 (which map to [AuthFailure]) —
/// so non-auth 4xx codes (e.g. 408, 422, 429) as well as 5xx codes. See
/// `penguin_api`'s `mapFailure` for the exact mapping table.
class ServerFailure extends Failure {
  /// Creates a server failure with [statusCode] and [message].
  const ServerFailure(this.statusCode, super.message);

  /// The HTTP status code the server returned.
  final int statusCode;
}

/// Catch-all for unexpected errors, preserving the original error and stack
/// trace for logging/telemetry.
class UnknownFailure extends Failure {
  /// Creates an unknown failure from [cause] and its [stackTrace].
  UnknownFailure(this.cause, this.stackTrace) : super(cause.toString());

  /// The original error object.
  final Object cause;

  /// The stack trace captured at the point of failure.
  final StackTrace stackTrace;
}
