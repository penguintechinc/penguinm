import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:penguin_core/penguin_core.dart';
import 'license_entitlement.dart';
import 'license_source.dart';

/// [LicenseSource] backed by the PenguinTech license server's
/// `POST /api/v2/validate` endpoint (see the `integrating-license-server`
/// skill). Returns [Result.err] rather than throwing on any network,
/// server, or malformed-response failure, so callers can fall back to a
/// cached tier without a crash.
class PenguinLicenseSource implements LicenseSource {
  /// Creates a PenguinTech license source targeting [serverUrl]; pass a
  /// fake [client] in tests.
  PenguinLicenseSource({required this._serverUrl, http.Client? client})
    : _client = client ?? http.Client();

  final Uri _serverUrl;
  final http.Client _client;

  @override
  Future<Result<LicenseEntitlement>> fetch({
    required String productKey,
    String? licenseKey,
    required String installationId,
  }) async {
    try {
      final url = _serverUrl.replace(path: '/api/v2/validate');

      final body = jsonEncode({
        'productKey': productKey,
        if (licenseKey case final String key) 'licenseKey': key,
        'installationId': installationId,
      });

      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = body;

      final response = await _client
          .send(request)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('License server request timeout'),
          );

      if (response.statusCode != 200) {
        return Result.err(
          ServerFailure(
            response.statusCode,
            'License server returned ${response.statusCode}',
          ),
        );
      }

      final decoded =
          jsonDecode(await response.stream.bytesToString())
              as Map<String, Object?>;
      final entitlement = LicenseEntitlement.fromJson(decoded);

      return Result.ok(entitlement);
    } on Exception catch (e) {
      return Result.err(NetworkFailure(e.toString()));
    } on TypeError catch (e) {
      // Malformed/unexpected-shape JSON (e.g. a non-map response body)
      // throws a TypeError from the `as` cast above rather than an
      // Exception; map it to Result.err the same way so a bad payload
      // never escapes as an unhandled error.
      return Result.err(NetworkFailure('Malformed license response: $e'));
    }
  }
}
