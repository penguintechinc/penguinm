import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';

void main() {
  test('NetworkFailure carries message and optional cause', () {
    final cause = Exception('timeout');
    final failure = NetworkFailure('no connection', cause: cause);
    expect(failure.message, 'no connection');
    expect(failure.cause, cause);
  });

  test('AuthFailure carries status code and message', () {
    const failure = AuthFailure(401, 'unauthorized');
    expect(failure.statusCode, 401);
    expect(failure.message, 'unauthorized');
  });

  test('ValidationFailure carries field and message', () {
    const failure = ValidationFailure('email', 'invalid format');
    expect(failure.field, 'email');
    expect(failure.message, 'invalid format');
  });

  test('StorageFailure carries message', () {
    const failure = StorageFailure('disk full');
    expect(failure.message, 'disk full');
  });

  test('ServerFailure carries status code and message', () {
    const failure = ServerFailure(500, 'internal error');
    expect(failure.statusCode, 500);
    expect(failure.message, 'internal error');
  });

  test('UnknownFailure preserves cause and stack trace', () {
    final cause = Exception('boom');
    final stack = StackTrace.current;
    final failure = UnknownFailure(cause, stack);
    expect(failure.cause, cause);
    expect(failure.stackTrace, stack);
    expect(failure.message, cause.toString());
  });
}
