import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:penguin_flags/src/license_tier.dart';
import 'package:penguin_flags/src/penguin_license_source.dart';

void main() {
  group('PenguinLicenseSource', () {
    test('parses tier and expiry', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), contains('/api/v2/validate'));
        expect(request.method, 'POST');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['productKey'], 'waddlebot');
        return http.Response(
          jsonEncode({
            'tier': 'professional',
            'expiresAt': '2026-12-31T23:59:59Z',
            'features': <String, Object?>{'whitelabelling': true},
          }),
          200,
        );
      });

      final source = PenguinLicenseSource(
        serverUrl: Uri.parse('https://license.example.com'),
        client: client,
      );

      final result = await source.fetch(
        productKey: 'waddlebot',
        installationId: 'inst-123',
      );

      expect(result.isOk, isTrue);
      final ent = result.valueOrNull!;
      expect(ent.tier, LicenseTier.professional);
      expect(ent.expiresAt, isNotNull);
      expect(ent.features['whitelabelling'], isTrue);
    });

    test('parses the license_entitlement.json fixture', () async {
      final fixture = File(
        'test/fixtures/license_entitlement.json',
      ).readAsStringSync();

      final client = MockClient((request) async {
        return http.Response(fixture, 200);
      });

      final source = PenguinLicenseSource(
        serverUrl: Uri.parse('https://license.example.com'),
        client: client,
      );

      final result = await source.fetch(
        productKey: 'penguinm',
        installationId: 'inst-123',
      );

      expect(result.isOk, isTrue);
      final ent = result.valueOrNull!;
      expect(ent.tier, LicenseTier.professional);
      expect(ent.expiresAt, isNotNull);
      expect(ent.features['whitelabelling'], isTrue);
      expect(ent.features['google_oauth'], isTrue);
    });

    test('parses free tier', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'tier': 'free', 'features': <String, Object?>{}}),
          200,
        );
      });

      final source = PenguinLicenseSource(
        serverUrl: Uri.parse('https://license.example.com'),
        client: client,
      );

      final result = await source.fetch(
        productKey: 'waddlebot',
        installationId: 'inst-123',
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.tier, LicenseTier.free);
    });

    test('parses enterprise tier', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tier': 'enterprise',
            'features': <String, Object?>{'saml': true, 'audit_logs': true},
          }),
          200,
        );
      });

      final source = PenguinLicenseSource(
        serverUrl: Uri.parse('https://license.example.com'),
        client: client,
      );

      final result = await source.fetch(
        productKey: 'waddlebot',
        installationId: 'inst-123',
      );

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.tier, LicenseTier.enterprise);
    });

    test('includes licenseKey when provided', () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['licenseKey'], 'PENG-TEST-KEY');
        return http.Response(
          jsonEncode({'tier': 'free', 'features': <String, Object?>{}}),
          200,
        );
      });

      final source = PenguinLicenseSource(
        serverUrl: Uri.parse('https://license.example.com'),
        client: client,
      );

      await source.fetch(
        productKey: 'waddlebot',
        licenseKey: 'PENG-TEST-KEY',
        installationId: 'inst-123',
      );
    });

    test('returns error on connection failure', () async {
      final client = MockClient((request) async {
        throw Exception('Connection failed');
      });

      final source = PenguinLicenseSource(
        serverUrl: Uri.parse('https://license.example.com'),
        client: client,
      );

      final result = await source.fetch(
        productKey: 'waddlebot',
        installationId: 'inst-123',
      );

      expect(result.isOk, isFalse);
      expect(result.valueOrNull, isNull);
    });

    test('returns error on non-200 response', () async {
      final client = MockClient((request) async {
        return http.Response('{}', 500);
      });

      final source = PenguinLicenseSource(
        serverUrl: Uri.parse('https://license.example.com'),
        client: client,
      );

      final result = await source.fetch(
        productKey: 'waddlebot',
        installationId: 'inst-123',
      );

      expect(result.isOk, isFalse);
      expect(result.valueOrNull, isNull);
    });

    test('returns an error result on malformed JSON shape', () async {
      final client = MockClient((request) async {
        // 'features' is a string, not a map: the `as Map<...>?` cast in
        // LicenseEntitlement.fromJson throws a TypeError, which must be
        // caught and turned into Result.err rather than escaping.
        return http.Response(
          jsonEncode({'tier': 'free', 'features': 'not-a-map'}),
          200,
        );
      });

      final source = PenguinLicenseSource(
        serverUrl: Uri.parse('https://license.example.com'),
        client: client,
      );

      final result = await source.fetch(
        productKey: 'waddlebot',
        installationId: 'inst-123',
      );

      expect(result.isOk, isFalse);
    });
  });
}
