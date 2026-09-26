import 'dart:convert';
import 'dart:developer' as developer;

import 'clock.dart';
import 'log_sanitizer.dart';
import 'logger.dart';

/// [PenguinLogger] that writes sanitized, single-line JSON records via
/// `dart:developer`'s log channel — the default logger below `prod`,
/// before a telemetry-backed logger takes over (see `penguin_telemetry`).
class ConsoleLogger implements PenguinLogger {
  /// Creates a console logger. [clock] and [minLevel] are overridable for
  /// tests; [sink] lets tests capture emitted lines instead of writing to
  /// the developer log.
  ConsoleLogger({
    this.clock = const SystemClock(),
    this.minLevel = LogLevel.debug,
    void Function(String line)? sink,
  }) : _sink = sink ?? _developerLogSink;

  /// Source of the `timestamp` field on every emitted record.
  final Clock clock;

  final void Function(String line) _sink;

  /// Records below this level are dropped without being sanitized or
  /// written to the sink.
  final LogLevel minLevel;

  static void _developerLogSink(String line) {
    developer.log(line, name: 'penguin');
  }

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;
    final record = <String, Object?>{
      'timestamp': clock.now().toIso8601String(),
      'level': level.name,
      'message': LogSanitizer.scrubText(message),
      'attributes': LogSanitizer.sanitize(attributes),
      if (error != null) 'error': LogSanitizer.scrubText(error.toString()),
      if (stackTrace != null)
        'stackTrace': LogSanitizer.scrubText(stackTrace.toString()),
    };
    _sink(jsonEncode(record));
  }

  @override
  void debug(String message, {Map<String, Object?> attributes = const {}}) =>
      log(LogLevel.debug, message, attributes: attributes);

  @override
  void info(String message, {Map<String, Object?> attributes = const {}}) =>
      log(LogLevel.info, message, attributes: attributes);

  @override
  void warn(String message, {Map<String, Object?> attributes = const {}}) =>
      log(LogLevel.warn, message, attributes: attributes);

  @override
  void error(
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    LogLevel.error,
    message,
    attributes: attributes,
    error: error,
    stackTrace: stackTrace,
  );
}
