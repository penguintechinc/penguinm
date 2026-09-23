@Tags(['contract'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_testing/penguin_testing.dart';

/// An [HttpOverrides] with no overridden behavior: its inherited
/// `createHttpClient` builds a real, socket-backed [HttpClient] instead of
/// the fake one `flutter_test` installs globally to block real sockets —
/// see this task's agent-rules (found by T4; calling the top-level
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
  OtlpSinkClient client, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    try {
      await client.summary();
      return;
    } on Object {
      // Not ready yet; retry until the deadline.
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('otlp_sink did not become ready within $timeout');
}

void main() {
  test(
    'OtlpSinkClient reads /summary and resets a live otlp_sink process',
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

        final client = OtlpSinkClient(
          baseUrl: Uri.parse('http://127.0.0.1:$port'),
        );

        try {
          await _waitUntilReady(client);

          final initial = await client.summary();
          expect(initial.logRecords, 0);
          expect(initial.metricDataPoints, 0);
          expect(initial.histograms, 0);
          expect(initial.spans, 0);

          // Post a minimal OTLP logs payload directly so the sink's
          // counters move, proving OtlpSinkClient reads real state rather
          // than a hardcoded zero.
          final poster = HttpClient();
          final request = await poster.postUrl(
            Uri.parse('http://127.0.0.1:$port/v1/logs'),
          );
          request.headers.contentType = ContentType.json;
          request.write(
            '{"resourceLogs":[{"scopeLogs":[{"logRecords":[{}]}]}]}',
          );
          final response = await request.close();
          await response.drain<void>();
          poster.close(force: true);

          final afterPost = await client.summary();
          expect(afterPost.logRecords, 1);

          await client.reset();
          final afterReset = await client.summary();
          expect(afterReset.logRecords, 0);
        } finally {
          client.close();
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
