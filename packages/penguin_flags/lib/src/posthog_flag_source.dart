import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:penguin_core/penguin_core.dart';
import 'flag_source.dart';

/// [FlagSource] backed by self-hosted PostHog's `/decide` endpoint on
/// `license.penguintech.io`. Uses its own [http.Client] (never a shared
/// authenticated client) since the PostHog project key is a public,
/// write-only token, not a product credential.
class PostHogFlagSource implements FlagSource {
  /// Creates a PostHog flag source targeting [host] with the given public
  /// [projectKey]; pass a fake [client] in tests.
  PostHogFlagSource({
    required this._host,
    required this._projectKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri _host;
  final String _projectKey;
  final http.Client _client;

  @override
  Future<Result<Map<String, Object?>>> fetch({
    required String distinctId,
    Map<String, String> properties = const {},
  }) async {
    try {
      final url = _host.replace(path: '/decide', queryParameters: {'v': '3'});

      final body = jsonEncode({
        'api_key': _projectKey,
        'distinct_id': distinctId,
        'person_properties': properties,
      });

      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = body;

      final response = await _client
          .send(request)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('PostHog request timeout'),
          );

      if (response.statusCode != 200) {
        return Result.err(
          ServerFailure(
            response.statusCode,
            'PostHog returned ${response.statusCode}',
          ),
        );
      }

      final decoded =
          jsonDecode(await response.stream.bytesToString())
              as Map<String, Object?>;
      final flags = (decoded['featureFlags'] as Map<String, Object?>?) ?? {};

      return Result.ok(flags);
    } on Exception catch (e) {
      return Result.err(NetworkFailure(e.toString()));
    } on TypeError catch (e) {
      // Malformed/unexpected-shape JSON (e.g. a non-map response body or a
      // 'featureFlags' field of the wrong type) throws a TypeError from the
      // `as` casts above rather than an Exception; map it to Result.err the
      // same way so a bad payload never escapes as an unhandled error.
      return Result.err(NetworkFailure('Malformed PostHog response: $e'));
    }
  }
}
