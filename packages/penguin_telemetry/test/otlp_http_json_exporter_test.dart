import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_telemetry/src/otlp_http_json_exporter.dart';
import 'package:penguin_telemetry/src/otlp_json.dart';

void main() {
  final endpoint = Uri.parse('http://127.0.0.1:4318');

  test(
    'exportLogs POSTs OTLP JSON to /v1/logs with configured headers',
    () async {
      late Uri capturedUri;
      late Map<String, String> capturedHeaders;
      late Map<String, Object?> capturedBody;

      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedHeaders = request.headers;
        capturedBody = jsonDecode(request.body) as Map<String, Object?>;
        return http.Response('{}', 200);
      });

      final exporter = OtlpHttpJsonExporter(
        endpoint: endpoint,
        serviceName: 'gazer',
        serviceVersion: '1.0.0',
        headers: const <String, String>{'Authorization': 'Bearer tok'},
        client: client,
      );

      final result = await exporter.exportLogs(<LogRecordData>[
        LogRecordData(
          timestamp: DateTime.utc(2026),
          level: LogLevel.info,
          message: 'hi',
        ),
      ]);

      expect(result.ok, isTrue);
      expect(result.accepted, 1);
      expect(capturedUri.toString(), 'http://127.0.0.1:4318/v1/logs');
      expect(capturedHeaders['Authorization'], 'Bearer tok');
      expect(capturedHeaders['Content-Type'], contains('application/json'));
      expect(capturedBody.containsKey('resourceLogs'), isTrue);
    },
  );

  test('exportMetrics POSTs to /v1/metrics', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/metrics');
      return http.Response('{}', 202);
    });
    final exporter = OtlpHttpJsonExporter(
      endpoint: endpoint,
      serviceName: 's',
      serviceVersion: '1',
      client: client,
    );

    final result = await exporter.exportMetrics(<MetricData>[
      MetricData.sum(name: 'c', dataPoints: const <MetricDataPoint>[]),
    ]);

    expect(result.ok, isTrue);
    expect(result.accepted, 1);
  });

  test('exportSpans POSTs to /v1/traces', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/traces');
      return http.Response('{}', 200);
    });
    final exporter = OtlpHttpJsonExporter(
      endpoint: endpoint,
      serviceName: 's',
      serviceVersion: '1',
      client: client,
    );

    final result = await exporter.exportSpans(<SpanData>[]);

    expect(result.ok, isTrue);
    expect(result.accepted, 0);
  });

  test('non-2xx status returns a failure result without throwing', () async {
    final client = MockClient(
      (request) async => http.Response('server error', 500),
    );
    final exporter = OtlpHttpJsonExporter(
      endpoint: endpoint,
      serviceName: 's',
      serviceVersion: '1',
      client: client,
    );

    final result = await exporter.exportLogs(<LogRecordData>[
      LogRecordData(
        timestamp: DateTime.utc(2026),
        level: LogLevel.error,
        message: 'x',
      ),
    ]);

    expect(result.ok, isFalse);
    expect(result.accepted, 0);
    expect(result.error, contains('500'));
  });

  test('a throwing client returns a failure result without throwing', () async {
    final client = MockClient(
      (request) async => throw const SocketException('boom'),
    );
    final exporter = OtlpHttpJsonExporter(
      endpoint: endpoint,
      serviceName: 's',
      serviceVersion: '1',
      client: client,
    );

    final result = await exporter.exportLogs(<LogRecordData>[
      LogRecordData(
        timestamp: DateTime.utc(2026),
        level: LogLevel.error,
        message: 'x',
      ),
    ]);

    expect(result.ok, isFalse);
    expect(result.error, isNotNull);
  });

  test(
    'a timing-out client returns a failure result without throwing',
    () async {
      final client = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('{}', 200);
      });
      final exporter = OtlpHttpJsonExporter(
        endpoint: endpoint,
        serviceName: 's',
        serviceVersion: '1',
        client: client,
        timeout: const Duration(milliseconds: 5),
      );

      final result = await exporter.exportLogs(<LogRecordData>[
        LogRecordData(
          timestamp: DateTime.utc(2026),
          level: LogLevel.error,
          message: 'x',
        ),
      ]);

      expect(result.ok, isFalse);
    },
  );

  test(
    'constructing without an injected client defaults to a real http.Client',
    () {
      final exporter = OtlpHttpJsonExporter(
        endpoint: endpoint,
        serviceName: 's',
        serviceVersion: '1',
      );

      expect(exporter, isA<OtlpHttpJsonExporter>());
    },
  );

  test(
    'an endpoint with a trailing slash does not produce a double slash',
    () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'http://127.0.0.1:4318/v1/logs');
        return http.Response('{}', 200);
      });
      final exporter = OtlpHttpJsonExporter(
        endpoint: Uri.parse('http://127.0.0.1:4318/'),
        serviceName: 's',
        serviceVersion: '1',
        client: client,
      );

      await exporter.exportLogs(<LogRecordData>[]);
    },
  );
}
