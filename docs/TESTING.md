# Testing — Strategy, Mock Data, Gates, Coverage

**90%+ line coverage per package required.** All tests must pass before merge. Every commit must pass the telemetry smoke gate.

## Test Layers

| Layer | What | Where | Gate | Tools |
|---|---|---|---|---|
| Unit | Pure Dart: Result, JwtClaims, RetryPolicy, LogSanitizer, OTLP encoding, semver | `test/` (not `integration_test/`) | ≥90% | `flutter test` |
| Widget | UI: screens, widgets, responsive layouts, form factors | `test/goldens/` (golden tests) | ≥90% + visual | `flutter test` |
| Integration | Critical flows: login → home, offline write → reconnect → sync | `integration_test/` | pass/fail | `flutter test integration_test/` |
| Golden | `ResponsiveScaffold` ×3 sizes, `ConnectivityBanner`, `UpdatePrompt` | `test/goldens/` | visual match | `flutter test` + `--update-goldens` |
| Contract | API mocks: `OtlpHttpJsonExporter` vs `tooling/otlp_sink`, PostHog flags, license server | `test/` (fixtures) | status code | `flutter test` |
| Telemetry | Reference app bootstrap + OTel emission | `tooling/otlp_sink` (local OTLP receiver) | ≥1 log, ≥1 metric, ≥1 histogram | `make telemetry-validate.sh` |
| Platform | Native modules (if any) | `platform/android/*/android/src/test/`, iOS `*Tests.swift` | pass/fail | JUnit 4, XCTest |
| Conformance | Logging: ≥1 file scanned, `PenguinLogger` used, zero `print(`/`debugPrint(` | `check-logging.sh` | denominator > 0 | grep |

## Running Tests

```bash
make test-unit        # Unit tests only (test/ directory)
make test             # Unit + widget + coverage (test/ + goldens)
make test-integration # Integration tests (requires Android emulator, API 35)
make coverage         # test + coverage-gate.sh (≥90% per package)
make smoke-test       # bootstrap + analyze + reference tests + telemetry + pins (<2 min)
```

## Coverage Gates

**`make coverage` runs `coverage-gate.sh`** — parses `coverage/lcov.info` per package:

```bash
# Output per package:
# penguin_core: 342/380 90.0%
# penguin_auth: 218/242 90.1%
# penguin_api: 156/173 90.2%

# Aggregate summary:
# Total: 4152/4631 89.7% → FAIL (< 90%)
```

| Condition | Result |
|---|---|
| Any package < 90% | FAIL |
| Any package with LF=0 (no lines found) | FAIL |
| Zero packages scanned | FAIL |
| All packages ≥90% | PASS |

**Stop on failure** — don't commit below 90%.

## Writing Tests

### Unit Test Pattern

```dart
// test/domain/auth/jwt_claims_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_testing/penguin_testing.dart';

void main() {
  group('JwtClaims', () {
    test('decodes valid JWT payload', () {
      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
          '.eyJzdWIiOiJ1c2VyLTEyMyIsImV4cCI6OTk5OTk5OTk5OSwiaWF0IjoxNjMwNzAzMjQwfQ'
          '.sig';

      final claims = JwtClaims.decode(jwt);
      expect(claims.sub, equals('user-123'));
      expect(claims.isExpired(const FakeClock()), isFalse);
    });

    test('isExpired returns true when exp < now', () {
      const jwt = 'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjE2MzA3MDMyNDB9.sig';
      final clock = FakeClock()..setNow(DateTime(2026));

      final claims = JwtClaims.decode(jwt);
      expect(claims.isExpired(clock), isTrue);
    });
  });
}
```

### Widget Test Pattern

```dart
// test/features/springboard/springboard_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_testing/penguin_testing.dart';
import 'package:penguin_reference/manifest.dart';

void main() {
  group('SpringboardScreen', () {
    testWidgets('renders title and items', (tester) async {
      await pumpPenguinApp(tester, manifest);

      expect(find.text('Springboard'), findsOneWidget);
      expect(find.byType(ListTile), findsWidgets);
    });

    testWidgets('navigates to profile on tap', (tester) async {
      await pumpPenguinApp(tester, manifest);

      await tester.tap(find.byIcon(Icons.person));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });
}
```

### Golden Test Pattern

```dart
// test/goldens/responsive_scaffold_golden_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_ui/penguin_ui.dart';
import 'package:penguin_testing/penguin_testing.dart';

void main() {
  group('ResponsiveScaffold goldens', () {
    testWidgets('phone portrait', (tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(390, 844);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveScaffold(
            destinations: [
              NavigationDestinationSpec(
                route: '/home',
                label: 'Home',
                icon: Icons.home,
                selectedIcon: Icons.home_filled,
              ),
            ],
            selectedIndex: 0,
            onSelect: (_) {},
            body: const Center(child: Text('Home')),
          ),
        ),
      );

      await expectLater(
        find.byType(ResponsiveScaffold),
        matchesGoldenFile('goldens/responsive_scaffold_phone.png'),
      );
    });

    testWidgets('tablet landscape', (tester) async {
      tester.binding.window.physicalSizeTestValue = const Size(1280, 800);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      // ... test
    });
  });
}
```

Update goldens with:
```bash
flutter test --update-goldens test/goldens/
```

### Integration Test Pattern

```dart
// integration_test/auth_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:penguin_reference/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth flow', () {
    testWidgets('login → home → logout', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Open login
      expect(find.byType(LoginScreen), findsOneWidget);

      // Fill form (or open browser)
      await tester.tap(find.byType(ContinueButton));
      // ... browser flow mocked or real

      // Verify home screen
      await tester.pumpAndSettle();
      expect(find.byType(SpringboardScreen), findsOneWidget);

      // Logout
      await tester.tap(find.byType(LogoutButton));
      await tester.pumpAndSettle();

      // Back to login
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
```

Run with:
```bash
flutter test integration_test/
# On emulator: flutter test integration_test/ --device-id emulator-5554
```

## Mock Data

**Generators in `penguin_testing`** produce 3–4 items per model (users, flags, version infos, etc.):

```bash
make seed-mock-data
```

Writes to each app's `test/fixtures/` and prints counts:
```
Created 15 fixture files:
  users.json (3 items)
  springboard_items.json (4 items)
  ...
```

Use in tests:

```dart
import 'package:penguin_testing/fixtures/fixtures.dart' as fixtures;

void main() {
  testWidgets('displays user list', (tester) async {
    final users = fixtures.loadUsers(); // [User(...), User(...), User(...)]

    await pumpPenguinApp(tester, manifest, overrides: [
      userRepositoryProvider.overrideWithValue(
        FakeUserRepository()..setUsers(users)
      ),
    ]);

    expect(find.byType(UserListTile), findsNWidgets(3));
  });
}
```

## Telemetry Validation

**Every smoke test asserts OTel emission via local OTLP/HTTP test sink** (`tooling/otlp_sink`):

```bash
make telemetry-validate.sh
```

Procedure:
1. Start `tooling/otlp_sink` on `127.0.0.1:4318`
2. Run `apps/penguin_reference` with `OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318`
3. Capture and count: log records, metric data points, histograms, spans
4. Verify:
   - ≥1 log record received
   - ≥1 metric data point received
   - ≥1 histogram received (load/latency histograms most often missed)
   - ≥1 span received (if inter-service calls are made)
5. Print counts; FAIL on zero

**Example output:**
```
Telemetry validation:
  Logs: 12 records ✓
  Metrics: 8 data points ✓
  Histograms: 3 received ✓
  Spans: 5 received ✓
PASS
```

## Test Utilities (penguin_testing)

### Fakes

```dart
FakeClock()           // Controllable time
FakeTokenProvider()   // Mock token source; setToken(), setRefreshError()
FakeAuthBackend()     // Mock login; pushResult(Result<Session>)
FakeFlagSource()      // Mock PostHog; setFlags(Map)
FakeLicenseSource()   // Mock license server; setTier(LicenseTier)
FakeConnectivityMonitor() // Mock connectivity; setStatus()
FakeUpdateChecker()   // Mock update check; setStatus()
```

### Helpers

```dart
pumpPenguinApp(tester, manifest, {overrides})
  // Pump the entire app with bootstrap; ready for interaction

penguinGolden(name, {size})
  // Golden file helper with standard sizes

OtlpSinkClient.summary()
  // Query telemetry counts from tooling/otlp_sink

ScriptedHttpClient(queue)
  // A MockClient from package:http/testing.dart fed by a queue of scripted responses, recording every request
```

### Fixtures

```dart
fixtures.loadUsers()      // [User(...), ...]
fixtures.loadFlags()      // Map<String, Object?>
fixtures.loadVersionInfos() // [ClientVersionInfo(...), ...]
```

## Logging Conformance

**`check-logging.sh`** asserts:
- ≥1 source file scanned (`lib/` and `test/` directories)
- ≥1 file imports `PenguinLogger` or uses the logging package
- Zero `print(`, `debugPrint(`, or `log.` calls in package/app source (except `tooling/otlp_sink`)

```bash
make check-logging.sh  # Part of ci.yml
```

Fails on zero denominator or detection of hand-rolled logging.

## Form Factor Testing

Every screen must work on:
- Phone portrait (<600dp) + landscape
- Tablet portrait (≥600dp) + landscape
- Expanded (≥900dp)

**Golden tests** cover these sizes. **Widget tests** verify layout adapts:

```dart
testWidgets('phone layout', (tester) async {
  tester.binding.window.physicalSizeTestValue = const Size(390, 844);
  // ...
});

testWidgets('tablet layout', (tester) async {
  tester.binding.window.physicalSizeTestValue = const Size(834, 1194);
  // ...
});
```

## Pre-Commit Testing

```bash
make pre-commit
# Runs: lint → test-security → smoke-test → test → coverage → check-pins
```

All steps must pass. Exit status propagates — no masking with `|| true`.

| Step | What | Must pass |
|---|---|---|
| lint | `dart format` + `flutter analyze` | Zero infos/warnings |
| test-security | gitleaks, trivy, osv, semgrep, zizmor, hadolint | All scanners exit 0 |
| smoke-test | bootstrap + analyze + reference tests + telemetry | All tests pass, ≥1 log + metric |
| test | Every package with --coverage | All tests pass |
| coverage | Parse lcov.info per package | ≥90% per package, LF > 0 |
| check-pins | Verify versions are exact, Flutter consistent | No mutable refs |

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| Coverage <90% | Untested code branches | Write widget/unit tests for the branch |
| Golden mismatch | Layout changed | Review new golden; if correct: `--update-goldens` |
| Test times out | Network call or infinite loop | Use fakes instead of real HTTP; add timeout |
| Telemetry counts zero | Exporter not initialized | Verify OTEL_EXPORTER_OTLP_ENDPOINT is set and reachable |
| Emulator required | Integration test needs real device interaction | Set up Android emulator (API 35, x86_64) or physical device |

## Best Practices

- **TDD**: write test first, see it fail, implement, see it pass
- **One assertion per unit test** (prefer; integration tests can have multiple)
- **Meaningful test names**: `test('decrements cart when remove button tapped')` not `test('remove')`
- **Mock external dependencies**: fakes for API, auth, storage, telemetry
- **Test error paths**: network errors, 401 responses, storage failures
- **Test boundaries**: form factors, themes, light/dark mode
- **Keep fixtures simple**: 3–4 items, representative data only

See `APP_STANDARDS.md` for form-factor matrix and device testing recommendations.
