import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';

/// [TokenProvider] fake for [SyncQueue] tests: always returns a token and
/// always reports a successful refresh, so a `401` response drives exactly
/// one [AuthClient] replay (matching `AuthClient`'s real refresh-and-replay
/// behaviour) without needing a real auth backend.
class FakeTokenProvider implements TokenProvider {
  final _events = StreamController<AuthEvent>.broadcast();

  @override
  Future<String?> accessToken() async => 'test-token';

  @override
  Future<bool> refresh() async {
    _events.add(AuthEvent.refreshed);
    return true;
  }

  @override
  Stream<AuthEvent> get events => _events.stream;
}

/// Builds a minimal [AppConfig] for tests that only care about
/// [PenguinApiClient]'s request plumbing, not real config values.
AppConfig testAppConfig() => AppConfig(
  productKey: 'test',
  appVersion: '1.0.0',
  environment: PenguinEnvironment.prealpha,
  apiBaseUrl: Uri.parse('http://api.example.com'),
  licenseServerUrl: 'https://license.example.com',
);

/// A queue of scripted HTTP responses fed to [http.testing.MockClient],
/// recording every request it receives (including `AuthClient`'s 401
/// refresh-and-replay calls and any internal `RetryClient` attempts) so
/// tests can assert exact method/path/header/order.
class ScriptedResponses {
  ScriptedResponses(this._responses);

  final List<http.Response> _responses;

  /// Every request seen, in the order [handle] was called.
  final List<http.Request> seen = [];

  int _index = 0;

  /// The handler passed to `MockClient(...)`.
  Future<http.Response> handle(http.Request request) async {
    seen.add(request);
    if (_index >= _responses.length) {
      throw StateError(
        'ScriptedResponses: no response queued for call #${_index + 1} '
        '(${request.method} ${request.url.path})',
      );
    }
    return _responses[_index++];
  }
}

/// Shorthand for a scripted JSON response.
http.Response jsonResponse(int statusCode, [String body = '{}']) =>
    http.Response(
      body,
      statusCode,
      headers: {'content-type': 'application/json'},
    );
