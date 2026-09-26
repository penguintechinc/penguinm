import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:penguin_core/penguin_core.dart';

/// Middleware that logs HTTP requests and responses at DEBUG level: method,
/// path, status code, and duration. Request bodies are never logged unless
/// [logBodies] is true, and even then only sanitized — JSON bodies through
/// [LogSanitizer.sanitize] on the decoded map, non-JSON bodies through
/// [LogSanitizer.scrubText]. Query-string values are never logged.
class SanitizedLogClient extends http.BaseClient {
  /// Creates a logging middleware wrapping [inner].
  SanitizedLogClient({
    required this._inner,
    PenguinLogger? log,
    this.logBodies = false,
  }) : _log = log ?? _NoopLogger();

  final http.Client _inner;
  final PenguinLogger _log;

  /// Whether to log request bodies (sanitized) at DEBUG level.
  final bool logBodies;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final stopwatch = Stopwatch()..start();

    _log.debug(
      _requestMessage(request),
      attributes: _requestAttributes(request),
    );

    http.StreamedResponse? response;
    try {
      response = await _inner.send(request);
      return response;
    } finally {
      stopwatch.stop();

      // `response` stays null when `_inner.send` threw above — only log
      // the completion line when a response actually came back, and never
      // read it unconditionally (that would mask the original error).
      final currentResponse = response;
      if (currentResponse != null) {
        _log.debug(
          '${_requestMessage(request)} -> ${currentResponse.statusCode} '
          '(${stopwatch.elapsedMilliseconds}ms)',
          attributes: LogSanitizer.sanitize({
            'http.request.method': request.method,
            'http.response.status_code': currentResponse.statusCode,
            'duration_ms': stopwatch.elapsedMilliseconds,
          }),
        );
      }
    }
  }

  /// Builds the request log message: method + path (never the query
  /// string), plus the sanitized body when [logBodies] is enabled.
  String _requestMessage(http.BaseRequest request) {
    var message = 'HTTP ${request.method} ${request.url.path}';
    if (logBodies && request is http.Request && request.body.isNotEmpty) {
      message += ' ${_sanitizedBody(request.body)}';
    }
    return message;
  }

  /// Builds debug-level log attributes for a request: method and path
  /// always; the sanitized body only when [logBodies] is enabled.
  Map<String, Object?> _requestAttributes(http.BaseRequest request) {
    final attrs = <String, Object?>{
      'method': request.method,
      'path': request.url.path,
    };

    if (logBodies && request is http.Request && request.body.isNotEmpty) {
      attrs['body'] = _sanitizedBody(request.body);
    }

    return LogSanitizer.sanitize(attrs);
  }

  /// Sanitizes a request body for logging. A JSON object body is decoded
  /// and passed through [LogSanitizer.sanitize] so sensitive keys are
  /// masked structurally; anything else (non-JSON text, or JSON that isn't
  /// an object — an array, string, number, bool, or null) is scrubbed as
  /// free text via [LogSanitizer.scrubText].
  Object _sanitizedBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        return LogSanitizer.sanitize(decoded);
      }
      return LogSanitizer.scrubText(body);
    } on FormatException {
      return LogSanitizer.scrubText(body);
    }
  }
}

/// Fallback logger used only when no [PenguinLogger] is injected — every
/// call is a silent no-op so logging never crashes an un-instrumented app.
class _NoopLogger implements PenguinLogger {
  @override
  void debug(String message, {Map<String, Object?> attributes = const {}}) {}

  @override
  void error(
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {}

  @override
  void info(String message, {Map<String, Object?> attributes = const {}}) {}

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {}

  @override
  void warn(String message, {Map<String, Object?> attributes = const {}}) {}
}
