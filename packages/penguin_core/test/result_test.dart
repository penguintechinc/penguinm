import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';

void main() {
  test('Result fold ok/err', () {
    const ok = Result<int>.ok(42);
    const err = Result<int>.err(StorageFailure('disk full'));

    expect(
      ok.fold((v) => 'value:$v', (f) => 'failure:${f.message}'),
      'value:42',
    );
    expect(
      err.fold((v) => 'value:$v', (f) => 'failure:${f.message}'),
      'failure:disk full',
    );
  });

  test('Result.isOk and valueOrNull reflect success/failure', () {
    const ok = Result<int>.ok(1);
    const err = Result<int>.err(StorageFailure('x'));

    expect(ok.isOk, isTrue);
    expect(ok.valueOrNull, 1);
    expect(err.isOk, isFalse);
    expect(err.valueOrNull, isNull);
  });

  test('Result.map transforms ok and passes err through unchanged', () {
    const ok = Result<int>.ok(2);
    const err = Result<int>.err(StorageFailure('x'));

    expect(ok.map((v) => v * 2).valueOrNull, 4);
    final mappedErr = err.map((v) => v * 2);
    expect(mappedErr.isOk, isFalse);
    expect(mappedErr.fold((v) => 'ok', (f) => f.message), 'x');
  });
}
