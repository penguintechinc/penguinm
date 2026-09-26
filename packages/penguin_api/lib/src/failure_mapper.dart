import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:penguin_core/penguin_core.dart';

/// Maps HTTP and network errors to typed [Failure] objects for consistent
/// error handling. Status-code mapping (only when [response] is given):
///
/// | Status                                   | Failure                       |
/// |-------------------------------------------|-------------------------------|
/// | 401, 403                                   | [AuthFailure] (statusCode)    |
/// | any other non-2xx (400–499 except 401/403, and 5xx) | [ServerFailure] (statusCode) |
///
/// Every non-2xx status keeps its exact code in the returned [Failure] —
/// including 4xx codes that aren't 401/403 — so callers can tell apart, say,
/// a retryable `408`/`429` from a terminal `422` (`penguin_offline`'s
/// `SyncQueue` depends on this to decide retry vs. dead-letter). Without a
/// [response] (pure exceptions): [http.ClientException] / [TimeoutException]
/// / [SocketException] → [NetworkFailure]; anything else → [UnknownFailure].
Failure mapFailure(
  Object error, {
  http.BaseResponse? response,
  StackTrace? stackTrace,
}) {
  stackTrace ??= StackTrace.current;

  // HTTP status code failures — the exact status is always preserved, even
  // for non-auth 4xx codes, so callers can distinguish retryable from
  // terminal failures without re-deriving the status themselves.
  if (response != null) {
    final statusCode = response.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      return AuthFailure(
        statusCode,
        'HTTP $statusCode: ${_reasonPhrase(statusCode)}',
      );
    }
    if (statusCode < 200 || statusCode >= 300) {
      return ServerFailure(
        statusCode,
        'HTTP $statusCode: ${_reasonPhrase(statusCode)}',
      );
    }
  }

  // Network-level exceptions
  if (error is http.ClientException) {
    return NetworkFailure(error.message, cause: error);
  }
  if (error is TimeoutException) {
    return NetworkFailure('Request timeout', cause: error);
  }
  if (error is SocketException) {
    return NetworkFailure(error.message, cause: error);
  }

  // Unknown error
  return UnknownFailure(error, stackTrace);
}

/// Returns the HTTP reason phrase for a status code.
String _reasonPhrase(int statusCode) {
  return switch (statusCode) {
    400 => 'Bad Request',
    401 => 'Unauthorized',
    403 => 'Forbidden',
    404 => 'Not Found',
    408 => 'Request Timeout',
    409 => 'Conflict',
    429 => 'Too Many Requests',
    500 => 'Internal Server Error',
    502 => 'Bad Gateway',
    503 => 'Service Unavailable',
    504 => 'Gateway Timeout',
    _ => 'Error',
  };
}
