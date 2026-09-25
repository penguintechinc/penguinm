# Architecture — Layout, Dependencies, Workspace Mechanics

## Repository Layout

```
penguinm/
├── pubspec.yaml                 pub workspace root (workspace: members list, melos dev-dep)
├── pubspec.lock                 the ONLY lockfile — committed
├── (melos config)               under root pubspec's `melos:` key (melos 8 ignores melos.yaml)
├── analysis_options.yaml        include: package:penguin_lints/analysis_options.yaml
├── .fvmrc  .flutter-version     3.44.8 (stable)
├── VERSION                      0.1.0 — shared-library version (packages/ + shells/) only;
│                                 apps version independently via apps/<app>/VERSION
├── Makefile                     see CLAUDE.md Commands section
├── CLAUDE.md  README.md  LICENSE  .gitignore  .pre-commit-config.yaml  .PLAN  .TODO
├── .github/
│   ├── CODEOWNERS               *  @Chromeninja @PenguinzTech
│   └── workflows/               ci.yml security.yml codeql.yml toolchain-image.yml release-android.yml e2e-android.yml
├── apps/
│   ├── README.md                how to add an app (points at templates/ + ADDING_AN_APP.md)
│   ├── penguin_reference/       product key `penguinm`, proves every shell capability end-to-end
│   │   └── VERSION              0.1.0 — this app's own version; see docs/RELEASE.md
│   ├── penguincloud/            product key `penguincloud`
│   │   └── VERSION              0.1.0 — this app's own version; see docs/RELEASE.md
│   └── gazer/                   (incoming) Gazer Mobile v2 — moved in by the waddlebot session
├── shells/
│   └── penguin_app_shell/       runPenguinApp(AppManifest) — bootstrap + router + chrome
├── packages/
│   ├── flutter_libs/            migrated: theme, LoginPageBuilder, OAuth/SAML utils, TokenStorage, forms, sidebar, ConsoleVersion
│   ├── penguin_lints/           shared analysis_options
│   ├── penguin_core/            AppConfig, Result/Failure, PenguinLogger, LogSanitizer, Clock
│   ├── penguin_api/             PenguinApiClient + interceptors, RetryPolicy, TokenProvider interface
│   ├── penguin_auth/            AuthController, Session, JwtClaims, OIDC + password backends, SessionStore
│   ├── penguin_telemetry/       OTel logs/metrics/traces, OTLP/HTTP exporter, standard histograms
│   ├── penguin_flags/           FeatureFlags: PostHog + license tier, cache, FeatureGate widget
│   ├── penguin_offline/         ConnectivityMonitor, OfflineStore (SQLite), SyncQueue
│   ├── penguin_update/          UpdateChecker, UpdatePrompt
│   ├── penguin_ui/              PenguinTheme, FormFactor, ResponsiveScaffold, AdaptiveLayout, ErrorView
│   └── penguin_testing/         fakes for every interface, pump helpers, golden helper, OTLP sink client
├── platform/
│   ├── android/
│   │   ├── gradle/              libs.versions.toml, penguin-android.gradle.kts (convention), signing.gradle.kts
│   │   ├── plugins/             federated Flutter plugin packages (none yet; policy in README)
│   │   └── README.md            native-module justification policy + how to add a plugin
│   └── ios/README.md            dormant; what activates it
├── templates/
│   └── penguin_app/             mason brick → apps/<name>/lib, test, env, pubspec, README, CHANGELOG
├── tooling/
│   ├── docker/Dockerfile.flutter-android
│   ├── otlp_sink/               Dart package: local OTLP/HTTP receiver that counts records (smoke gate)
│   └── scripts/                 install-pre-commit.sh coverage-gate.sh telemetry-validate.sh check-pins.sh new-app.sh build-android.sh version.sh
└── docs/
    ├── ARCHITECTURE.md APP_STANDARDS.md ADDING_AN_APP.md AUTH.md NATIVE_MODULES.md OFFLINE.md RELEASE.md TESTING.md
    ├── flutter_libs/            API.md README.md CHANGELOG.md (moved from penguin-libs/docs/flutter-libs)
    └── superpowers/{specs,plans}/
```

## Dependency Graph

Arrows = "depends on"; no cycles:

```
apps/* → shells/penguin_app_shell → every package below
penguin_core → (nothing)                       # also hosts cross-cutting interfaces: TokenProvider, MetricsSink, TraceSink
penguin_telemetry → penguin_core               # implements MetricsSink/TraceSink
penguin_api → penguin_core                     # observes requests through MetricsSink/TraceSink
penguin_auth → penguin_core, flutter_libs      # implements TokenProvider; talks to the product API with its own http.Client
penguin_flags → penguin_core                   # own http.Client (PostHog + license server are different hosts, no product token)
penguin_ui → penguin_core, flutter_libs
penguin_offline, penguin_update → penguin_core, penguin_api
penguin_testing → every package's interfaces (dev-dependency only)
platform/android/plugins/* → flutter only (none yet)
```

Build order that follows: core → {telemetry, api, auth, flags, ui, plugins, flutter_libs tests, tooling} → {offline, update} → testing → shell + template → apps.

## Workspace Mechanics

- **Root `pubspec.yaml`**: `name: penguinm_workspace`, `publish_to: none`, `environment: sdk: '>=3.12.2 <4.0.0'`, `workspace:` listing every package, shell, app, plugin, and template
- **Every member declares** `resolution: workspace` and `environment: sdk: '>=3.12.2 <4.0.0'`, `flutter: '>=3.44.8'`
- **Exact versions everywhere** — no `^`, `~`, `any`, version ranges, or git deps without a 40-char `ref` (checked by `make check-pins`)
- **One `pubspec.lock` at root**, committed; members must not carry their own (migrated `flutter_libs` lockfile is deleted)
- **Flutter pinned to 3.44.8** in `.fvmrc`, `.flutter-version`, Docker image, every workflow; `check-pins.sh` asserts all four agree
- **Melos scripts** (root `pubspec.yaml` → `melos:` key) wrap `melos exec` so `make test` runs every package with `--coverage` and writes `coverage/lcov.info` per package

## Shared Packages — Key APIs

### penguin_core

**Config and cross-cutting interfaces — the root everyone depends on (but it depends on nothing).**

```dart
class AppConfig {
  /// Reads --dart-define values: PENGUIN_ENV, API_BASE_URL, OTEL_*, POSTHOG_*, LICENSE_SERVER_URL
  factory AppConfig.fromEnvironment({required String productKey, required String appVersion});
  bool get isLicenseBypassDomain; // checks apiBaseUrl host
}

// Cross-cutting interfaces implemented elsewhere:
abstract interface class TokenProvider { Future<String?> accessToken(); Future<bool> refresh(); }
abstract interface class MetricsSink { void counter(String name, num value, {Map<String, Object?> attributes}); }
abstract interface class TraceSink { SpanHandle startSpan(String name, {SpanHandle? parent, Map<String, Object?> attributes}); }

sealed class Result<T> { R fold<R>(R Function(T) ok, R Function(Failure) err); }
sealed class Failure { ... } // NetworkFailure, AuthFailure, ServerFailure, etc.

abstract interface class PenguinLogger { void log(LogLevel level, String message, {Map<String, Object?> attributes}); }
class LogSanitizer { static Map<String, Object?> sanitize(Map<String, Object?> attrs); }
```

### penguin_telemetry

**OpenTelemetry logs + metrics + traces, OTLP/HTTP exporter.**

```dart
class Telemetry {
  static Future<Telemetry> start(TelemetryConfig config, ...);
  PenguinLogger get logger; Meter get meter; Tracer get tracer;
  Future<void> flush(); Future<void> shutdown();
}

class Meter { Counter counter(...); Histogram histogram(...); ObservableGauge gauge(...); }
class Tracer { Span startSpan(...); Future<T> trace<T>(String name, Future<T> Function(Span) body); }
class OtlpHttpJsonExporter { /* POST <endpoint>/v1/logs|metrics|traces */ }
```

### penguin_api

**HTTP client with auth, retry, tracing, sanitized logging.**

```dart
class PenguinApiClient {
  Future<Result<T>> get<T>(String path, {Map<String, Object?>? query, required T Function(Object?) decode});
  Future<Result<T>> post<T>(String path, {Object? body, String? idempotencyKey, required T Function(Object?) decode});
  Future<Result<ClientVersionInfo>> fetchClientVersion(); // GET /api/v1/client/version
}

class RetryPolicy { /* maxAttempts, exponential backoff, configurable statuses */ }
// Middleware: AuthClient (adds Bearer token, retries on 401), RetryClient, TraceClient, SanitizedLogClient
```

### penguin_auth

**OAuth2 + PKCE hosted login (system browser) or password-based auth (transitional).**

```dart
class AuthConfig {
  const AuthConfig.hosted({required Uri issuer, required String clientId, required String redirectUri, ...});
  const AuthConfig.password({String loginPath = '/api/v1/auth/login', ...});
}

class JwtClaims { factory JwtClaims.decode(String jwt); bool isExpired(Clock c); bool hasScope(String s); }
class Session { String accessToken; String? refreshToken; DateTime expiresAt; JwtClaims claims; }

sealed class AuthState { unknown(); unauthenticated(); authenticating(); authenticated(Session); expired(); }
class AuthController extends Notifier<AuthState> implements TokenProvider { ... }
```

### penguin_flags

**PostHog feature flags + license tier, with caching and offline support.**

```dart
enum LicenseTier { free, professional, enterprise; bool satisfies(LicenseTier required); }

class FeatureFlags {
  Future<void> initialize({required String distinctId});
  bool isEnabled(String key);          // key = '<productKey>.<feature>' (never-seen → false)
  LicenseTier get tier;                // bypassDomain → enterprise; unreachable → cached; never-seen → free
  bool hasTier(LicenseTier required);
  Stream<void> get changes;
}
```

### penguin_offline

**Connectivity monitoring, SQLite-backed cache store, sync queue for offline writes.**

```dart
enum ConnectivityStatus { online, offline, unknown }
class ConnectivityMonitor { Stream<ConnectivityStatus> get status; Future<void> start(); }

abstract interface class OfflineStore {
  Future<void> put(String collection, String id, Map<String, Object?> data, {DateTime? fetchedAt});
  Future<CachedEntry?> get(String collection, String id);
  Future<List<CachedEntry>> list(String collection);
}

class SyncQueue {
  Future<void> enqueue(PendingWrite w);
  Stream<int> get depth;
  Future<SyncReport> drain(); // called automatically on offline→online
  Stream<PendingWrite> get deadLetters; // 4xx other than 408/429
}
```

### penguin_ui

**One design system, Material 3, responsive layout, form factors (phone/tablet).**

```dart
class AppBrand { const AppBrand({String? displayName, String? logoAsset, Color? seed}); }
class PenguinTheme { static ThemeData dark({Color? seed}); static ThemeData light({Color? seed}); }
enum FormFactor { phone, tablet, expanded; static FormFactor of(BuildContext c); } // <600 / 600–899 / ≥900dp

class ResponsiveScaffold { /* phone: NavigationBar; tablet: NavigationRail; expanded: SidebarMenu + master/detail */ }
class AdaptiveLayout { /* phone/tablet/expanded builders */ }
```

### shells/penguin_app_shell

**Bootstrap, router, chrome — the entry point every app calls.**

```dart
abstract class FeatureModule {
  String get id;
  String? get flagKey;              // '<productKey>.<feature>'
  List<RouteBase> routes(Ref ref);
  List<NavigationDestinationSpec> get destinations;
}

class AppManifest {
  const AppManifest({
    required this.productKey, required this.appName, required this.appVersion,
    required this.config, required this.auth, required this.features,
    this.brand = const AppBrand(), this.homeRoute = '/home', this.loginRoute = '/login',
    this.loginBuilder, this.extraRoutes = const [], this.siblings = const [],
  });
}

Future<void> runPenguinApp(AppManifest manifest, {List<Override> overrides = const []});
class Bootstrap { static Future<BootstrapResult> run(AppManifest m, ...); }

// Bootstrap order: AppConfig → Telemetry → FeatureFlags → Auth → UpdateChecker → Connectivity + SyncQueue
// No step throws; each records a warning and continues
```

### penguin_testing

**Fakes, fixtures, helpers for unit/widget/integration tests.**

```dart
// Fakes for every interface:
class FakeClock implements Clock { void setNow(DateTime dt); }
class FakeTokenProvider implements TokenProvider { void setToken(String? t); void setRefreshError(Failure f); }
class FakeAuthBackend implements AuthBackend { void pushResult(Result<Session> r); }
class FakeFlagSource implements FlagSource { void setFlags(Map<String, Object?> f); }

// Helpers:
Future<void> pumpPenguinApp(WidgetTester wt, AppManifest manifest, {List<Override> overrides});
penguinGolden(String name, {Size? size});
class OtlpSinkClient { Future<TestSummary> summary(); } // reads from tooling/otlp_sink

// Fixtures: 3–4 items per model (users, flags, version infos, etc.)
```

## Per-App Folder Standard

See `CLAUDE.md` "Per-App Folder Standard" section — verbatim reference in root.

## Android Platform Conventions

- `platform/android/gradle/libs.versions.toml` pins AGP, Kotlin, plugin versions
- `platform/android/gradle/penguin-android.gradle.kts` sets: minSdk 24, targetSdk 36, compileSdk 36, NDK 28.2.13676358, AGP 9.0.1, Kotlin 2.3.20, Gradle 9.1.0, JVM 17, ndk.abiFilters = arm64-v8a, x86_64
- `platform/android/gradle/signing.gradle.kts` requires env vars (`PENGUIN_ANDROID_KEYSTORE_PATH`, `PENGUIN_ANDROID_KEYSTORE_PASSWORD`, `PENGUIN_ANDROID_KEY_ALIAS`, `PENGUIN_ANDROID_KEY_PASSWORD`) for release builds
- Flavors: dev (appIdSuffix `.dev`), beta (`.beta`), prod (none)
- Release never signed with debug key; build fails if any signing env var is missing

## Toolchain Image & CI/CD

See `APP_STANDARDS.md` and `RELEASE.md` for Docker build, CI workflows, and versioning.
