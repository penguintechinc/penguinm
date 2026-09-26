import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as testing;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_api/penguin_api.dart';
import 'support/scripted_client.dart';

void main() {
  group('PenguinApiClient', () {
    test('get returns decoded result on success', () async {
      final builder = ScriptedClientBuilder();
      builder.respond(
        method: 'GET',
        pathPattern: '/api/items',
        statusCode: 200,
        body: '{"name":"test"}',
      );

      final config = _FakeConfig();
      final tokens = _FakeTokenProvider();
      final client = PenguinApiClient(
        config: config,
        tokens: tokens,
        inner: builder.build(),
      );

      final result = await client.get(
        '/api/items',
        decode: (json) => (json as Map)['name'],
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, equals('test'));
    });

    test('post returns decoded result on success', () async {
      final builder = ScriptedClientBuilder();
      builder.respondWhen(
        predicate: (req) => req.method == 'POST',
        statusCode: 201,
        body: '{"id":42}',
      );

      final config = _FakeConfig();
      final tokens = _FakeTokenProvider();
      final client = PenguinApiClient(
        config: config,
        tokens: tokens,
        inner: builder.build(),
      );

      final result = await client.post(
        '/items',
        body: {'name': 'new'},
        decode: (json) => (json as Map)['id'],
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, equals(42));
    });

    test('setBaseUrl only affects requests issued after the call', () async {
      final builder = ScriptedClientBuilder();
      builder
          .respondWhen(
            predicate: (req) => req.url.host == 'api.example.com',
            statusCode: 200,
            body: '{"ok":true}',
            description: 'GET on original host',
          )
          .respondWhen(
            predicate: (req) => req.url.host == 'new-host.com',
            statusCode: 200,
            body: '{"ok":true}',
            description: 'GET on new-host.com',
          );

      final config = _FakeConfig();
      final tokens = _FakeTokenProvider();
      final inner = builder.build();
      final client = PenguinApiClient(
        config: config,
        tokens: tokens,
        inner: inner,
      );

      final first = await client.get('/test', decode: (json) => true);
      expect(first.isOk, isTrue);
      expect(inner.seenRequests[0].url.host, equals('api.example.com'));

      client.setBaseUrl(Uri.parse('https://new-host.com'));

      final second = await client.get('/test', decode: (json) => true);
      expect(second.isOk, isTrue);
      expect(inner.seenRequests[1].url.host, equals('new-host.com'));
    });

    test('query parameters are included in URL', () async {
      final builder = ScriptedClientBuilder();
      builder.respondWhen(
        predicate: (req) =>
            req.url.path.contains('/items') &&
            req.url.queryParameters['page'] == '2',
        statusCode: 200,
        body: '[]',
      );

      final config = _FakeConfig();
      final tokens = _FakeTokenProvider();
      final client = PenguinApiClient(
        config: config,
        tokens: tokens,
        inner: builder.build(),
      );

      final result = await client.get(
        '/items',
        query: {'page': '2'},
        decode: (json) => (json as List).length,
      );

      expect(result.isOk, isTrue);
    });

    test('put sends request correctly', () async {
      final builder = ScriptedClientBuilder();
      builder.respondWhen(
        predicate: (req) => req.method == 'PUT',
        statusCode: 200,
        body: '{"updated":true}',
      );

      final config = _FakeConfig();
      final tokens = _FakeTokenProvider();
      final client = PenguinApiClient(
        config: config,
        tokens: tokens,
        inner: builder.build(),
      );

      final result = await client.put(
        '/items/1',
        body: {'name': 'updated'},
        decode: (json) => true,
      );

      expect(result.isOk, isTrue);
    });

    test('patch sends request correctly', () async {
      final builder = ScriptedClientBuilder();
      builder.respondWhen(
        predicate: (req) => req.method == 'PATCH',
        statusCode: 200,
        body: '{"patched":true}',
      );

      final config = _FakeConfig();
      final tokens = _FakeTokenProvider();
      final client = PenguinApiClient(
        config: config,
        tokens: tokens,
        inner: builder.build(),
      );

      final result = await client.patch(
        '/items/1',
        body: {'name': 'patched'},
        decode: (json) => true,
      );

      expect(result.isOk, isTrue);
    });

    test('patch without Idempotency-Key is not retried on 503', () async {
      final builder = ScriptedClientBuilder();
      builder.respond(method: 'PATCH', pathPattern: '/items', statusCode: 503);

      final config = _FakeConfig();
      final tokens = _FakeTokenProvider();
      final inner = builder.build();
      final client = PenguinApiClient(
        config: config,
        tokens: tokens,
        inner: inner,
        retry: const RetryPolicy(
          baseDelay: Duration(milliseconds: 1),
          jitter: false,
        ),
      );

      final result = await client.patch(
        '/items',
        body: {'name': 'new'},
        decode: (json) => null,
      );

      expect(result.isOk, isFalse);
      expect(result.fold((ok) => null, (err) => err), isA<ServerFailure>());
      expect(inner.seenRequests.length, equals(1));
    });

    test('delete sends request correctly', () async {
      final builder = ScriptedClientBuilder();
      builder.respondWhen(
        predicate: (req) => req.method == 'DELETE',
        statusCode: 204,
      );

      final config = _FakeConfig();
      final tokens = _FakeTokenProvider();
      final client = PenguinApiClient(
        config: config,
        tokens: tokens,
        inner: builder.build(),
      );

      final result = await client.delete('/items/1', decode: (json) => null);

      expect(result.isOk, isTrue);
    });

    test('fetchClientVersion parses response', () async {
      final builder = ScriptedClientBuilder();
      builder.respond(
        method: 'GET',
        pathPattern: '/api/v1/client/version',
        statusCode: 200,
        body:
            '{"latestVersion":"2.0.0","minimumVersion":"1.5.0","storeUrl":"https://play.google.com/store"}',
      );

      final config = _FakeConfig();
      final tokens = _FakeTokenProvider();
      final client = PenguinApiClient(
        config: config,
        tokens: tokens,
        inner: builder.build(),
      );

      final result = await client.fetchClientVersion();

      expect(result.isOk, isTrue);
      expect(result.valueOrNull?.latestVersion, equals('2.0.0'));
      expect(result.valueOrNull?.minimumVersion, equals('1.5.0'));
    });

    test('handles 401 error as AuthFailure when refresh fails', () async {
      final builder = ScriptedClientBuilder();
      builder.respond(method: 'GET', pathPattern: '/api', statusCode: 401);

      final config = _FakeConfig();
      final tokens = _FakeTokenProvider(refreshSucceeds: false);
      final client = PenguinApiClient(
        config: config,
        tokens: tokens,
        inner: builder.build(),
      );

      final result = await client.get('/api/test', decode: (json) => null);

      expect(result.isOk, isFalse);
      expect(result.fold((ok) => null, (err) => err), isA<AuthFailure>());
    });

    test('handles network error as NetworkFailure', () async {
      final config = _FakeConfig();
      final tokens = _FakeTokenProvider();
      final innerClient = testing.MockClient((request) async {
        throw http.ClientException('Network error');
      });

      final client = PenguinApiClient(
        config: config,
        tokens: tokens,
        inner: innerClient,
        retry: const RetryPolicy(
          maxAttempts: 2,
          baseDelay: Duration(milliseconds: 1),
          jitter: false,
        ),
      );

      final result = await client.get('/test', decode: (json) => null);

      expect(result.isOk, isFalse);
      expect(result.fold((ok) => null, (err) => err), isA<NetworkFailure>());
    });

    test('timeout maps to NetworkFailure', () async {
      final config = _FakeConfig();
      final tokens = _FakeTokenProvider();
      final client = PenguinApiClient(
        config: config,
        tokens: tokens,
        inner: testing.MockClient(
          (request) => Completer<http.Response>().future,
        ),
        timeout: const Duration(milliseconds: 30),
      );

      final result = await client.get('/test', decode: (json) => null);

      expect(result.isOk, isFalse);
      expect(result.fold((ok) => null, (err) => err), isA<NetworkFailure>());
    });

    test(
      '401 then refresh then replay succeeds and re-sends the body intact',
      () async {
        final builder = ScriptedClientBuilder();
        builder
            .respondWhen(
              predicate: (req) => req.method == 'POST',
              statusCode: 401,
              description: 'POST first attempt -> 401',
            )
            .respondWhen(
              predicate: (req) => req.method == 'POST',
              statusCode: 200,
              body: '{"ok":true}',
              description: 'POST replay -> 200',
            );

        final config = _FakeConfig();
        final tokens = _FakeTokenProvider(
          initialToken: 'old-token',
          refreshedToken: 'new-token',
        );
        final inner = builder.build();
        final client = PenguinApiClient(
          config: config,
          tokens: tokens,
          inner: inner,
        );

        final result = await client.post(
          '/items',
          body: {'name': 'widget'},
          decode: (json) => (json as Map)['ok'],
        );

        expect(result.isOk, isTrue);
        expect(result.valueOrNull, isTrue);

        // Exactly two real network requests: the original 401 and the replay.
        expect(inner.seenRequests.length, equals(2));
        final first = inner.seenRequests[0];
        final second = inner.seenRequests[1];
        expect(first.body, equals(jsonEncode({'name': 'widget'})));
        expect(second.body, equals(first.body));
        expect(first.headers['authorization'], equals('Bearer old-token'));
        expect(second.headers['authorization'], equals('Bearer new-token'));
      },
    );

    test(
      'refresh failure emits AuthEvent.unauthenticated and returns AuthFailure',
      () async {
        final builder = ScriptedClientBuilder();
        builder.respond(method: 'GET', pathPattern: '/api', statusCode: 401);

        final config = _FakeConfig();
        final tokens = _FakeTokenProvider(refreshSucceeds: false);
        final inner = builder.build();
        final client = PenguinApiClient(
          config: config,
          tokens: tokens,
          inner: inner,
        );

        final events = <AuthEvent>[];
        tokens.events.listen(events.add);

        final result = await client.get('/api/test', decode: (json) => null);

        expect(result.isOk, isFalse);
        expect(result.fold((ok) => null, (err) => err), isA<AuthFailure>());
        expect(events, contains(AuthEvent.unauthenticated));
        // Refresh failure means no replay attempt: one real request only.
        expect(inner.seenRequests.length, equals(1));
      },
    );

    test('retries 503 then succeeds, sending exactly two requests', () async {
      final builder = ScriptedClientBuilder();
      builder
          .respond(method: 'GET', pathPattern: '/items', statusCode: 503)
          .respond(
            method: 'GET',
            pathPattern: '/items',
            statusCode: 200,
            body: '{"name":"ok"}',
          );

      final config = _FakeConfig();
      final tokens = _FakeTokenProvider();
      final inner = builder.build();
      final client = PenguinApiClient(
        config: config,
        tokens: tokens,
        inner: inner,
        retry: const RetryPolicy(
          baseDelay: Duration(milliseconds: 1),
          jitter: false,
        ),
      );

      final result = await client.get(
        '/items',
        decode: (json) => (json as Map)['name'],
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull, equals('ok'));
      expect(inner.seenRequests.length, equals(2));
    });

    test('POST without Idempotency-Key is not retried on 503', () async {
      final builder = ScriptedClientBuilder();
      builder.respond(method: 'POST', pathPattern: '/items', statusCode: 503);

      final config = _FakeConfig();
      final tokens = _FakeTokenProvider();
      final inner = builder.build();
      final client = PenguinApiClient(
        config: config,
        tokens: tokens,
        inner: inner,
        retry: const RetryPolicy(
          baseDelay: Duration(milliseconds: 1),
          jitter: false,
        ),
      );

      final result = await client.post(
        '/items',
        body: {'name': 'new'},
        decode: (json) => null,
      );

      expect(result.isOk, isFalse);
      expect(result.fold((ok) => null, (err) => err), isA<ServerFailure>());
      expect(inner.seenRequests.length, equals(1));
    });

    test('uses a default http.Client when none is injected', () async {
      final config = _FakeConfig();
      final tokens = _FakeTokenProvider();
      // No `inner:` passed — exercises the `inner ??= http.Client()`
      // fallback. flutter_test's binding intercepts real HTTP with a fake
      // 400 response, so this stays fast and offline.
      final client = PenguinApiClient(config: config, tokens: tokens);

      final result = await client.get('/test', decode: (json) => null);

      expect(result.isOk, isFalse);
    });

    test('exposes the composed middleware chain via the client getter', () {
      final config = _FakeConfig();
      final tokens = _FakeTokenProvider();
      final client = PenguinApiClient(
        config: config,
        tokens: tokens,
        inner: ScriptedClientBuilder().build(),
      );

      expect(client.client, isA<http.Client>());
    });

    test(
      'fetchClientVersion maps a non-object JSON response to UnknownFailure',
      () async {
        final builder = ScriptedClientBuilder();
        builder.respond(
          method: 'GET',
          pathPattern: '/api/v1/client/version',
          statusCode: 200,
          body: '[1,2,3]',
        );

        final config = _FakeConfig();
        final tokens = _FakeTokenProvider();
        final client = PenguinApiClient(
          config: config,
          tokens: tokens,
          inner: builder.build(),
        );

        final result = await client.fetchClientVersion();

        expect(result.isOk, isFalse);
        expect(result.fold((ok) => null, (err) => err), isA<UnknownFailure>());
      },
    );

    test(
      'a decode failure never leaks raw exception text (e.g. secrets) into the failure message',
      () async {
        // Non-JSON body containing something secret-shaped; the decoder
        // below throws a real FormatException whose own message embeds the
        // exact source text ("...at character 1\ntoken=abc123\n^..."). The
        // resulting Failure.message must never repeat that text.
        final builder = ScriptedClientBuilder();
        builder.respond(
          method: 'GET',
          pathPattern: '/api',
          statusCode: 200,
          body: 'token=abc123',
        );

        final config = _FakeConfig();
        final tokens = _FakeTokenProvider();
        final client = PenguinApiClient(
          config: config,
          tokens: tokens,
          inner: builder.build(),
        );

        final result = await client.get(
          '/api/test',
          decode: (json) => int.parse(json as String),
        );

        expect(result.isOk, isFalse);
        final failure = result.fold((ok) => null, (err) => err);
        expect(failure, isA<UnknownFailure>());
        expect(failure!.message, isNot(contains('abc123')));
        expect(failure.message, contains('FormatException'));
      },
    );
  });

  group('apiClientProvider', () {
    test('throws UnimplementedError until an app overrides it', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(apiClientProvider),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.exception,
            'exception',
            isA<UnimplementedError>(),
          ),
        ),
      );
    });
  });
}

class _FakeConfig extends AppConfig {
  _FakeConfig()
    : super(
        productKey: 'test',
        appVersion: '1.0.0',
        environment: PenguinEnvironment.prealpha,
        apiBaseUrl: Uri.parse('http://api.example.com'),
        licenseServerUrl: 'https://license.example.com',
      );
}

/// Configurable [TokenProvider] fake: reports [initialToken], and on
/// [refresh] either swaps to [refreshedToken] and emits
/// [AuthEvent.refreshed], or (when [refreshSucceeds] is false) fails and
/// emits [AuthEvent.unauthenticated].
class _FakeTokenProvider implements TokenProvider {
  _FakeTokenProvider({
    String initialToken = 'test-token',
    this.refreshedToken,
    this.refreshSucceeds = true,
  }) : _token = initialToken;

  String _token;
  final String? refreshedToken;
  final bool refreshSucceeds;
  final _events = StreamController<AuthEvent>.broadcast();

  @override
  Future<String?> accessToken() async => _token;

  @override
  Future<bool> refresh() async {
    if (!refreshSucceeds) {
      _events.add(AuthEvent.unauthenticated);
      return false;
    }
    if (refreshedToken != null) {
      _token = refreshedToken!;
    }
    _events.add(AuthEvent.refreshed);
    return true;
  }

  @override
  Stream<AuthEvent> get events => _events.stream;
}
