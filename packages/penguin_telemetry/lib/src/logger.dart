import 'package:penguin_core/penguin_core.dart';

import 'otlp_json.dart';
import 'queue.dart';

/// [PenguinLogger] backing a running `Telemetry` instance: sanitizes every
/// attribute map, buffers records onto a bounded queue for OTLP export, and
/// optionally mirrors every record to a console logger for local debugging.
class TelemetryLogger implements PenguinLogger {
  /// Creates a telemetry-backed logger. Records below [minLevel] are
  /// dropped before sanitization or enqueueing; when [consoleMirror] is
  /// true every emitted record is also sent to [mirror] (a [ConsoleLogger]
  /// by default).
  TelemetryLogger({
    required this._clock,
    required this._queue,
    this.minLevel = LogLevel.info,
    this.consoleMirror = false,
    PenguinLogger? mirror,
  }) : _mirror = mirror ?? ConsoleLogger(clock: _clock, minLevel: minLevel);

  /// Records below this level are dropped.
  final LogLevel minLevel;

  /// Whether every record is also written to the console mirror.
  final bool consoleMirror;

  final Clock _clock;
  final BoundedQueue<LogRecordData> _queue;
  final PenguinLogger _mirror;

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;
    final sanitized = <String, Object?>{
      ...LogSanitizer.sanitize(attributes),
      if (error != null) 'exception.type': error.runtimeType.toString(),
      if (error != null) 'exception.message': error.toString(),
      if (stackTrace != null) 'exception.stacktrace': stackTrace.toString(),
    };
    _queue.add(
      LogRecordData(
        timestamp: _clock.now(),
        level: level,
        message: message,
        attributes: sanitized,
      ),
    );
    if (consoleMirror) {
      _mirror.log(
        level,
        message,
        attributes: sanitized,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void debug(
    String message, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) => log(LogLevel.debug, message, attributes: attributes);

  @override
  void info(
    String message, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) => log(LogLevel.info, message, attributes: attributes);

  @override
  void warn(
    String message, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) => log(LogLevel.warn, message, attributes: attributes);

  @override
  void error(
    String message, {
    Map<String, Object?> attributes = const <String, Object?>{},
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
