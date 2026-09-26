import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';

void main() {
  test(
    'ConsoleLogger emits single-line JSON with level and sanitized attrs',
    () {
      final lines = <String>[];
      final logger = ConsoleLogger(sink: lines.add);

      logger.log(
        LogLevel.info,
        'hello',
        attributes: const {'token': 'abcdef1234', 'user': 'justin'},
      );

      expect(lines, hasLength(1));
      expect(lines.single.contains('\n'), isFalse);

      final decoded = jsonDecode(lines.single) as Map<String, Object?>;
      expect(decoded['level'], 'info');
      expect(decoded['message'], 'hello');

      final attrs = decoded['attributes']! as Map<String, Object?>;
      expect(attrs['token'], '****1234');
      expect(attrs['user'], 'justin');
    },
  );

  test('ConsoleLogger suppresses records below minLevel', () {
    final lines = <String>[];
    final logger = ConsoleLogger(sink: lines.add, minLevel: LogLevel.warn);

    logger.debug('quiet');
    logger.info('also quiet');
    logger.warn('loud');

    expect(lines, hasLength(1));
    final decoded = jsonDecode(lines.single) as Map<String, Object?>;
    expect(decoded['level'], 'warn');
  });

  test('ConsoleLogger.error includes error and stack trace', () {
    final lines = <String>[];
    final logger = ConsoleLogger(sink: lines.add);
    final stack = StackTrace.current;

    logger.error('boom', error: Exception('bad'), stackTrace: stack);

    final decoded = jsonDecode(lines.single) as Map<String, Object?>;
    expect(decoded['level'], 'error');
    expect(decoded['error'], contains('bad'));
    expect(decoded['stackTrace'], isNotNull);
  });

  test('ConsoleLogger sanitizes error text with embedded tokens', () {
    final lines = <String>[];
    final logger = ConsoleLogger(sink: lines.add);

    logger.log(
      LogLevel.error,
      'Request failed',
      error: Exception('Bearer abc123xyz failed'),
    );

    final decoded = jsonDecode(lines.single) as Map<String, Object?>;
    final errorText = decoded['error'] as String;
    expect(errorText, contains('Bearer ****'));
    expect(errorText, isNot(contains('abc123')));
  });

  test('ConsoleLogger sanitizes message with Bearer tokens', () {
    final lines = <String>[];
    final logger = ConsoleLogger(sink: lines.add);

    logger.log(
      LogLevel.error,
      'Auth error: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJydXN0In0.test',
    );

    final decoded = jsonDecode(lines.single) as Map<String, Object?>;
    expect(decoded['message'], contains('Bearer ****'));
    expect(decoded['message'], isNot(contains('eyJhbGc')));
  });

  test(
    'ConsoleLogger without an explicit sink writes to the developer log',
    () {
      final logger = ConsoleLogger();
      // No assertion beyond "does not throw": the default sink forwards to
      // dart:developer's log channel, which isn't capturable from a test.
      expect(() => logger.info('via default sink'), returnsNormally);
    },
  );

  test('loggerProvider defaults to a ConsoleLogger', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(loggerProvider), isA<ConsoleLogger>());
  });
}
