/// A local OTLP/HTTP JSON receiver used only for smoke-test telemetry
/// validation. Never deployed — `telemetry-validate.sh` runs it as a
/// throwaway process alongside the reference app's test suite.
library;

import 'dart:convert';
import 'dart:io';

import 'counters.dart';

/// OTLP endpoint paths this sink accepts a `POST` body on.
const Set<String> _otlpPaths = {'/v1/logs', '/v1/metrics', '/v1/traces'};

/// Local OTLP/HTTP JSON receiver. Binds a single [HttpServer], decodes each
/// `POST /v1/{logs,metrics,traces}` body into [counters] via the matching
/// aggregation rule, and serves `GET /summary` / `POST /reset` so
/// `telemetry-validate.sh` can assert non-zero emission on every commit.
class OtlpSinkServer {
  /// Creates a sink with fresh [counters], or the given ones for tests that
  /// need to inspect state set up ahead of time.
  OtlpSinkServer({Counters? counters}) : counters = counters ?? Counters();

  /// Counters accumulated from every payload received so far.
  final Counters counters;

  HttpServer? _server;

  /// The bound port. Only valid after [start] has completed.
  int get port {
    final server = _server;
    if (server == null) {
      throw StateError('OtlpSinkServer.start() has not completed');
    }
    return server.port;
  }

  /// Binds `host:port` (port `0` picks an ephemeral port) and starts
  /// accepting requests. Each request is logged as one line to stdout.
  Future<void> start({String host = '127.0.0.1', int port = 4318}) async {
    final server = await HttpServer.bind(host, port);
    _server = server;
    server.listen(_handle);
  }

  /// Stops accepting connections and releases the bound socket. Safe to
  /// call more than once.
  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _handle(HttpRequest request) async {
    final method = request.method;
    final path = request.uri.path;
    // ignore: avoid_print
    print('$method $path');

    try {
      if (method == 'GET' && path == '/summary') {
        await _respondJson(request.response, HttpStatus.ok, counters.toJson());
        return;
      }

      if (method == 'POST' && path == '/reset') {
        counters.reset();
        await _respondJson(request.response, HttpStatus.ok, const {
          'status': 'reset',
        });
        return;
      }

      if (method == 'POST' && _otlpPaths.contains(path)) {
        await _handleOtlpPost(request, path);
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    } on Object catch (error) {
      // ignore: avoid_print
      print('error handling $method $path: $error');
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }

  Future<void> _handleOtlpPost(HttpRequest request, String path) async {
    final rawBody = await utf8.decoder.bind(request).join();

    final Map<String, dynamic> body;
    try {
      final decoded = rawBody.isEmpty ? null : jsonDecode(rawBody);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('top-level OTLP JSON must be an object');
      }
      body = decoded;
    } on FormatException {
      await _respondJson(request.response, HttpStatus.badRequest, const {
        'error': 'malformed JSON',
      });
      return;
    }

    switch (path) {
      case '/v1/logs':
        counters.addLogs(body);
      case '/v1/metrics':
        counters.addMetrics(body);
      case '/v1/traces':
        counters.addSpans(body);
    }

    await _respondJson(request.response, HttpStatus.ok, const {'status': 'ok'});
  }

  Future<void> _respondJson(
    HttpResponse response,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }
}
