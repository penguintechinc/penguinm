@Tags(['contract'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_telemetry/penguin_telemetry.dart';

/// An [HttpOverrides] with no overridden behavior: its inherited
/// `createHttpClient` builds a real, socket-backed [HttpClient] instead of
/// the fake one `flutter_test` installs globally to block real sockets —
/// the correct pattern per this task's agent-rules (calling the top-level
/// `HttpClient()` factory from inside a `createHttpClient` callback would
/// re-enter the same override and recurse forever; this doesn't do that).
class _RealHttp extends HttpOverrides {}

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Future<void> _waitUntilReady(
  int port, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/summary'),
      );
      final response = await request.close();
      await response.drain<void>();
      client.close(force: true);
      if (response.statusCode == 200) return;
    } on Object {
      // Not ready yet; retry until the deadline.
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError(
    'otlp_sink did not become ready on port $port within $timeout',
  );
}

Future<Map<String, dynamic>> _summary(int port) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse('http://127.0.0.1:$port/summary'),
    );
    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();
    return jsonDecode(body) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

void main() {
  test(
    'the real OtlpHttpJsonExporter feeds a live otlp_sink process',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final port = await _freePort();

        final process = await Process.start('dart', <String>[
          'run',
          'otlp_sink',
          '--port',
          '$port',
        ], workingDirectory: '../../tooling/otlp_sink');
        process.stdout.listen((_) {});
        process.stderr.listen((_) {});

        try {
          await _waitUntilReady(port);

          final telemetry = await Telemetry.start(
            TelemetryConfig(
              serviceName: 'contract-test',
              serviceVersion: '0.1.0',
              endpoint: Uri.parse('http://127.0.0.1:$port'),
              exportInterval: const Duration(minutes: 10),
            ),
          );

          telemetry.logger.info('contract test log record');
          telemetry.meter.counter('contract.counter').add(1);
          telemetry.meter.histogram('contract.histogram').record(42);
          telemetry.tracer.startSpan('contract-span').end();

          await telemetry.flush();
          await telemetry.shutdown();

          final summary = await _summary(port);

          expect((summary['logRecords']! as int) >= 1, isTrue);
          expect((summary['metricDataPoints']! as int) >= 1, isTrue);
          expect((summary['histograms']! as int) >= 1, isTrue);
          expect((summary['spans']! as int) >= 1, isTrue);
        } finally {
          process.kill(ProcessSignal.sigterm);
          await process.exitCode.timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              process.kill(ProcessSignal.sigkill);
              return -1;
            },
          );
        }
      }, _RealHttp());
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
