import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:penguin_testing/penguin_testing.dart';

void main() {
  group('ScriptedHttpClient', () {
    test('returns the queued response for a request', () async {
      final client = ScriptedHttpClient();
      client.queueResponse(statusCode: 201, body: '{"ok":true}');

      final response = await client.get(Uri.parse('https://api.example.com/x'));

      expect(response.statusCode, 201);
      expect(response.body, '{"ok":true}');
      expect(response.headers['content-type'], 'application/json');
    });

    test('records every request received', () async {
      final client = ScriptedHttpClient();
      client
        ..queueResponse()
        ..queueResponse();

      await client.get(Uri.parse('https://api.example.com/a'));
      await client.post(Uri.parse('https://api.example.com/b'), body: 'hi');

      expect(client.seenRequests, hasLength(2));
      expect(client.seenRequests[0].method, 'GET');
      expect(client.seenRequests[0].url.path, '/a');
      expect(client.seenRequests[1].method, 'POST');
      expect(client.seenRequests[1].body, 'hi');
    });

    test('drains queued responses in FIFO order', () async {
      final client = ScriptedHttpClient();
      client
        ..queueResponse(statusCode: 200, body: 'first')
        ..queueResponse(statusCode: 500, body: 'second');

      final first = await client.get(Uri.parse('https://api.example.com/x'));
      final second = await client.get(Uri.parse('https://api.example.com/x'));

      expect(first.statusCode, 200);
      expect(first.body, 'first');
      expect(second.statusCode, 500);
      expect(second.body, 'second');
    });

    test('queueError makes the next send rethrow', () async {
      final client = ScriptedHttpClient();
      client.queueError(http.ClientException('boom'));

      await expectLater(
        () => client.get(Uri.parse('https://api.example.com/x')),
        throwsA(isA<http.ClientException>()),
      );
    });

    test('throws a StateError when no response is queued', () async {
      final client = ScriptedHttpClient();
      await expectLater(
        () => client.get(Uri.parse('https://api.example.com/x')),
        throwsStateError,
      );
    });

    test(
      'a queued delay is driven through the injected delayFn, never a real sleep',
      () async {
        final recordedDelays = <Duration>[];
        final client = ScriptedHttpClient(
          delayFn: (duration) async {
            recordedDelays.add(duration);
            // Deliberately does not await a real Future.delayed — proves the
            // client never forces a real sleep for a scripted delay.
          },
        );
        client.queueResponse(
          statusCode: 200,
          body: 'slow',
          delay: const Duration(seconds: 30),
        );

        final stopwatch = Stopwatch()..start();
        final response = await client.get(
          Uri.parse('https://api.example.com/x'),
        );
        stopwatch.stop();

        expect(response.body, 'slow');
        expect(recordedDelays, [const Duration(seconds: 30)]);
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
      },
    );

    test('sending the same http.Request twice throws a StateError, matching a '
        'real client (MockClient finalizes the request on send)', () async {
      final client = ScriptedHttpClient();
      client
        ..queueResponse()
        ..queueResponse();

      final request = http.Request(
        'GET',
        Uri.parse('https://api.example.com/x'),
      );

      // First send finalizes the request and succeeds.
      await client.send(request);

      // Resending the same (already-finalized) request object must fail
      // exactly as it would against a real http.Client — this is the
      // regression coverage for the retry-middleware bug where a
      // hand-rolled double silently accepted a re-sent finalized request.
      await expectLater(() => client.send(request), throwsStateError);
    });

    test('the default delayFn performs a real (short) delay', () async {
      final client = ScriptedHttpClient();
      client.queueResponse(
        statusCode: 200,
        body: 'ok',
        delay: const Duration(milliseconds: 1),
      );

      final response = await client.get(Uri.parse('https://api.example.com/x'));

      expect(response.body, 'ok');
    });

    test('close does not throw', () {
      final client = ScriptedHttpClient();
      expect(client.close, returnsNormally);
    });
  });
}
