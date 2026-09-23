import 'package:http/http.dart' as http;
import 'package:http/testing.dart' show MockClient;

/// One scripted outcome for the next unmatched request: either a response
/// to return (after an optional delay) or an error to throw.
class _ScriptedEntry {
  _ScriptedEntry.response({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.delay,
  }) : error = null;

  _ScriptedEntry.error(Object this.error)
    : statusCode = 0,
      body = '',
      headers = const <String, String>{},
      delay = Duration.zero;

  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final Duration delay;
  final Object? error;
}

/// A scripted [http.Client] for tests: [queueResponse]/[queueError] enqueue
/// outcomes consumed in FIFO order by [send], and every request received is
/// recorded in [seenRequests].
///
/// Built on `package:http/testing.dart`'s [MockClient] rather than a
/// hand-rolled [http.BaseClient] subclass — [MockClient.send] finalizes the
/// incoming request exactly like a real client, so a caller (e.g. a retry
/// middleware) that resends the same [http.Request] object instead of
/// building a fresh one crashes here exactly as it would against a real
/// server, instead of silently succeeding. See
/// `throws a StateError when the same request is sent twice` in this
/// package's test suite.
class ScriptedHttpClient extends http.BaseClient {
  /// Creates a scripted client. [delayFn] performs a queued response's
  /// delay (defaults to a real [Future.delayed]); tests that don't want to
  /// wait in real time can inject a fake that completes immediately (or
  /// records the requested [Duration] and drives it manually), so a
  /// scripted delay never forces a real sleep.
  ScriptedHttpClient({Future<void> Function(Duration)? delayFn})
    : _delayFn = delayFn ?? ((duration) => Future<void>.delayed(duration)) {
    _mock = MockClient(_handle);
  }

  late final MockClient _mock;
  final Future<void> Function(Duration) _delayFn;
  final List<_ScriptedEntry> _queue = <_ScriptedEntry>[];

  /// Every request this client has received, in order, after finalization
  /// (body already read into [http.Request.bodyBytes]).
  final List<http.Request> seenRequests = <http.Request>[];

  /// Appends a response outcome, returned to the next unmatched [send]
  /// call. FIFO — the first queued response answers the first request.
  void queueResponse({
    int statusCode = 200,
    String body = '',
    Map<String, String> headers = const <String, String>{
      'content-type': 'application/json',
    },
    Duration delay = Duration.zero,
  }) {
    _queue.add(
      _ScriptedEntry.response(
        statusCode: statusCode,
        body: body,
        headers: headers,
        delay: delay,
      ),
    );
  }

  /// Appends an error outcome — the next unmatched [send] call rethrows
  /// [error] instead of returning a response, for exercising network
  /// failure paths (`ClientException`, `SocketException`, ...).
  void queueError(Object error) {
    _queue.add(_ScriptedEntry.error(error));
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _mock.send(request);

  Future<http.Response> _handle(http.Request request) async {
    seenRequests.add(request);
    if (_queue.isEmpty) {
      throw StateError(
        'ScriptedHttpClient: no scripted response queued for '
        '${request.method} ${request.url}',
      );
    }
    final entry = _queue.removeAt(0);
    if (entry.delay > Duration.zero) {
      await _delayFn(entry.delay);
    }
    final error = entry.error;
    if (error != null) throw error;
    return http.Response(
      entry.body,
      entry.statusCode,
      headers: entry.headers,
      request: request,
    );
  }

  @override
  void close() {
    _mock.close();
  }
}
