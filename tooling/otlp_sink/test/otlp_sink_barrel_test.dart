// The barrel currently exports nothing (transitional placeholder); a later
// task populates it and this ignore is removed.
// ignore_for_file: unused_import
/// Transitional placeholder verifying the otlp_sink barrel imports cleanly.
library;

import 'package:otlp_sink/otlp_sink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('barrel imports', () {
    expect(true, isTrue);
  });
}
