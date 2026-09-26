/// Severity for a single log record, matching the four-level scheme used
/// across penguinm clients (DEBUG through ERROR).
enum LogLevel {
  /// Verbose diagnostic detail — generous by design, enabled below prod.
  debug,

  /// State change / lifecycle — the default runtime level.
  info,

  /// Degraded but still serving.
  warn,

  /// Actionable failure.
  error,
}

/// Cross-cutting structured logging interface every penguinm package logs
/// through; implementations attach sanitization and a destination
/// (console, telemetry) without callers needing to know which.
abstract interface class PenguinLogger {
  /// Emits a log record at [level] with [message] and optional structured
  /// [attributes], [error], and [stackTrace].
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  });

  /// Emits a [LogLevel.debug] record.
  void debug(String message, {Map<String, Object?> attributes = const {}});

  /// Emits a [LogLevel.info] record.
  void info(String message, {Map<String, Object?> attributes = const {}});

  /// Emits a [LogLevel.warn] record.
  void warn(String message, {Map<String, Object?> attributes = const {}});

  /// Emits a [LogLevel.error] record, optionally carrying the originating
  /// [error] and [stackTrace].
  void error(
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  });
}
