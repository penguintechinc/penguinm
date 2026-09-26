import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/license_state.dart';
import 'device_id.dart';
import 'gazer_log.dart';

/// Persists the most recent [LicenseState] as JSON in shared_preferences.
class LicenseCache {
  LicenseCache(this._prefs);

  final SharedPreferencesAsync _prefs;

  static const String _kKey = 'gazer.license.state';

  /// Returns the cached state, or `null` if nothing has ever been written.
  Future<LicenseState?> read() async {
    final json = await _prefs.getString(_kKey);
    if (json == null) return null;
    return LicenseState.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Overwrites the cached state with [s].
  Future<void> write(LicenseState s) async {
    await _prefs.setString(_kKey, jsonEncode(s.toJson()));
  }
}

/// App-local client for the PenguinTech license server's Gazer-facing API
/// (temporary bridge pending promotion into `flutter_libs` — see the
/// design spec's "TEMPORARY BRIDGE" decision).
///
/// Never throws: every failure path degrades to a cached or `unknown`
/// [LicenseState] instead of propagating an exception to the caller.
class LicenseClient {
  LicenseClient({
    required this._client,
    required this._cache,
    required this._deviceIdProvider,
    required this._now,
    this.baseUrl = kLicenseBaseUrl,
  });

  final http.Client _client;
  final LicenseCache _cache;
  final DeviceIdProvider _deviceIdProvider;
  final DateTime Function() _now;

  /// Base URL for `/validate`, `/features`, `/keepalive`.
  final String baseUrl;

  static const Map<String, String> _jsonHeaders = <String, String>{
    'content-type': 'application/json',
  };

  /// Validates this install and fetches its feature flags.
  ///
  /// Success -> `valid` with fresh flags and `lastFetched = now()`.
  /// Network error with a cache fetched less than [kLicenseGracePeriod] ago
  /// -> `gracePeriod` with the cached flags. Network error with a stale or
  /// absent cache -> `unknown`. A 4xx response -> `invalid`. A `/validate`
  /// body that does not say `valid: true` -> `invalid`, without fetching
  /// features. Any other failure — including a malformed features
  /// response, a device-id provider failure, or a corrupted cache — is
  /// swallowed and degrades to a cached or `unknown` result. This method
  /// never throws.
  ///
  /// Graceful degradation to cached values is for *network* failure only:
  /// an answer that says the licence is not valid is an answer, and
  /// falling back to a cached "valid" would make the server's verdict
  /// unenforceable.
  Future<LicenseState> validateAndFetchFlags() async {
    String? deviceId;
    try {
      deviceId = await _deviceIdProvider.deviceId();
    } catch (_) {
      deviceId = null;
    }

    LicenseState? cached;
    try {
      cached = await _cache.read();
    } catch (_) {
      // A corrupted cache is treated exactly like no cache at all.
      cached = null;
    }

    if (deviceId == null) {
      // No device id available: never call the server without a real one
      // -- degrade exactly like a network failure, using the cached device
      // id (if any) only to shape the returned LicenseState, never sent
      // anywhere.
      return _offlineFallback(cached, cached?.deviceId ?? '');
    }

    try {
      final validateResponse = await _client
          .post(
            Uri.parse('$baseUrl/validate'),
            headers: _jsonHeaders,
            body: jsonEncode(_payload(deviceId)),
          )
          .timeout(kHttpTimeout);
      final statusCode = validateResponse.statusCode;
      if (statusCode >= 400 && statusCode < 500) {
        return await _invalid(cached, deviceId);
      }
      if (statusCode < 200 || statusCode >= 300) {
        // A non-2xx, non-4xx response (e.g. 5xx) is a transport-level
        // failure, not an answer -- never reaches body validation.
        return _offlineFallback(cached, deviceId);
      }
      if (!_isValidated(_decodeBody(validateResponse.body))) {
        return await _invalid(cached, deviceId);
      }
      final response = await _client
          .post(
            Uri.parse('$baseUrl/features'),
            headers: _jsonHeaders,
            body: jsonEncode(_payload(deviceId)),
          )
          .timeout(kHttpTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _offlineFallback(cached, deviceId);
      }
      final rawFlags = Map<String, dynamic>.from(
        (_decodeBody(response.body) as Map<String, dynamic>)['features'] as Map,
      );
      final flags = rawFlags.map((key, value) => MapEntry(key, value as bool));
      final state = LicenseState(
        status: LicenseStatus.valid,
        flags: flags,
        lastFetched: _now(),
        deviceId: deviceId,
      );
      await _cache.write(state);
      _logFetchOutcome(state, deviceId);
      return state;
    } catch (_) {
      return _offlineFallback(cached, deviceId);
    }
  }

  /// Decodes a raw response body as JSON, returning `null` on any decode
  /// failure rather than throwing -- an unparseable body is not evidence
  /// of entitlement, but it must not crash the never-throw contract either.
  static Object? _decodeBody(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  /// Whether a `/validate` response body affirms the licence.
  ///
  /// Only an explicit boolean `valid: true` counts. A body that is not a
  /// JSON object, or whose `valid` field is missing or not a bool, is
  /// treated as *not* validated: an unreadable answer is not evidence of
  /// entitlement.
  static bool _isValidated(Object? body) {
    if (body is! Map) return false;
    final Object? valid = body['valid'];
    return valid is bool && valid;
  }

  /// Builds, caches, logs, and returns the `invalid` result.
  ///
  /// `lastFetched` is deliberately left as whatever it was before this
  /// call (not reset to `now()`), so [_offlineFallback]'s grace-period
  /// math still grades off the last *successful* fetch rather than off
  /// this rejection.
  Future<LicenseState> _invalid(LicenseState? cached, String deviceId) async {
    final invalid = LicenseState(
      status: LicenseStatus.invalid,
      flags: cached?.flags ?? const {},
      lastFetched: cached?.lastFetched,
      deviceId: deviceId,
    );
    await _cache.write(invalid);
    _logFetchOutcome(invalid, deviceId);
    return invalid;
  }

  /// Logs the fetch outcome (status, flag count) — never the device id
  /// in full; [GazerLog.maskSecret] shows only its last 4 characters.
  void _logFetchOutcome(LicenseState state, String deviceId) {
    GazerLog.info('license.fetch', <String, Object?>{
      'status': state.status.name,
      'flagCount': state.flags.length,
      'deviceId': GazerLog.maskSecret(deviceId),
    });
  }

  /// Fire-and-forget keepalive ping; failures — including a device-id
  /// provider failure — are swallowed silently.
  Future<void> keepalive() async {
    try {
      final deviceId = await _deviceIdProvider.deviceId();
      unawaited(_sendKeepalive(deviceId));
    } catch (_) {
      // No device id available -- nothing to keep alive.
    }
  }

  /// Wrapped in its own `async` body so that a synchronous throw is caught
  /// the same way as an asynchronous one.
  Future<void> _sendKeepalive(String deviceId) async {
    try {
      await _client
          .post(
            Uri.parse('$baseUrl/keepalive'),
            headers: _jsonHeaders,
            body: jsonEncode(_payload(deviceId)),
          )
          .timeout(kHttpTimeout);
    } catch (_) {
      // Fire-and-forget: keepalive failures are never surfaced to the caller.
    }
  }

  /// Degrades to a cached result when the server can't be reached (or no
  /// device id could be resolved): `gracePeriod` with the cached flags if
  /// [cached] was fetched strictly less than [kLicenseGracePeriod] ago,
  /// otherwise `unknown` with whatever flags [cached] holds (or empty, if
  /// there is no usable cache at all).
  LicenseState _offlineFallback(LicenseState? cached, String deviceId) {
    final LicenseState state;
    if (cached?.lastFetched != null &&
        _now().difference(cached!.lastFetched!) < kLicenseGracePeriod) {
      state = cached.copyWith(status: LicenseStatus.gracePeriod);
    } else {
      state = LicenseState(
        status: LicenseStatus.unknown,
        flags: cached?.flags ?? const {},
        lastFetched: cached?.lastFetched,
        deviceId: deviceId,
      );
    }
    _logFetchOutcome(state, deviceId);
    return state;
  }

  /// Builds the request body sent to `/validate`, `/features`, and
  /// `/keepalive` — the resolved [deviceId] plus fixed product/component
  /// identifiers identifying this app to the license server.
  Map<String, String> _payload(String deviceId) => {
    'device_id': deviceId,
    'product': 'waddlebot',
    'component': 'gazer',
  };
}
