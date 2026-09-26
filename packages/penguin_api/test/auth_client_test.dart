import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as testing;
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_api/src/middleware/auth_client.dart';
import 'support/scripted_client.dart';

void main() {
  group('AuthClient', () {
    test('adds Authorization header with token', () async {
      final fakeTokens = _FakeTokenProvider('test-token');
      final inner = ScriptedClientBuilder()
          .respond(method: 'GET', pathPattern: '/api', statusCode: 200)
          .build();

      final client = AuthClient(inner: inner, tokens: fakeTokens);

      final response = await client.get(Uri.parse('http://example.com/api'));
      expect(response.statusCode, equals(200));
      expect(
        inner.seenRequests.first.headers['authorization'],
        equals('Bearer test-token'),
      );
    });

    test('replays request after successful refresh on 401', () async {
      final fakeTokens = _FakeTokenProvider('old-token', 'new-token');
      final builder = ScriptedClientBuilder();
      // First request gets 401, second gets 200
      builder
          .respond(method: 'GET', pathPattern: '/api', statusCode: 401)
          .respond(method: 'GET', pathPattern: '/api', statusCode: 200);

      final inner = builder.build();
      final client = AuthClient(inner: inner, tokens: fakeTokens);

      final response = await client.get(Uri.parse('http://example.com/api'));
      expect(response.statusCode, equals(200));

      // Should have sent the request twice
      expect(inner.seenRequests.length, equals(2));
      // Second request should have new token
      expect(
        inner.seenRequests[1].headers['authorization'],
        equals('Bearer new-token'),
      );
    });

    test('emits unauthenticated event on refresh failure', () async {
      final fakeTokens = _FakeTokenProvider.withRefreshFailure('token');
      final inner = ScriptedClientBuilder()
          .respond(method: 'GET', pathPattern: '/api', statusCode: 401)
          .build();

      final client = AuthClient(inner: inner, tokens: fakeTokens);

      final events = <AuthEvent>[];
      fakeTokens.events.listen(events.add);

      final response = await client.get(Uri.parse('http://example.com/api'));

      expect(response.statusCode, equals(401));
      expect(events, contains(AuthEvent.unauthenticated));
    });

    test('does not replay on second 401 after refresh', () async {
      final fakeTokens = _FakeTokenProvider('token', 'new-token');
      final builder = ScriptedClientBuilder();
      builder
          .respond(method: 'GET', pathPattern: '/api', statusCode: 401)
          .respond(method: 'GET', pathPattern: '/api', statusCode: 401);

      final inner = builder.build();
      final client = AuthClient(inner: inner, tokens: fakeTokens);

      final response = await client.get(Uri.parse('http://example.com/api'));

      // Should return the 401 from the replay
      expect(response.statusCode, equals(401));
      // Should have sent exactly two requests: initial + one retry
      expect(inner.seenRequests.length, equals(2));
    });

    test('buffers request body for replay', () async {
      final fakeTokens = _FakeTokenProvider('token', 'new-token');
      final builder = ScriptedClientBuilder();
      builder
          .respondWhen(
            predicate: (req) =>
                req.method == 'POST' && req.url.path.contains('/api'),
            statusCode: 401,
            description: 'POST /api first → 401',
          )
          .respondWhen(
            predicate: (req) => req.method == 'POST',
            statusCode: 200,
            body: '{"ok":true}',
            description: 'POST → 200',
          );

      final inner = builder.build();
      final client = AuthClient(inner: inner, tokens: fakeTokens);

      final request = http.Request('POST', Uri.parse('http://example.com/api'));
      request.body = '{"data":"test"}';

      final response = await client.send(request);
      expect(response.statusCode, equals(200));

      // Second request (after refresh) should have same body
      final secondRequest = inner.seenRequests[1];
      expect(secondRequest.body, equals('{"data":"test"}'));
    });

    test(
      'throws when replaying a MultipartRequest whose files were already sent',
      () async {
        // A MultipartFile can only be finalized once ever (package:http),
        // so once the first send has drained its body — which the initial
        // 401 attempt below does — reusing the same MultipartRequest for a
        // replay is unsafe and must be rejected loudly rather than risk
        // sending a drained stream.
        final fakeTokens = _FakeTokenProvider('token', 'new-token');
        final inner = ScriptedClientBuilder()
            .respond(method: 'POST', pathPattern: '/api', statusCode: 401)
            .build();
        final client = AuthClient(inner: inner, tokens: fakeTokens);

        final request = http.MultipartRequest(
          'POST',
          Uri.parse('http://example.com/api'),
        )..fields['name'] = 'widget';

        await expectLater(client.send(request), throwsStateError);
      },
    );

    test(
      'throws StateError when replaying a StreamedRequest after a 401',
      () async {
        final fakeTokens = _FakeTokenProvider('token', 'new-token');
        final inner = ScriptedClientBuilder()
            .respond(method: 'POST', pathPattern: '/api', statusCode: 401)
            .build();
        final client = AuthClient(inner: inner, tokens: fakeTokens);

        final request = http.StreamedRequest(
          'POST',
          Uri.parse('http://example.com/api'),
        );
        unawaited(request.sink.close());

        await expectLater(client.send(request), throwsStateError);
      },
    );

    test(
      'throws UnsupportedError when replaying an unrecognized request type after a 401',
      () async {
        final fakeTokens = _FakeTokenProvider('token', 'new-token');
        final inner = ScriptedClientBuilder()
            .respond(method: 'GET', pathPattern: '/api', statusCode: 401)
            .build();
        final client = AuthClient(inner: inner, tokens: fakeTokens);

        final request = _CustomRequest(
          'GET',
          Uri.parse('http://example.com/api'),
        );

        await expectLater(client.send(request), throwsUnsupportedError);
      },
    );

    test('coalesces concurrent 401s into a single refresh() call', () async {
      final fakeTokens = _CountingRefreshTokenProvider();
      final inner = testing.MockClient((request) async {
        final auth = request.headers['authorization'];
        if (auth == 'Bearer old-token') {
          return http.Response('', 401);
        }
        return http.Response('{"ok":true}', 200);
      });
      final client = AuthClient(inner: inner, tokens: fakeTokens);

      // Two 401s in flight at once, before either has had a chance to
      // finish its refresh — only one `refresh()` call should result.
      final first = client.get(Uri.parse('http://example.com/api/a'));
      final second = client.get(Uri.parse('http://example.com/api/b'));

      final responses = await Future.wait([first, second]);

      expect(responses[0].statusCode, equals(200));
      expect(responses[1].statusCode, equals(200));
      expect(fakeTokens.refreshCalls, equals(1));
    });
  });
}

/// A minimal [http.BaseRequest] that is neither [http.Request],
/// [http.MultipartRequest], nor [http.StreamedRequest] — used to exercise
/// [AuthClient]'s fallback branch for an unrecognized request type.
class _CustomRequest extends http.BaseRequest {
  _CustomRequest(super.method, super.url);

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream.fromBytes([]);
  }
}

class _FakeTokenProvider implements TokenProvider {
  _FakeTokenProvider(this._token, [this._refreshToken])
    : shouldRefreshFail = false;

  _FakeTokenProvider.withRefreshFailure(this._token)
    : _refreshToken = null,
      shouldRefreshFail = true;

  String _token;
  final String? _refreshToken;
  final bool shouldRefreshFail;
  final _events = StreamController<AuthEvent>.broadcast();

  @override
  Future<String?> accessToken() async => _token;

  @override
  Future<bool> refresh() async {
    if (shouldRefreshFail) {
      _events.add(AuthEvent.unauthenticated);
      return false;
    }
    if (_refreshToken != null) {
      _token = _refreshToken;
      _events.add(AuthEvent.refreshed);
      return true;
    }
    return false;
  }

  @override
  Stream<AuthEvent> get events => _events.stream;
}

/// A [TokenProvider] whose `refresh()` counts its own calls and takes a
/// short delay before completing, so tests can drive two concurrent 401s
/// through the refresh window and assert only one real `refresh()` ran.
class _CountingRefreshTokenProvider implements TokenProvider {
  int refreshCalls = 0;
  bool _refreshed = false;

  @override
  Future<String?> accessToken() async => _refreshed ? 'new-token' : 'old-token';

  @override
  Future<bool> refresh() async {
    refreshCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    _refreshed = true;
    return true;
  }

  @override
  Stream<AuthEvent> get events => const Stream.empty();
}
