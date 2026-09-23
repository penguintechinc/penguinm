import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_api/src/failure_mapper.dart';

void main() {
  group('mapFailure', () {
    test('maps 401 to AuthFailure', () {
      final response = _FakeResponse(401);
      final failure = mapFailure(Exception('Unauthorized'), response: response);

      expect(failure, isA<AuthFailure>());
      expect((failure as AuthFailure).statusCode, equals(401));
    });

    test('maps 403 to AuthFailure', () {
      final response = _FakeResponse(403);
      final failure = mapFailure(Exception('Forbidden'), response: response);

      expect(failure, isA<AuthFailure>());
      expect((failure as AuthFailure).statusCode, equals(403));
    });

    test('maps 5xx to ServerFailure', () {
      for (final status in [500, 502, 503, 504]) {
        final response = _FakeResponse(status);
        final failure = mapFailure(
          Exception('Server error'),
          response: response,
        );

        expect(
          failure,
          isA<ServerFailure>(),
          reason: 'Status $status should map to ServerFailure',
        );
        expect((failure as ServerFailure).statusCode, equals(status));
      }
    });

    test('maps ClientException to NetworkFailure', () {
      final error = http.ClientException('Network error');
      final failure = mapFailure(error);

      expect(failure, isA<NetworkFailure>());
      expect((failure as NetworkFailure).cause, same(error));
    });

    test('maps TimeoutException to NetworkFailure', () {
      final error = TimeoutException('Timeout');
      final failure = mapFailure(error);

      expect(failure, isA<NetworkFailure>());
    });

    test('maps SocketException to NetworkFailure', () {
      final error = SocketException('Socket error');
      final failure = mapFailure(error);

      expect(failure, isA<NetworkFailure>());
    });

    test(
      'maps non-auth 4xx statuses to ServerFailure, preserving the exact code',
      () {
        // penguin_offline's SyncQueue depends on the exact status surviving
        // here to decide retry (408/429) vs. dead-letter (400/409/422).
        for (final status in [400, 408, 409, 422, 429]) {
          final response = _FakeResponse(status);
          final failure = mapFailure(
            Exception('Client error'),
            response: response,
          );

          expect(
            failure,
            isA<ServerFailure>(),
            reason: 'Status $status should map to ServerFailure',
          );
          expect((failure as ServerFailure).statusCode, equals(status));
        }
      },
    );

    test('maps unknown error to UnknownFailure', () {
      final error = Exception('Unknown error');
      final failure = mapFailure(error);

      expect(failure, isA<UnknownFailure>());
      expect((failure as UnknownFailure).cause, same(error));
    });

    test('preserves message from response', () {
      final response = _FakeResponse(500);
      final failure = mapFailure(
        Exception('Custom message'),
        response: response,
      );

      expect((failure as ServerFailure).message, contains('500'));
    });
  });
}

class _FakeResponse extends http.BaseResponse {
  _FakeResponse(super.statusCode) : super(contentLength: 0, headers: const {});
}
