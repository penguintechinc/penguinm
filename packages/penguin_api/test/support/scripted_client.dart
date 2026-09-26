import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as testing;

/// A test double for [http.Client] built on `package:http/testing.dart`'s
/// [testing.MockClient] — never a hand-rolled [http.BaseClient] — so every
/// send goes through the real request lifecycle: [testing.MockClient.send]
/// calls `BaseRequest.finalize()` exactly as `IOClient` (or any production
/// client) would, so sending the same request instance twice throws the
/// same `StateError` a real server round-trip would. Fed by a queue of
/// scripted (predicate, response) pairs consumed in order; records every
/// request it receives so tests can assert on what was actually sent.
class ScriptedClient extends http.BaseClient {
  /// Creates a client fed by [_scripts], a queue of (predicate, response)
  /// pairs; each incoming request is matched against predicates in order.
  ScriptedClient(this._scripts) {
    _mock = testing.MockClient((request) async {
      seenRequests.add(request);

      for (var i = _scriptIndex; i < _scripts.length; i++) {
        final script = _scripts[i];
        if (script.predicate(request)) {
          _scriptIndex = i + 1;
          return script.response;
        }
      }

      throw StateError(
        'ScriptedClient: no matching script (starting from index '
        '$_scriptIndex) for ${request.method} ${request.url}\n'
        'Expected one of: ${_scripts.map((s) => s.description).join(", ")}',
      );
    });
  }

  /// Queue of (predicate, response) pairs applied in order to incoming
  /// requests.
  final List<_Script> _scripts;

  late final testing.MockClient _mock;

  /// Every request this client has received, in order. These are the
  /// *finalized* [http.Request] objects `MockClient` reconstructs
  /// internally — faithful copies of method/url/headers/body, but not the
  /// exact instance the caller sent.
  final List<http.Request> seenRequests = [];

  /// Index of the next script to use (scripts are consumed in order).
  int _scriptIndex = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _mock.send(request);
}

/// A single scripted (predicate, response) pair.
class _Script {
  _Script({
    required this.predicate,
    required this.response,
    required this.description,
  });

  final bool Function(http.BaseRequest request) predicate;
  final http.Response response;
  final String description;
}

/// Builder for scripted client responses, fluent style.
class ScriptedClientBuilder {
  final List<_Script> _scripts = [];

  /// Adds a response matched by [method] and [pathPattern] (substring match),
  /// returning [statusCode] with [body] (defaults to empty).
  ScriptedClientBuilder respond({
    required String method,
    required String pathPattern,
    required int statusCode,
    String body = '',
    Map<String, String> headers = const {},
  }) {
    _scripts.add(
      _Script(
        predicate: (req) =>
            req.method == method && req.url.path.contains(pathPattern),
        response: http.Response(
          body,
          statusCode,
          headers: {'content-type': 'application/json', ...headers},
        ),
        description: '$method $pathPattern → $statusCode',
      ),
    );
    return this;
  }

  /// Adds a response matched by a custom [predicate], returning
  /// [statusCode] with [body].
  ScriptedClientBuilder respondWhen({
    required bool Function(http.BaseRequest) predicate,
    required int statusCode,
    String body = '',
    Map<String, String> headers = const {},
    String description = '(custom)',
  }) {
    _scripts.add(
      _Script(
        predicate: predicate,
        response: http.Response(
          body,
          statusCode,
          headers: {'content-type': 'application/json', ...headers},
        ),
        description: description,
      ),
    );
    return this;
  }

  /// Builds the client.
  ScriptedClient build() => ScriptedClient(_scripts);
}
