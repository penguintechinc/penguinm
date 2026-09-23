import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:penguin_core/penguin_core.dart';
import 'request_replay.dart';

/// Middleware that adds an `Authorization: Bearer <token>` header to every
/// request and handles token refresh + replay on 401: if the server returns
/// 401, the client calls [TokenProvider.refresh()] once, then replays the
/// request with the new token. On refresh failure, emits
/// [AuthEvent.unauthenticated]. Concurrent 401s are de-duplicated: only the
/// first triggers [TokenProvider.refresh]; every other concurrent 401 awaits
/// that same in-flight call instead of starting its own (refresh tokens are
/// typically single-use, so calling `refresh()` twice at once would race).
class AuthClient extends http.BaseClient {
  /// Creates an auth middleware wrapping [inner]. `inner`/`tokens` are
  /// initializing formals bound to private fields (`_inner`/`_tokens`) —
  /// Dart exposes the underscore-stripped name as the external label, so
  /// the public constructor call site (`AuthClient(inner: ..., tokens:
  /// ...)`) is unchanged.
  AuthClient({required this._inner, required this._tokens});

  final http.Client _inner;
  final TokenProvider _tokens;

  /// The in-flight [TokenProvider.refresh] call, shared by every concurrent
  /// 401 until it completes — `null` when no refresh is in progress.
  Future<bool>? _refreshInFlight;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Add token to the initial request
    request = await _addToken(request);

    // Send the request
    var response = await _inner.send(request);

    // On 401, try to refresh and replay
    if (response.statusCode == 401) {
      final refreshed = await _refresh();
      if (!refreshed) {
        // Refresh failed — return the 401 response (unauthenticated was emitted by refresh())
        return response;
      }

      // Refresh succeeded — replay the original request with the new token
      var replayRequest = copyRequestForReplay(request);
      replayRequest = await _addToken(replayRequest);
      response = await _inner.send(replayRequest);
    }

    return response;
  }

  /// Runs [TokenProvider.refresh] at most once per outage: the first 401 to
  /// arrive starts it and stores the in-flight future; every concurrent 401
  /// awaits that same future instead of calling `refresh()` again.
  Future<bool> _refresh() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _tokens.refresh();
    _refreshInFlight = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_refreshInFlight, future)) {
          _refreshInFlight = null;
        }
      }),
    );
    return future;
  }

  /// Adds the current access token to the request.
  Future<http.BaseRequest> _addToken(http.BaseRequest request) async {
    final token = await _tokens.accessToken();
    if (token != null) {
      request.headers['authorization'] = 'Bearer $token';
    }
    return request;
  }
}
