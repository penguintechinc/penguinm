import 'dart:convert';
import 'package:flutter_libs/flutter_libs.dart';
import 'package:http/http.dart' as http;
import 'package:penguin_core/penguin_core.dart';
import 'auth_backend.dart';
import 'auth_config.dart';
import 'jwt_claims.dart';
import 'login_request.dart';
import 'session.dart';

/// Transitional in-app password login backend. Posts email/password/mfa_code
/// via HTTP and accepts either `{access_token, refresh_token, expires_in}`
/// or flutter_libs `LoginResponse` JSON.
class PasswordAuthBackend implements AuthBackend {
  /// Creates a password login backend.
  PasswordAuthBackend(
    this._config, {
    required this.apiBaseUrl,
    http.Client? client,
    Clock? clock,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? const SystemClock() {
    if (_config case final PasswordAuthConfig cfg) {
      _passwordConfig = cfg;
    } else {
      throw ArgumentError('PasswordAuthBackend requires AuthConfig.password()');
    }
  }

  final AuthConfig _config;

  /// The product's API base URL — login/refresh/logout paths are resolved
  /// relative to this.
  final Uri apiBaseUrl;
  final http.Client _client;
  final Clock _clock;
  late final PasswordAuthConfig _passwordConfig;

  @override
  Future<Result<Session>> login(LoginRequest request) async {
    try {
      // Handle different request types.
      String? email, password, mfaCode;

      if (request case Password(
        email: final e,
        password: final p,
        mfaCode: final m,
      )) {
        email = e;
        password = p;
        mfaCode = m;
      } else if (request case FromLoginResponse(
        response: final LoginResponse response,
      )) {
        // Extract from LoginPageBuilder response.
        if (!response.success || response.token == null) {
          return Result.err(
            AuthFailure(null, response.error ?? 'Login failed'),
          );
        }

        // Build a session directly from the response.
        return _sessionFromLoginResponse(response);
      } else {
        return Result.err(AuthFailure(null, 'Invalid login request type'));
      }

      // Prepare login payload.
      final payload = <String, dynamic>{
        'email': email,
        'password': password,
        'mfa_code': ?mfaCode,
      };

      // POST to login endpoint.
      final url = apiBaseUrl.replace(path: _passwordConfig.loginPath);
      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return Result.err(
          ServerFailure(
            response.statusCode,
            'Login failed with status ${response.statusCode}',
          ),
        );
      }

      // Parse response: could be standard or LoginResponse format.
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // Try standard OAuth2 response first.
      if (json.containsKey('access_token')) {
        return _sessionFromStandardResponse(json);
      }

      // Try LoginResponse format.
      if (json.containsKey('success')) {
        try {
          final loginResponse = LoginResponse.fromJson(json);
          return _sessionFromLoginResponse(loginResponse);
        } catch (e) {
          return Result.err(UnknownFailure(e, StackTrace.current));
        }
      }

      return Result.err(AuthFailure(null, 'Unexpected login response format'));
    } catch (e, st) {
      return Result.err(UnknownFailure(e, st));
    }
  }

  @override
  Future<Result<Session>> refresh(Session session) async {
    try {
      if (session.refreshToken == null) {
        return Result.err(AuthFailure(null, 'No refresh token available'));
      }

      final url = apiBaseUrl.replace(path: _passwordConfig.refreshPath);
      final payload = {'refresh_token': session.refreshToken};

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return Result.err(
          ServerFailure(
            response.statusCode,
            'Refresh failed with status ${response.statusCode}',
          ),
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return _sessionFromStandardResponse(json);
    } catch (e, st) {
      return Result.err(UnknownFailure(e, st));
    }
  }

  @override
  Future<Result<void>> logout(Session session) async {
    try {
      final url = apiBaseUrl.replace(path: _passwordConfig.logoutPath);
      final payload = {'access_token': session.accessToken};

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Result.err(
          ServerFailure(
            response.statusCode,
            'Logout failed with status ${response.statusCode}',
          ),
        );
      }

      return const Result.ok(null);
    } catch (e, st) {
      return Result.err(UnknownFailure(e, st));
    }
  }

  /// Creates a session from a standard OAuth2 response.
  Result<Session> _sessionFromStandardResponse(Map<String, dynamic> json) {
    try {
      final accessToken = json['access_token'] as String?;
      if (accessToken == null) {
        return Result.err(AuthFailure(null, 'No access token in response'));
      }

      final claims = JwtClaims.decode(accessToken);
      final expiresIn = json['expires_in'] as int? ?? 3600;
      final expiresAt = _clock.now().add(Duration(seconds: expiresIn));

      final session = Session(
        accessToken: accessToken,
        refreshToken: json['refresh_token'] as String?,
        expiresAt: expiresAt,
        claims: claims,
      );

      return Result.ok(session);
    } catch (e, st) {
      return Result.err(UnknownFailure(e, st));
    }
  }

  /// Creates a session from a LoginResponse object.
  Result<Session> _sessionFromLoginResponse(LoginResponse response) {
    try {
      if (!response.success || response.token == null) {
        return Result.err(AuthFailure(null, response.error ?? 'Login failed'));
      }

      final claims = JwtClaims.decode(response.token!);
      // LoginResponse doesn't include expires_in, so assume 1 hour.
      final expiresAt = _clock.now().add(const Duration(hours: 1));

      final session = Session(
        accessToken: response.token!,
        refreshToken: response.refreshToken,
        expiresAt: expiresAt,
        claims: claims,
      );

      return Result.ok(session);
    } catch (e, st) {
      return Result.err(UnknownFailure(e, st));
    }
  }
}
