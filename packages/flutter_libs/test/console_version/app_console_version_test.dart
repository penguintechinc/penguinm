import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Pumps [widget] with [client] injected as the ambient `package:http`
/// client (via `http.runWithClient`), then flushes the microtasks and
/// timers the widget's fire-and-forget fetch needs to complete.
Future<void> _pumpWithClient(
  WidgetTester tester,
  Widget widget,
  http.Client client,
) {
  return http.runWithClient(() async {
    await tester.pumpWidget(widget);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }, () => client);
}

void main() {
  group('AppConsoleVersion 200 responses', () {
    testWidgets('logs the fetched version and build epoch', (tester) async {
      http.Request? seenRequest;
      final client = MockClient((request) async {
        seenRequest = request;
        return http.Response(
          jsonEncode({'version': '2.5.1', 'buildEpoch': 1700000000}),
          200,
        );
      });

      await _pumpWithClient(
        tester,
        MaterialApp(
          home: AppConsoleVersion(
            appName: 'Elder',
            versionUrl: 'https://example.penguintech.cloud/version',
            environment: 'beta',
          ),
        ),
        client,
      );

      expect(seenRequest, isNotNull);
      expect(
        seenRequest!.url,
        Uri.parse('https://example.penguintech.cloud/version'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('falls back to defaults when fields are missing', (
      tester,
    ) async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response(jsonEncode(<String, dynamic>{}), 200);
      });

      await _pumpWithClient(
        tester,
        MaterialApp(
          home: AppConsoleVersion(
            appName: 'Elder',
            versionUrl: 'https://example.penguintech.cloud/version',
          ),
        ),
        client,
      );

      expect(called, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('forwards custom headers to the request', (tester) async {
      http.Request? seenRequest;
      final client = MockClient((request) async {
        seenRequest = request;
        return http.Response(jsonEncode({'version': '1.0.0'}), 200);
      });

      await _pumpWithClient(
        tester,
        MaterialApp(
          home: AppConsoleVersion(
            appName: 'Elder',
            versionUrl: 'https://example.penguintech.cloud/version',
            headers: const {'Authorization': 'Bearer test-token'},
          ),
        ),
        client,
      );

      expect(seenRequest, isNotNull);
      expect(seenRequest!.headers['Authorization'], 'Bearer test-token');
    });

    testWidgets('uses empty headers by default', (tester) async {
      http.Request? seenRequest;
      final client = MockClient((request) async {
        seenRequest = request;
        return http.Response(jsonEncode({'version': '1.0.0'}), 200);
      });

      await _pumpWithClient(
        tester,
        MaterialApp(
          home: AppConsoleVersion(
            appName: 'Elder',
            versionUrl: 'https://example.penguintech.cloud/version',
          ),
        ),
        client,
      );

      expect(seenRequest, isNotNull);
      expect(seenRequest!.headers['Authorization'], isNull);
    });

    testWidgets('accepts metadata to merge with the API source tag', (
      tester,
    ) async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'version': '1.0.0'}), 200);
      });

      await _pumpWithClient(
        tester,
        MaterialApp(
          home: AppConsoleVersion(
            appName: 'Elder',
            versionUrl: 'https://example.penguintech.cloud/version',
            metadata: const {'region': 'us-east'},
          ),
        ),
        client,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('AppConsoleVersion non-200 and error responses', () {
    testWidgets('does not throw on a 500 response', (tester) async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('Internal Server Error', 500);
      });

      await _pumpWithClient(
        tester,
        MaterialApp(
          home: AppConsoleVersion(
            appName: 'Elder',
            versionUrl: 'https://example.penguintech.cloud/version',
          ),
        ),
        client,
      );

      expect(called, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('catches a malformed (non-JSON) response body', (tester) async {
      final client = MockClient((request) async {
        return http.Response('not valid json {{{', 200);
      });

      await _pumpWithClient(
        tester,
        MaterialApp(
          home: AppConsoleVersion(
            appName: 'Elder',
            versionUrl: 'https://example.penguintech.cloud/version',
          ),
        ),
        client,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('catches a JSON body that is not an object', (tester) async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode([1, 2, 3]), 200);
      });

      await _pumpWithClient(
        tester,
        MaterialApp(
          home: AppConsoleVersion(
            appName: 'Elder',
            versionUrl: 'https://example.penguintech.cloud/version',
          ),
        ),
        client,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('catches a client-side error such as a timeout', (
      tester,
    ) async {
      final client = MockClient((request) async {
        throw Exception('simulated connection timeout');
      });

      await _pumpWithClient(
        tester,
        MaterialApp(
          home: AppConsoleVersion(
            appName: 'Elder',
            versionUrl: 'https://example.penguintech.cloud/version',
          ),
        ),
        client,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
