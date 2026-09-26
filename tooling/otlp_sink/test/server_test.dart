/// Tests for [OtlpSinkServer] and [Counters] covering every counting rule
/// from the T4 brief: log records, sum/histogram data points, spans, reset,
/// and malformed-JSON rejection. Each server-facing test binds an ephemeral
/// port and drives it with a real `HttpClient` inside `HttpOverrides.runZoned`
/// because `flutter_test` blocks real sockets once the test binding loads.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otlp_sink/otlp_sink.dart';

/// Minimal decoded HTTP response used by the request helper below.
class _Response {
  _Response(this.statusCode, this.body);

  final int statusCode;
  final String body;

  Map<String, dynamic> get json => jsonDecode(body) as Map<String, dynamic>;
}

/// An [HttpOverrides] with no overridden behavior: `createHttpClient` falls
/// through to the base class, which constructs the real socket-backed
/// client directly rather than going back through the `HttpClient()`
/// factory (calling that factory inside a `createHttpClient` callback would
/// re-enter the same zone override and recurse forever).
class _RealHttpOverrides extends HttpOverrides {}

Future<_Response> _request(
  int port,
  String method,
  String path, {
  String? body,
  bool asJson = true,
}) {
  return HttpOverrides.runZoned(
    () async {
      final client = HttpClient();
      try {
        final uri = Uri.parse('http://127.0.0.1:$port$path');
        final request = await client.openUrl(method, uri);
        if (body != null) {
          if (asJson) {
            request.headers.contentType = ContentType.json;
          }
          request.write(body);
        }
        final response = await request.close();
        final text = await utf8.decoder.bind(response).join();
        return _Response(response.statusCode, text);
      } finally {
        client.close(force: true);
      }
    },
    createHttpClient: (context) =>
        _RealHttpOverrides().createHttpClient(context),
  );
}

Map<String, dynamic> _logsPayload(
  int recordsInFirstScope, {
  int extraScopeRecords = 0,
}) {
  return {
    'resourceLogs': [
      {
        'scopeLogs': [
          {
            'logRecords': List.generate(
              recordsInFirstScope,
              (i) => {'body': 'log-$i'},
            ),
          },
          if (extraScopeRecords > 0)
            {
              'logRecords': List.generate(
                extraScopeRecords,
                (i) => {'body': 'extra-$i'},
              ),
            },
        ],
      },
    ],
  };
}

Map<String, dynamic> _metricsPayload() {
  return {
    'resourceMetrics': [
      {
        'scopeMetrics': [
          {
            'metrics': [
              {
                'name': 'requests_total',
                'sum': {
                  'dataPoints': [
                    {'asInt': 1},
                    {'asInt': 2},
                  ],
                },
              },
              {
                'name': 'active_connections',
                'gauge': {
                  'dataPoints': [
                    {'asInt': 5},
                  ],
                },
              },
              {
                'name': 'request_latency',
                'histogram': {
                  'dataPoints': [
                    {'count': 3},
                    {'count': 4},
                    {'count': 5},
                  ],
                },
              },
            ],
          },
        ],
      },
    ],
  };
}

Map<String, dynamic> _spansPayload(int spanCount) {
  return {
    'resourceSpans': [
      {
        'scopeSpans': [
          {
            'spans': List.generate(spanCount, (i) => {'name': 'span-$i'}),
          },
        ],
      },
    ],
  };
}

void main() {
  group('Counters', () {
    test('addLogs counts every logRecords entry across scopeLogs', () {
      final counters = Counters();
      counters.addLogs(_logsPayload(2, extraScopeRecords: 3));
      expect(counters.logRecords, 5);
    });

    test(
      'addMetrics sums sum/gauge/histogram dataPoints and counts histograms separately',
      () {
        final counters = Counters();
        counters.addMetrics(_metricsPayload());
        // 2 (sum) + 1 (gauge) + 3 (histogram) = 6 total data points.
        expect(counters.metricDataPoints, 6);
        expect(counters.histograms, 1);
      },
    );

    test('addSpans counts every span across scopeSpans', () {
      final counters = Counters();
      counters.addSpans(_spansPayload(4));
      expect(counters.spans, 4);
    });

    test('reset zeroes every counter', () {
      final counters = Counters()
        ..addLogs(_logsPayload(2))
        ..addMetrics(_metricsPayload())
        ..addSpans(_spansPayload(3));
      counters.reset();
      expect(counters.toJson(), {
        'logRecords': 0,
        'metricDataPoints': 0,
        'histograms': 0,
        'spans': 0,
      });
    });

    test(
      'addLogs/addMetrics/addSpans ignore payloads missing the expected shape',
      () {
        final counters = Counters();
        counters.addLogs({});
        counters.addMetrics({'resourceMetrics': 'not-a-list'});
        counters.addSpans({
          'resourceSpans': [
            {'scopeSpans': 'not-a-list'},
          ],
        });
        expect(counters.toJson(), {
          'logRecords': 0,
          'metricDataPoints': 0,
          'histograms': 0,
          'spans': 0,
        });
      },
    );
  });

  group('OtlpSinkServer', () {
    late OtlpSinkServer server;
    late int port;

    setUp(() async {
      server = OtlpSinkServer();
      await server.start(port: 0);
      port = server.port;
    });

    tearDown(() async {
      await server.stop();
    });

    test('port getter throws before start() has completed', () {
      final unstarted = OtlpSinkServer();
      expect(() => unstarted.port, throwsStateError);
    });

    test('GET /summary starts at zero', () async {
      final response = await _request(port, 'GET', '/summary');
      expect(response.statusCode, HttpStatus.ok);
      expect(response.json, {
        'logRecords': 0,
        'metricDataPoints': 0,
        'histograms': 0,
        'spans': 0,
      });
    });

    test('counts log records via POST /v1/logs', () async {
      final response = await _request(
        port,
        'POST',
        '/v1/logs',
        body: jsonEncode(_logsPayload(3)),
      );
      expect(response.statusCode, HttpStatus.ok);

      final summary = await _request(port, 'GET', '/summary');
      expect(summary.json['logRecords'], 3);
    });

    test(
      'counts sum and histogram data points separately via POST /v1/metrics',
      () async {
        final response = await _request(
          port,
          'POST',
          '/v1/metrics',
          body: jsonEncode(_metricsPayload()),
        );
        expect(response.statusCode, HttpStatus.ok);

        final summary = await _request(port, 'GET', '/summary');
        expect(summary.json['metricDataPoints'], 6);
        expect(summary.json['histograms'], 1);
      },
    );

    test('counts spans via POST /v1/traces', () async {
      final response = await _request(
        port,
        'POST',
        '/v1/traces',
        body: jsonEncode(_spansPayload(2)),
      );
      expect(response.statusCode, HttpStatus.ok);

      final summary = await _request(port, 'GET', '/summary');
      expect(summary.json['spans'], 2);
    });

    test('POST /reset zeroes counters after data was received', () async {
      await _request(
        port,
        'POST',
        '/v1/logs',
        body: jsonEncode(_logsPayload(2)),
      );
      await _request(
        port,
        'POST',
        '/v1/traces',
        body: jsonEncode(_spansPayload(1)),
      );

      final resetResponse = await _request(port, 'POST', '/reset');
      expect(resetResponse.statusCode, HttpStatus.ok);

      final summary = await _request(port, 'GET', '/summary');
      expect(summary.json, {
        'logRecords': 0,
        'metricDataPoints': 0,
        'histograms': 0,
        'spans': 0,
      });
    });

    test('malformed JSON returns 400 and leaves counters unchanged', () async {
      final response = await _request(
        port,
        'POST',
        '/v1/logs',
        body: '{not valid json',
      );
      expect(response.statusCode, HttpStatus.badRequest);

      final summary = await _request(port, 'GET', '/summary');
      expect(summary.json['logRecords'], 0);
    });

    test(
      'non-object top-level JSON returns 400 and leaves counters unchanged',
      () async {
        final response = await _request(
          port,
          'POST',
          '/v1/metrics',
          body: jsonEncode([1, 2, 3]),
        );
        expect(response.statusCode, HttpStatus.badRequest);

        final summary = await _request(port, 'GET', '/summary');
        expect(summary.json['metricDataPoints'], 0);
      },
    );

    test('unknown path returns 404', () async {
      final response = await _request(port, 'GET', '/nope');
      expect(response.statusCode, HttpStatus.notFound);
    });

    test(
      'missing body on POST /v1/logs is treated as malformed JSON (400)',
      () async {
        final response = await _request(port, 'POST', '/v1/logs');
        expect(response.statusCode, HttpStatus.badRequest);
      },
    );
  });
}
