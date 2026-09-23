import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_telemetry/src/logger.dart';
import 'package:penguin_telemetry/src/otlp_json.dart';
import 'package:penguin_telemetry/src/queue.dart';

class _RecordingLogger implements PenguinLogger {
  final List<String> messages = <String>[];

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    messages.add(message);
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

void main() {
  test('sanitizes attributes before enqueueing', () {
    final queue = BoundedQueue<LogRecordData>(maxSize: 10);
    final logger = TelemetryLogger(clock: const SystemClock(), queue: queue);

    logger.info(
      'login',
      attributes: const <String, Object?>{'password': 'hunter2xyz'},
    );

    expect(queue.drain().single.attributes['password'], '****2xyz');
  });

  test('records below minLevel are dropped', () {
    final queue = BoundedQueue<LogRecordData>(maxSize: 10);
    final logger = TelemetryLogger(
      clock: const SystemClock(),
      queue: queue,
      minLevel: LogLevel.warn,
    );

    logger.debug('noisy');
    logger.info('also noisy');
    logger.warn('kept');

    final records = queue.drain();
    expect(records, hasLength(1));
    expect(records.single.message, 'kept');
    expect(records.single.level, LogLevel.warn);
  });

  test('log() below minLevel via the generic entrypoint is also dropped', () {
    final queue = BoundedQueue<LogRecordData>(maxSize: 10);
    final logger = TelemetryLogger(clock: const SystemClock(), queue: queue);

    logger.log(LogLevel.debug, 'dropped');

    expect(queue.isEmpty, isTrue);
  });

  test('error() attaches exception attributes', () {
    final queue = BoundedQueue<LogRecordData>(maxSize: 10);
    final logger = TelemetryLogger(clock: const SystemClock(), queue: queue);

    logger.error(
      'failed',
      error: StateError('boom'),
      stackTrace: StackTrace.current,
    );

    final record = queue.drain().single;
    expect(record.attributes['exception.type'], contains('StateError'));
    expect(record.attributes['exception.message'], contains('boom'));
    expect(record.attributes.containsKey('exception.stacktrace'), isTrue);
    expect(record.message, 'failed');
  });

  test('consoleMirror mirrors every emitted record to the given mirror', () {
    final queue = BoundedQueue<LogRecordData>(maxSize: 10);
    final mirror = _RecordingLogger();
    final logger = TelemetryLogger(
      clock: const SystemClock(),
      queue: queue,
      consoleMirror: true,
      mirror: mirror,
    );

    logger.info('hello');

    expect(mirror.messages, <String>['hello']);
  });

  test('consoleMirror false does not mirror', () {
    final queue = BoundedQueue<LogRecordData>(maxSize: 10);
    final mirror = _RecordingLogger();
    final logger = TelemetryLogger(
      clock: const SystemClock(),
      queue: queue,
      mirror: mirror,
    );

    logger.info('hello');

    expect(mirror.messages, isEmpty);
  });

  test('debug()/warn() route through log() at the right level', () {
    final queue = BoundedQueue<LogRecordData>(maxSize: 10);
    final logger = TelemetryLogger(
      clock: const SystemClock(),
      queue: queue,
      minLevel: LogLevel.debug,
    );

    logger
      ..debug('d')
      ..warn('w');

    final records = queue.drain();
    expect(records[0].level, LogLevel.debug);
    expect(records[1].level, LogLevel.warn);
  });
}
