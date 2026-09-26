/// CLI entry point for the local OTLP/HTTP smoke-test sink:
/// `dart run otlp_sink --port 4318 [--host 127.0.0.1]`. Starts
/// [OtlpSinkServer] and keeps the process alive until SIGINT/SIGTERM, so
/// `telemetry-validate.sh` can run it in the background and kill it on exit.
library;

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:otlp_sink/otlp_sink.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'port',
      abbr: 'p',
      defaultsTo: '4318',
      help: 'TCP port to bind.',
    )
    ..addOption('host', defaultsTo: '127.0.0.1', help: 'Address to bind.')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage.');

  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln('otlp_sink: ${error.message}');
    stderr.writeln(parser.usage);
    exitCode = 64;
    return;
  }

  if (results['help'] as bool) {
    // ignore: avoid_print
    print(parser.usage);
    return;
  }

  final portArg = results['port'] as String;
  final port = int.tryParse(portArg);
  if (port == null || port < 0 || port > 65535) {
    stderr.writeln('otlp_sink: invalid --port value "$portArg"');
    exitCode = 64;
    return;
  }
  final host = results['host'] as String;

  final server = OtlpSinkServer();
  await server.start(host: host, port: port);
  // ignore: avoid_print
  print('otlp_sink: listening on http://$host:${server.port}');

  final completer = Completer<void>();
  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    signal.watch().listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
  }
  await completer.future;

  // ignore: avoid_print
  print('otlp_sink: shutting down');
  await server.stop();
}
