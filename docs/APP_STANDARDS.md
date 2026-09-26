# Mobile App Standards — Flutter 3.44.8

Updated for penguinm monorepo. Supersedes `penguin-libs/docs/standards/MOBILE.md`.

## Framework & Language

| Component | Standard | Version |
|---|---|---|
| Framework | Flutter (pub workspace: single `pubspec.lock`) | 3.44.8 (stable) |
| Language | Dart | 3.12.2+ |
| State management | Riverpod | 3.4.3 (hand-written providers, no codegen) |
| HTTP | package:http (dart.dev, not `dio`) | 1.6.0 |
| Routing | go_router | 17.5.0 |
| Secure storage | flutter_secure_storage | 11.1.1 |
| Local DB | sqlite3 + raw SQL (no codegen) | 3.5.2 |
| Dependency pinning | Exact versions, no `^` or `~` | Always |

**Rejected dependencies** (supply chain, maintenance, compatibility, or redundancy):
- `dio` (publisher `flutter.cn`, PRC-based; use `package:http` instead)
- `build_runner`, `freezed`, `json_serializable`, `riverpod_generator`, `custom_lint`, `riverpod_lint` (codegen incompatible with Flutter 3.44.8 analyzer version)
- `golden_toolkit` (discontinued)
- `jwt_decoder` (abandoned 2021; decode JWT by hand)
- `sqlite3_flutter_libs`, `drift` (EOL, codegen)
- `posthog_flutter` (bundles native SDKs; call HTTP API directly)

All versions from Appendix A of the design spec; adding a dependency not listed there is a blocker.

## Platform Targets & Device Support

### Target Platforms

| Platform | Minimum Version | Native Language (Modules) |
|---|---|---|
| Android | API 24+ (7.0 Nougat) | Kotlin |
| iOS | iOS 14.0+ (15.0 for penguincloud migration) | Swift |

### Form Factors (ALL Required)

Every app must support all four combinations. Responsive layout is mandatory.

| Device | Width | Layout Expectations |
|---|---|---|
| Phone (portrait) | <600dp | Single-column, bottom navigation |
| Phone (landscape) | Varies | Adapted single-column or compact two-pane |
| Tablet (portrait) | ≥600dp | Multi-pane, side navigation |
| Tablet (landscape) | ≥900dp | Full master-detail, side navigation, expanded content |

Use `LayoutBuilder` or `MediaQuery` to adapt UI. Never hardcode widths or assume a single device size.

**Test matrix**: all four form factors must be tested before release.

| Platform | Phone | Tablet |
|---|---|---|
| Android | Emulator (API 35) | Emulator (API 35) |
| iOS | Simulator (iPhone 15) | Simulator (iPad Pro 12.9") |

Android CI covers `api 35 x86_64`; iOS testing optional until iOS is sequenced.

## API Integration

Mobile apps talk to the same REST API as the web UI. Same endpoints, same versioning, same auth flow.

- **Endpoint versioning**: `/api/v{major}/endpoint` (e.g., `/api/v1/users`)
- **Auth**: Bearer token via `Authorization: Bearer <jwt>` header
- **Token refresh**: automatic on 401 via `AuthClient` middleware; tokens stored in `flutter_secure_storage` only
- **Timeouts**: 15 seconds by default; retries with exponential backoff for 408, 429, 500, 502, 503, 504
- **Observability**: every request traced via `TraceSink`, with sanitized logging at DEBUG and below
- **Version check**: `/api/v1/client/version` (GET, no auth) returns `latestVersion` and optional `minimumVersion`; app checks at startup, non-blocking

## Authentication & Security

### Tokens

- **Storage**: `flutter_secure_storage` only (Keychain on iOS, EncryptedSharedPreferences on Android)
- **Never**: SharedPreferences, plain text files, or hardcoded values
- **Lifecycle**: obtained at login, stored, refreshed on 401, cleared on logout or refresh failure (→ unauthenticated state)
- **Tokens never logged**: sanitizer masks by key pattern (`token`, `secret`, `password`, etc.) at every level; DEBUG included

### Login

**Hosted (recommended)** — app opens system browser (Custom Tabs on Android, SFSafariViewController on iOS):
1. App constructs authorization code flow URL with PKCE
2. System browser opens product's login page
3. User authenticates (OIDC/SAML/local chosen by server)
4. Server redirects to `io.penguintech.<app>://oauth/callback?code=<code>&state=<state>`
5. App captures redirect, exchanges code for tokens
6. Tokens stored in secure storage
7. Companion apps of one family share the browser session → single sign-on per family

**Password (transitional)** — only for products without hosted login yet:
- In-app form (via `flutter_libs` `LoginPageBuilder`) with email + password
- Optional MFA token entry
- POST `/api/v1/auth/login` with credentials
- Response contains access token + optional refresh token + expiration

See `docs/AUTH.md` for full backend contract.

### TLS & Certificates

- **Beta/prod only**: HTTPS with TLS 1.2+; disable SSLv3/TLS1.0/1.1
- **Dev only**: cleartext allowed for emulator loopback (e.g., `http://127.0.0.1:8000`); declared via `android:usesCleartextTraffic` in dev flavor manifest only
- No certificate pinning at the client level (infrastructure / WAF handles it)

### Secrets & Credentials

- **No hardcoded secrets** in source or config files
- **Build secrets** (Play Store keystore, release signing creds, CI tokens): inject via GitHub secrets as environment variables, never CLI args
- **Release builds**: signed from env only; missing any signing env var → build fails

## Design & Theming

### One Design System

All 14 apps share:
- **Design**: `PenguinTheme` (Material 3, dark default, gold/amber accent)
- **Components**: `ResponsiveScaffold`, `AdaptiveLayout`, `ErrorView`, `LoadingView`, `EmptyView`, form inputs, navigation
- **Branding**: per-app name, logo, optional seed colour only — no per-app theme forks

**Module conventions**: Every app is a set of modules that mirror the product's server and web UI modules. Feature flags mirror theirs: a module-level flag key is the SAME key the server/web UI use (`<product>.<module>`), so one PostHog toggle governs every surface; only mobile-specific sub-features get `<product>.<app>.<feature>`. All fourteen apps share one UX design system with branding limited to `AppBrand` only.

Apps override **only** via `AppBrand`:
```dart
const AppBrand(
  displayName: 'My App',
  logoAsset: 'assets/logo.png',
  seed: Colors.blue, // optional; used to derive Material 3 color scheme
)
```

### Layout by Form Factor

Phone and tablet layouts **must differ**. Use `FormFactor.of(context)` to detect:

| Form Factor | Navigation | Content |
|---|---|---|
| Phone | `NavigationBar` (bottom) | Single-column, scrollable |
| Tablet | `NavigationRail` (side) or sidebar | Multi-pane, master-detail |
| Expanded (≥900dp) | `SidebarMenu` + chrome | Full master-detail, expanded sidebar |

**Never** stretch a phone layout to tablet — design responsive from the start.

## Dependency Pinning

**Every dependency pinned to exact versions — no `^`, `~`, `any`, or ranges.**

```yaml
# ✅ CORRECT — exact versions pinned
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: 3.4.3
  go_router: 17.5.0
  package:http: 1.6.0

dev_dependencies:
  flutter_lints: 6.0.0
  flutter_test:
    sdk: flutter

# ❌ WRONG — floating constraints
# flutter_riverpod: ^3.4.3
# package:http: ~1.6.0
```

**Workspace resolution**: in a pub workspace (penguinm), one `pubspec.lock` at root; members declare `resolution: workspace`. Running `flutter pub get` / `flutter pub upgrade` at the root syncs the lockfile; running in a member package is a no-op (resolution is workspace-wide).

**Verification**: `make check-pins` scans every `pubspec.yaml`, Dockerfile, and workflow for mutable refs; fails on zero files scanned or any `^`/`~`/`any` found.

## Native Modules (When Flutter Isn't Enough)

Flutter handles the vast majority of use cases. Native modules are the exception, not the rule.

### When Justified

- Flutter has **no package** for the feature
- Existing packages are **unmaintained, unstable, or missing critical functionality**
- **Performance-critical** operations: low-level Bluetooth, custom camera pipelines, real-time audio processing
- **Platform-specific APIs**: certain HealthKit/Health Connect features, NFC modes, accessibility APIs with no Flutter equivalent

### When NOT Justified

- A Flutter package exists and works (even if imperfect)
- "It would be faster in native" without measured proof
- Developer preference or familiarity
- Features achievable with platform channels + existing packages

### Rules

1. **Document the justification** — comment in native code + note in `README.md` explaining why Flutter was insufficient
2. **Keep native code minimal** — only what Flutter cannot do; logic stays in Dart
3. **Use platform channels** — `MethodChannel` for request/response, `EventChannel` for streams
4. **Write for both platforms** — every native module needs Kotlin (Android) AND Swift (iOS) implementations
5. **Test native code** — JUnit for Android, XCTest for iOS

### Platform Channel Example

```dart
// lib/services/native_bridge.dart
const _channel = MethodChannel('io.penguintech.myapp/native');

static Future<String?> getPlatformSpecificData() async {
  return await _channel.invokeMethod('getPlatformSpecificData');
}
```

Kotlin:
```kotlin
// android/app/src/main/kotlin/io/penguintech/myapp/NativeBridge.kt
channel.setMethodCallHandler { call, result ->
  when (call.method) {
    "getPlatformSpecificData" -> {
      val data = NativeLib.getData()
      result.success(data)
    }
    else -> result.notImplemented()
  }
}
```

## Testing

### Required Test Coverage

**90%+ line coverage per package**, enforced by CI. All code must meet or exceed 90% coverage.

| Test Type | Scope | Tool | Gate |
|---|---|---|---|
| Unit | Models, services, pure logic | `flutter test` | ≥90% |
| Widget | UI components, screens | `flutter test` (goldens for responsive layouts) | ≥90% |
| Integration | Critical user flows (login, offline → sync) | `flutter test integration_test/` | on release |
| Platform | Native modules (if any) | JUnit (Android), XCTest (iOS) | part of `ci.yml` |

**Running tests:**
```bash
make test-unit              # Unit tests only
make test                   # Unit + widget + coverage
make test-integration       # Integration tests (requires emulator, API 35)
make coverage               # Test + coverage-gate (≥90%)
make smoke-test             # Bootstrap + analyze + reference tests (<2 min)
```

### Mock Data

Generators in `penguin_testing` produce 3–4 items per model. `make seed-mock-data` writes them to each app's `test/fixtures/` and prints counts.

### Telemetry Testing

Every smoke test asserts OTel emission via a local OTLP/HTTP test sink (`tooling/otlp_sink`):

| Signal | Threshold | Failure |
|---|---|---|
| Log records | ≥1 | FAIL |
| Metric data points | ≥1 | FAIL |
| Histogram metrics | ≥1 | FAIL |

**Counts always printed** — "no errors" is not a pass; zero denominator is a failure.

## Offline & Sync

See `docs/OFFLINE.md` for patterns, caching, sync queue, dead-letter handling.

## Update Checking

- App checks for updates at startup via `/api/v1/client/version` (GET, no auth)
- Non-blocking; if the server is unreachable, the app continues
- If update available: show prompt with "Update" (opens store) or "Later" (dismiss)
- If update required (server version > client's minimum version): non-dismissible dialog

See `packages/penguin_update/` for implementation.

## Code Organization

Every app follows the per-app folder standard: `apps/<app>/lib/features/<feature>/` with data/domain/presentation layers.

| Layer | What | Where |
|---|---|---|
| Presentation | Screens, widgets, Riverpod providers | `presentation/{screens,widgets,providers}/` |
| Domain | Entities, pure business logic (no Flutter imports) | `domain/` |
| Data | Repositories, DTOs, API/storage calls | `data/` |

See `CLAUDE.md` "Per-App Folder Standard" for the exact structure.

## Code Documentation

Every class and public function gets a 2–3 line doc comment (`///` in Dart):

```dart
/// Decodes a JWT payload without verifying the signature (server validates).
/// Returns null if the token is malformed.
factory JwtClaims.decode(String jwt) { ... }
```

**No ASCII-art dividers or `TODO`/`FIXME` placeholders** — implement or report.

## Linting & Formatting

```bash
make lint       # dart format check + flutter analyze (zero infos/warnings)
make format     # Apply dart format
```

**Analysis options**: inherit `package:penguin_lints/analysis_options.yaml`, which includes:
- `package:flutter_lints/flutter.yaml`
- `strict-casts`, `strict-inference`, `strict-raw-types`
- `prefer_final_locals`, `unawaited_futures`, `avoid_print`, `public_member_api_docs`, `always_declare_return_types`

**No `print(` or `debugPrint(`** in package/app source (only in `tooling/otlp_sink` for CLI stdout). All logging via `PenguinLogger` (sanitized, structured, OTel-backed).

## Pre-Commit Checklist

Before committing:

```bash
make pre-commit  # Runs: lint → test-security → smoke-test → test → coverage → check-pins
```

All steps must pass. See `make pre-commit` output for detailed results.

| Gate | Checks |
|---|---|
| `lint` | dart format, flutter analyze (zero infos/warnings) |
| `test-security` | gitleaks, trivy, osv-scanner, semgrep, zizmor, hadolint |
| `smoke-test` | bootstrap + analyze + reference app tests + telemetry validation + pins check (<2 min) |
| `test` | every package with --coverage |
| `coverage` | ≥90% per package, LF > 0, no zero-coverage packages |
| `check-pins` | no mutable refs in pubspecs, workflows, Dockerfile |

Exit status propagates; no masking with `|| true`.
