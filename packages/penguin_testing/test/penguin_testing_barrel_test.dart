/// Verifies the penguin_testing barrel exports every public fake, fixture,
/// and helper it claims to (spec §4.11) — a compile-time check as much as
/// a runtime one, since a missing export fails at import time.
library;

import 'package:penguin_testing/penguin_testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('barrel exports every fake, fixture set, and helper', () {
    expect(FakeClock(), isNotNull);
    expect(FakeTokenProvider(), isNotNull);
    expect(FakeAuthBackend(), isNotNull);
    expect(FakeFlagSource(), isNotNull);
    expect(FakeLicenseSource(), isNotNull);
    expect(InMemoryFlagCache(), isNotNull);
    expect(InMemoryTelemetryExporter(), isNotNull);
    expect(FakeConnectivityMonitor(), isNotNull);
    expect(InMemoryOfflineStore(), isNotNull);
    expect(FakeUpdateChecker(), isNotNull);
    expect(ScriptedHttpClient(), isNotNull);
    expect(
      OtlpSinkClient(baseUrl: Uri.parse('http://127.0.0.1:4318')),
      isNotNull,
    );

    expect(userFixtures, hasLength(4));
    expect(springboardItemFixtures, hasLength(4));
    expect(clientVersionFixtures, hasLength(4));
    expect(communityFixtures, hasLength(4));
    expect(memberFixtures, hasLength(4));
    expect(chatMessageFixtures, hasLength(4));
  });
}
