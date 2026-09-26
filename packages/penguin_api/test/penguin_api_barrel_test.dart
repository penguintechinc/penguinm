/// Verifies the `penguin_api` barrel actually exports the package's public
/// surface (not just that it imports cleanly) — a regression test for a
/// barrel that silently stops re-exporting a symbol.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/penguin_api.dart';

void main() {
  test('barrel exports RetryPolicy with its documented defaults', () {
    const policy = RetryPolicy();

    expect(policy.maxAttempts, equals(3));
    expect(policy, isNotNull);
  });
}
