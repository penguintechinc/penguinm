/// Verifies that the penguin_update barrel exports all public APIs.
library;

import 'package:penguin_update/penguin_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('barrel exports UpdateStatus', () {
    expect(UpToDate, isNotNull);
    expect(UpdateAvailable, isNotNull);
    expect(UpdateRequired, isNotNull);
    expect(Unknown, isNotNull);
  });

  test('barrel exports UpdateChecker', () {
    expect(UpdateChecker, isNotNull);
  });

  test('barrel exports UpdatePrompt', () {
    expect(UpdatePrompt, isNotNull);
  });

  test('barrel exports storeUrlFor', () {
    expect(storeUrlFor, isNotNull);
  });

  test('barrel exports providers', () {
    expect(updateStatusProvider, isNotNull);
    expect(updateCheckerProvider, isNotNull);
  });
}
