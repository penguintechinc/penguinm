import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_api/src/middleware/sanitized_log_client.dart';
import 'support/scripted_client.dart';

void main() {
  group('SanitizedLogClient', () {
    test('logs at DEBUG level by default', () async {
      final fakeLogger = _FakeLogger();
      final builder = ScriptedClientBuilder();
      builder.respond(method: 'GET', pathPattern: '/api', statusCode: 200);

      final inner = builder.build();
      final client = SanitizedLogClient(inner: inner, log: fakeLogger);

      await client.get(Uri.parse('http://example.com/api'));

      expect(
        fakeLogger.debugLogs,
        isNotEmpty,
        reason: 'Should log at DEBUG level',
      );
    });

    test('includes method and path in log', () async {
      final fakeLogger = _FakeLogger();
      final builder = ScriptedClientBuilder();
      builder.respond(
        method: 'POST',
        pathPattern: '/api/users',
        statusCode: 201,
      );

      final inner = builder.build();
      final client = SanitizedLogClient(inner: inner, log: fakeLogger);

      await client.post(Uri.parse('http://example.com/api/users'), body: '{}');

      final logs = fakeLogger.debugLogs.join(' ');
      expect(logs, contains('POST'));
      expect(logs, contains('/api/users'));
    });

    test('includes status code in log', () async {
      final fakeLogger = _FakeLogger();
      final builder = ScriptedClientBuilder();
      builder.respond(method: 'GET', pathPattern: '/api', statusCode: 404);

      final inner = builder.build();
      final client = SanitizedLogClient(inner: inner, log: fakeLogger);

      await client.get(Uri.parse('http://example.com/api'));

      final logs = fakeLogger.debugLogs.join(' ');
      expect(logs, contains('404'));
    });

    test('does not log body by default', () async {
      final fakeLogger = _FakeLogger();
      final builder = ScriptedClientBuilder();
      builder.respondWhen(
        predicate: (req) => req.method == 'POST',
        statusCode: 200,
        body: '{"secret":"password123"}',
      );

      final inner = builder.build();
      final client = SanitizedLogClient(inner: inner, log: fakeLogger);

      await client.post(
        Uri.parse('http://example.com/api'),
        body: '{"secret":"password123"}',
      );

      final logs = fakeLogger.debugLogs.join(' ');
      expect(logs, isNot(contains('password123')));
    });

    test('logs body when logBodies is true', () async {
      final fakeLogger = _FakeLogger();
      final builder = ScriptedClientBuilder();
      builder.respondWhen(
        predicate: (req) => req.method == 'POST',
        statusCode: 200,
        body: '{"key":"value"}',
      );

      final inner = builder.build();
      final client = SanitizedLogClient(
        inner: inner,
        log: fakeLogger,
        logBodies: true,
      );

      await client.post(
        Uri.parse('http://example.com/api'),
        body: '{"key":"value"}',
      );

      final logs = fakeLogger.debugLogs.join(' ');
      expect(logs, contains('value'));
    });

    test('sanitizes sensitive fields in logs', () async {
      final fakeLogger = _FakeLogger();
      final builder = ScriptedClientBuilder();
      builder.respondWhen(
        predicate: (req) => req.method == 'POST',
        statusCode: 200,
      );

      final inner = builder.build();
      final client = SanitizedLogClient(
        inner: inner,
        log: fakeLogger,
        logBodies: true,
      );

      await client.post(
        Uri.parse('http://example.com/api'),
        body: '{"token":"secret1234","password":"pass5678"}',
      );

      final logs = fakeLogger.debugLogs.join(' ');
      expect(logs, isNot(contains('secret1234')));
      expect(logs, isNot(contains('pass5678')));
    });

    test(
      'scrubs non-JSON text bodies (key=value form) when logBodies is true',
      () async {
        final fakeLogger = _FakeLogger();
        final builder = ScriptedClientBuilder();
        builder.respondWhen(
          predicate: (req) => req.method == 'POST',
          statusCode: 200,
        );

        final inner = builder.build();
        final client = SanitizedLogClient(
          inner: inner,
          log: fakeLogger,
          logBodies: true,
        );

        await client.post(
          Uri.parse('http://example.com/api'),
          body: 'token=abc123',
        );

        final logs = fakeLogger.debugLogs.join(' ');
        expect(logs, isNot(contains('abc123')));
      },
    );

    test(
      'scrubs valid JSON that is not an object (e.g. an array) as text',
      () async {
        final fakeLogger = _FakeLogger();
        final builder = ScriptedClientBuilder();
        builder.respondWhen(
          predicate: (req) => req.method == 'POST',
          statusCode: 200,
        );

        final inner = builder.build();
        final client = SanitizedLogClient(
          inner: inner,
          log: fakeLogger,
          logBodies: true,
        );

        await client.post(Uri.parse('http://example.com/api'), body: '[1,2,3]');

        expect(fakeLogger.debugLogs, isNotEmpty);
      },
    );

    test(
      'sanitizes sensitive fields in the logged attribute map, not just the message string',
      () async {
        final fakeLogger = _FakeLogger();
        final builder = ScriptedClientBuilder();
        builder.respondWhen(
          predicate: (req) => req.method == 'POST',
          statusCode: 200,
        );

        final inner = builder.build();
        final client = SanitizedLogClient(
          inner: inner,
          log: fakeLogger,
          logBodies: true,
        );

        await client.post(
          Uri.parse('http://example.com/api'),
          body: '{"token":"secret1234","password":"pass5678","name":"widget"}',
        );

        expect(fakeLogger.debugAttributes, isNotEmpty);
        for (final attrs in fakeLogger.debugAttributes) {
          final serialized = attrs.toString();
          expect(serialized, isNot(contains('secret1234')));
          expect(serialized, isNot(contains('pass5678')));
        }
        // Non-sensitive fields still pass through untouched.
        final withBody = fakeLogger.debugAttributes.firstWhere(
          (attrs) => attrs.containsKey('body'),
        );
        final body = withBody['body'];
        expect(body, isA<Map<String, Object?>>());
        expect((body as Map<String, Object?>)['name'], equals('widget'));
      },
    );
  });
}

class _FakeLogger implements PenguinLogger {
  final debugLogs = <String>[];
  final debugAttributes = <Map<String, Object?>>[];
  final infoLogs = <String>[];
  final warnLogs = <String>[];
  final errorLogs = <String>[];

  @override
  void debug(String message, {Map<String, Object?> attributes = const {}}) {
    debugLogs.add(message);
    debugAttributes.add(attributes);
  }

  @override
  void error(
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    errorLogs.add(message);
  }

  @override
  void info(String message, {Map<String, Object?> attributes = const {}}) {
    infoLogs.add(message);
  }

  @override
  void log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    switch (level) {
      case LogLevel.debug:
        debug(message, attributes: attributes);
      case LogLevel.info:
        info(message, attributes: attributes);
      case LogLevel.warn:
        warn(message, attributes: attributes);
      case LogLevel.error:
        this.error(
          message,
          attributes: attributes,
          error: error,
          stackTrace: stackTrace,
        );
    }
  }

  @override
  void warn(String message, {Map<String, Object?> attributes = const {}}) {
    warnLogs.add(message);
  }
}
