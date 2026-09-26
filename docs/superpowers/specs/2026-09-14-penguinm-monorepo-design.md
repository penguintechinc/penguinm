# penguinm — Mobile Monorepo Design

Date: 2026-09-14 · Status: approved in session (user answers recorded in §1) · Branch: `feature/monorepo-skeleton` → `release/v0.1.X`

## 1. Goals & decisions

| Decision | Value |
|---|---|
| Scope | One repo for every PenguinTech mobile app. Flutter/Dart primary; Kotlin (Android) / Swift (iOS) only where Dart cannot do the job, with written justification |
| Platform priority | Android first-class. iOS second-class: generated `ios/` dirs are kept but get no CI, signing, or store work until Android ships |
| DRY | Apps are manifests + feature modules. Cross-cutting concerns (auth, API, telemetry, flags, offline, update, UI, testing) live in `packages/` and `shells/`, consumed by in-repo path dependency |
| Monorepo tooling | Dart pub workspace (one root `pubspec.lock`) + Melos 7 for cross-package scripts |
| `flutter_libs` | **Moves** from `penguin-libs` into `packages/flutter_libs` (plain copy from `penguin-libs@120fb97`, provenance line in the commit). `penguin-libs` becomes server-side only |
| Seed apps | `apps/penguin_reference` (generated from the template), `apps/penguincloud` (migrated from `penguincloud/services/mobile`). **Gazer:** the old `waddlebot/mobile/flutter_gazer` is NOT migrated — it has been superseded by Gazer Mobile v2 (`waddlebot/mobile/gazer`, M1 complete, own container toolchain on Flutter 3.47.2), which the waddlebot session moves into this repo with full history and a handoff document once its last integration is green; `apps/gazer` is reserved for that move |
| Depth | Every package ships real minimal implementations with ≥90% line coverage. No stubs, no TODO placeholders |
| State / routing / HTTP | Riverpod 3 (`flutter_riverpod 3.4.3`, hand-written providers — no `riverpod_generator`/`riverpod_lint`/`custom_lint`: verified analyzer-version deadlocks on Flutter 3.44.8), `go_router 17.5.0`, **`package:http 1.6.0` (dart.dev)** — `dio` is rejected: its publisher `flutter.cn` is a PRC-based community, which `general.md` Supply Chain forbids |
| Local DB / codegen / goldens | `sqlite3 3.5.2` (Simon Binder, DE; 3.6.0's build hooks need a `meta` newer than Flutter 3.44.8 ships) with raw parameterised SQL — `drift` dropped so the repo has **zero codegen** (`build_runner` ≥2.15.2 is incompatible with Flutter 3.44.8 and `sqlite3_flutter_libs` is EOL); JWT decoding hand-written (`jwt_decoder` abandoned since 2021); goldens via plain `matchesGoldenFile` (`golden_toolkit` discontinued) |
| Android toolchain | Flutter 3.44.8 defaults: `compileSdk 36`, `targetSdk 36`, `minSdk 24`, NDK `28.2.13676358`, AGP `9.0.1`, Kotlin `2.3.20`, Gradle `9.1.0` |
| Rules | `client.md`, `client-flutter.md`, `general.md` already name `penguinm` as the macro-repo with `packages/` + `shells/`. Only the "(layout PROPOSED)" marker is reconciled once the layout exists |

### 1.1 App roster (user-provided 2026-09-14)

Fourteen apps are planned. Directory = `apps/<snake_case>`; `applicationId` = `io.penguintech.<snake_case>`; flag keys = `<product>.<app>.<feature>` for multi-app products (still prefixed by the product key, so `FeatureFlags`' prefix check holds). Product keys and prod domains come from the `penguintech-reference` skill (resolved 2026-09-14). `KnownApp.family` is the user-facing family used for grouping and sibling handoff (Waddles, SkausWatch, Elder, Nest, Tobogganing, PenguinCloud, WaddleAI — Current belongs to Waddles, Squawk to Tobogganing); `productKey` carries the product/repo. The reference marks Current and SkausWatch as deprecated products; they stay on the roster because the user listed them — confirm before scaffolding either.

| App | Dir | Product key | Family / parent (repo) | Prod domain | Purpose | Anticipated native modules |
|---|---|---|---|---|---|---|
| Gazer | `gazer` | `waddlebot` | Waddles (`waddlebot`) | waddles.app | streaming companion (Gazer Mobile v2, incoming) | RTMP encoder, Camera2/UVC, USB audio (already in v2) |
| Waddles | `waddles` | `waddlebot` | Waddles (`waddlebot`) | waddles.app | chat / community management (Discord-class) | push notifications, media capture |
| Ruffled | `ruffled` | `waddlebot` | Waddles (`waddlebot`) | waddles.app | CRM / support / sales companion | — |
| Current | `current` | `current` | Current (`current`), Waddles companion | currenturl.app | marketing / shortlink companion | share-sheet intent |
| SkausWatch | `skauswatch` | `skauswatch` | SkausWatch (`skauswatch`) | skauswatch.app | monitoring companion | — |
| SkausWatch Vault | `skauswatch_vault` | `skauswatch` | SkausWatch (`skauswatch`) | skauswatch.app | passwords, passkeys — security-sensitive | Credential Manager / passkeys, biometric unlock, hardware keystore (Kotlin) |
| Elder | `elder` | `elder` | Elder (`elder`) | elderrms.app | core app | — |
| Elder Support | `elder_support` | `elder` | Elder (`elder`) | elderrms.app | support companion | — |
| Nest Drive | `nest_drive` | `nest` | Nest (`nest`) | nestdata.app | file drive | document provider / background sync |
| Tobogganing | `tobogganing` | `tobogganing` | Tobogganing (`tobogganing`) | tobogganing.app | core app | — |
| Tobogganing Connect | `tobogganing_connect` | `tobogganing` | Tobogganing (`tobogganing`) | tobogganing.app | tunnel client — security-sensitive | `VpnService` (Kotlin); tunnel core possibly shared with `penguind` (Rust via FFI) — later decision |
| Tobogganing Squawk | `tobogganing_squawk` | `squawk` | Squawk (`squawk`), marketed under Tobogganing | squawkmgr.app | secure DNS client — security-sensitive | `VpnService`-based DNS (Kotlin) |
| PenguinCloud | `penguincloud` | `penguincloud` | PenguinCloud (`penguincloud`) | penguincloud.io | infra overview + basic management (Gough etc.); hub that points to the other apps | — |
| WaddleAI Chat | `waddleai_chat` | `waddleai` | WaddleAI (`waddleai`) | waddleai.app | chat client | — |

Every app is a set of **modules** that mirror (much lighter) the product's server and web UI modules, and its feature flags mirror theirs: a module-level flag key is the SAME key the server/web UI use (`<product>.<module>`), so one PostHog toggle governs every surface; only mobile-specific sub-features get `<product>.<app>.<feature>`. `FeatureModule.id` equals the server module name. All fourteen apps share one UX design and style (`PenguinTheme`, `ResponsiveScaffold`, the same components); per-app branding is limited to name, logo, and an optional seed colour — no per-app theme forks.

Design consequences: the shell gains a sibling-app launcher (§4.10) so companions open each other by deep link or fall back to the store; families share `AuthConfig`/tenant so a user signs in once per family (OIDC issuer per product); every companion's `env/*.json` names its family's API base. The security-sensitive three keep secrets only in platform secure storage and are the first candidates for the native-module policy in `docs/NATIVE_MODULES.md`.

Out of scope this session (tracked in §12): retiring the `penguin-libs` Flutter CI jobs and the `penguincloud` Makefile targets (separate PRs in those repos), the native Kotlin/SwiftUI "WaddleBot Hub" skeletons, iOS signing and App Store, Play Store secrets provisioning.

## 2. Repository layout

```
penguinm/
├── pubspec.yaml                 pub workspace root (workspace: members list, melos dev-dep)
├── pubspec.lock                 the ONLY lockfile — committed
├── (melos config)               lives under the root pubspec's `melos:` key (melos 8 ignores melos.yaml): scripts bootstrap analyze format test coverage build:android
├── analysis_options.yaml        include: package:penguin_lints/analysis_options.yaml
├── .fvmrc  .flutter-version     3.44.8 (stable)
├── VERSION                      0.1.0 — repo release version, applied to every app
├── Makefile                     see §9
├── CLAUDE.md  README.md  LICENSE  .gitignore  .pre-commit-config.yaml  .PLAN  .TODO
├── .github/
│   ├── CODEOWNERS               *  @Chromeninja @PenguinzTech
│   └── workflows/               ci.yml security.yml toolchain-image.yml release-android.yml e2e-android.yml (codeql.yml arrives with the Gazer v2 intake — R11)
├── apps/
│   ├── README.md                how to add an app (points at templates/ + docs/ADDING_AN_APP.md)
│   ├── penguin_reference/       product key `penguinm`, proves every shell capability end-to-end
│   ├── penguincloud/            product key `penguincloud`
│   └── gazer/                   (incoming) Gazer Mobile v2 — moved in by the waddlebot session; converges on the shell in a later spec
├── shells/
│   └── penguin_app_shell/       runPenguinApp(AppManifest) — bootstrap + router + chrome
├── packages/
│   ├── flutter_libs/            migrated: theme, LoginPageBuilder, OAuth/SAML utils, TokenStorage, forms, sidebar, ConsoleVersion, sanitized logger
│   ├── penguin_lints/           shared analysis_options
│   ├── penguin_core/            AppConfig, Result/Failure, PenguinLogger, LogSanitizer, Clock
│   ├── penguin_api/             PenguinApiClient (package:http) + middleware, RetryPolicy
│   ├── penguin_auth/            AuthController, Session, JwtClaims, OIDC + password backends, SessionStore
│   ├── penguin_telemetry/       OTel logs/metrics/traces, OTLP/HTTP exporter, standard histograms
│   ├── penguin_flags/           FeatureFlags: PostHog + license tier, cache, FeatureGate widget
│   ├── penguin_offline/         ConnectivityMonitor, OfflineStore (drift), SyncQueue, banner + stale chip
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

Dependency direction (arrows = "depends on"; no cycles):

```
apps/* → shells/penguin_app_shell → every package below
penguin_core → (nothing)                       # also hosts the cross-cutting interfaces: TokenProvider, MetricsSink, TraceSink
penguin_telemetry → penguin_core               # implements MetricsSink/TraceSink
penguin_api → penguin_core                     # observes requests through MetricsSink/TraceSink, never imports telemetry
penguin_auth → penguin_core, flutter_libs      # implements TokenProvider; talks to the product API with its own http.Client
penguin_flags → penguin_core                   # own http.Client (PostHog + license server are different hosts, no product token)
penguin_ui → penguin_core, flutter_libs
penguin_offline, penguin_update → penguin_core, penguin_api
penguin_testing → every package's interfaces (dev-dependency only)
platform/android/plugins/* → flutter only (none yet)

Build order that follows: core → {telemetry, api, auth, flags, ui, plugins, flutter_libs tests, tooling} → {offline, update} → testing → shell + template → apps.
```

## 3. Workspace mechanics

- Root `pubspec.yaml`: `name: penguinm_workspace`, `publish_to: none`, `environment: sdk: '>=3.12.2 <4.0.0'`, `workspace:` listing every package, shell, app, plugin, template example, and `tooling/otlp_sink`. `dev_dependencies: melos` (exact).
- Every member declares `resolution: workspace` and `environment: sdk: '>=3.12.2 <4.0.0'`, `flutter: '>=3.44.8'`.
- Exact versions everywhere. `tooling/scripts/check-pins.sh` fails on `^`, `~`, `any`, version ranges, or git deps without a 40-char `ref`; it prints the number of pubspecs scanned and fails on zero.
- One `pubspec.lock` at the root, committed. Members must not carry their own lockfile (the migrated `flutter_libs` one is deleted).
- Flutter pinned to 3.44.8 in `.fvmrc`, `.flutter-version`, the Docker image, and every workflow; `tooling/scripts/check-pins.sh` also asserts those four agree.
- Melos scripts (root `pubspec.yaml` → `melos:` key) wrap `melos exec` so that `make test` runs every package's suite with `--coverage` and writes `coverage/lcov.info` per package.

## 4. Shared packages — responsibilities and public API

Signatures below are the contract between packages; implementers may add members but not rename these. `Ref`/providers are Riverpod 3.

### 4.1 penguin_lints
`lib/analysis_options.yaml`: includes `package:flutter_lints/flutter.yaml`; enables `strict-casts`, `strict-inference`, `strict-raw-types`; adds `prefer_final_locals`, `unawaited_futures`, `avoid_print`, `public_member_api_docs`, `always_declare_return_types`, `require_trailing_commas`, `avoid_dynamic_calls`. `riverpod_lint` via `custom_lint`. Apps and packages include it; `avoid_print` is disabled only in `tooling/otlp_sink` (CLI stdout is legitimate).

### 4.2 penguin_core
```dart
enum PenguinEnvironment { prealpha, alpha, beta, gamma, prod }
class AppConfig {
  const AppConfig({required this.productKey, required this.appVersion, required this.environment, required this.apiBaseUrl,
    this.otlpEndpoint, this.otlpProtocol = 'http/json', this.otlpHeaders = const {}, this.posthogHost, this.posthogProjectKey,
    required this.licenseServerUrl, this.extra = const {}});
  /// Reads --dart-define values: PENGUIN_ENV, API_BASE_URL, OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_EXPORTER_OTLP_PROTOCOL,
  /// OTEL_EXPORTER_OTLP_HEADERS (k=v,k=v), POSTHOG_HOST, POSTHOG_PROJECT_KEY, LICENSE_SERVER_URL (default https://license.penguintech.io).
  factory AppConfig.fromEnvironment({required String productKey, required String appVersion});
  bool get isLicenseBypassDomain; // apiBaseUrl host ends with penguincloud.io / penguintech.cloud / <productKey>.app
  AppConfig copyWith({Uri? apiBaseUrl, PenguinEnvironment? environment, Map<String, String>? extra});
}
/// Runtime override of the API base URL (Gazer's user-selectable domain). Persisted in SharedPreferences (a URL, not a secret).
class AppConfigController extends Notifier<AppConfig> { Future<void> setApiBaseUrl(Uri url); Future<void> resetApiBaseUrl(); }
final appConfigProvider = NotifierProvider<AppConfigController, AppConfig>(AppConfigController.new); // initial value injected by runPenguinApp
// Cross-cutting interfaces implemented elsewhere (keeps api/offline/update independent of telemetry and auth):
abstract interface class TokenProvider { Future<String?> accessToken(); Future<bool> refresh(); Stream<AuthEvent> get events; }
enum AuthEvent { refreshed, unauthenticated }
abstract interface class MetricsSink { void counter(String name, num value, {Map<String, Object?> attributes = const {}}); void histogram(String name, num value, {Map<String, Object?> attributes = const {}}); void gauge(String name, num value, {Map<String, Object?> attributes = const {}}); }
abstract interface class TraceSink { SpanHandle startSpan(String name, {SpanHandle? parent, Map<String, Object?> attributes = const {}}); }
abstract interface class SpanHandle { void setAttribute(String key, Object? value); void recordError(Object error, [StackTrace? stack]); void end(); String get traceparent; }
class NoopMetricsSink implements MetricsSink {} class NoopTraceSink implements TraceSink {} class NoopSpanHandle implements SpanHandle {}
final metricsSinkProvider = Provider<MetricsSink>((_) => const NoopMetricsSink()); final traceSinkProvider = Provider<TraceSink>((_) => const NoopTraceSink());
sealed class Result<T> { const factory Result.ok(T value); const factory Result.err(Failure f); R fold<R>(R Function(T) ok, R Function(Failure) err); }
sealed class Failure { NetworkFailure(String message, {Object? cause}); AuthFailure(int? statusCode, String message); ValidationFailure(String field, String message); StorageFailure(String message); ServerFailure(int statusCode, String message); UnknownFailure(Object cause, StackTrace stack); }
enum LogLevel { debug, info, warn, error }
abstract interface class PenguinLogger { void log(LogLevel level, String message, {Map<String, Object?> attributes = const {}, Object? error, StackTrace? stackTrace}); void debug(String m, {Map<String, Object?> attributes}); /* info, warn, error likewise */ }
class ConsoleLogger implements PenguinLogger { /* sanitized, structured single-line JSON; enabled below prod only */ }
class LogSanitizer { static const sensitiveKeyPattern = r'(token|secret|password|passwd|authorization|api[_-]?key|mfa|otp|cookie|session|private[_-]?key)'; static Map<String, Object?> sanitize(Map<String, Object?> attrs); static String maskValue(String v); /* keeps last 4 chars: tok_****1234 */ }
abstract interface class Clock { DateTime now(); } class SystemClock implements Clock {}
// Riverpod
final clockProvider = Provider<Clock>((_) => const SystemClock());
final loggerProvider = Provider<PenguinLogger>(...); // overridden by telemetry
```
Configuration on mobile is build-time: `--dart-define-from-file=env/<flavor>.json` carries the public values above (URLs, project keys). No secrets are ever in these files; the PostHog project key is a public write-only key by PostHog's design and is still treated as config, not a credential.

### 4.3 penguin_telemetry
```dart
class TelemetryConfig { const TelemetryConfig({required this.serviceName, required this.serviceVersion, this.endpoint, this.protocol = OtlpProtocol.httpJson, this.headers = const {}, this.resourceAttributes = const {}, this.exportInterval = const Duration(seconds: 10), this.maxQueue = 2048, this.consoleMirror = false}); factory TelemetryConfig.fromAppConfig(AppConfig c); }
enum OtlpProtocol { httpJson, httpProtobuf /* rejected with WARN + fallback to httpJson in this version */, grpc /* same */ }
abstract interface class TelemetryExporter { Future<ExportResult> exportLogs(List<LogRecordData> r); Future<ExportResult> exportMetrics(List<MetricData> m); Future<ExportResult> exportSpans(List<SpanData> s); }
class ExportResult { final bool ok; final int accepted; final String? error; }
class OtlpHttpJsonExporter implements TelemetryExporter { OtlpHttpJsonExporter({required Uri endpoint, Map<String,String> headers, http.Client? client, Duration timeout = const Duration(seconds: 5)}); /* POST <endpoint>/v1/logs|metrics|traces, OTLP JSON encoding; never throws */ }
class NoopExporter implements TelemetryExporter {}
class Telemetry {
  static Future<Telemetry> start(TelemetryConfig config, {TelemetryExporter? exporter, Clock? clock});
  PenguinLogger get logger; Meter get meter; Tracer get tracer;
  Future<void> flush(); Future<void> shutdown();
  int get droppedCount; // exposed as counter telemetry.dropped too
}
class Meter { Counter counter(String name, {String unit = '1', String description = ''}); Histogram histogram(String name, {String unit = 'ms', String description = '', List<double> boundaries = defaultMsBoundaries}); ObservableGauge gauge(String name, double Function() observe, {String unit = '1'}); }
class Counter { void add(num value, {Map<String, Object?> attributes = const {}}); }
class Histogram { void record(num value, {Map<String, Object?> attributes = const {}}); }
class Tracer { Span startSpan(String name, {SpanKind kind = SpanKind.internal, Span? parent, Map<String, Object?> attributes = const {}}); Future<T> trace<T>(String name, Future<T> Function(Span span) body, {SpanKind kind}); }
class Span { void setAttribute(String key, Object? value); void recordError(Object error, [StackTrace? stack]); void setStatus(SpanStatus s); void end(); String get traceparent; /* W3C: 00-<traceId>-<spanId>-01 */ }
class StandardMetrics { static const appStartupDuration = 'app.startup.duration'; static const routeLoadDuration = 'app.route.load.duration'; static const httpClientRequestDuration = 'http.client.request.duration'; static const httpClientRequestSize = 'http.client.request.body.size'; static const syncQueueDepth = 'sync.queue.depth'; static const telemetryDropped = 'telemetry.dropped'; }
class TelemetryMetricsSink implements MetricsSink { TelemetryMetricsSink(Meter m); } // instruments created lazily per name, cached
class TelemetryTraceSink implements TraceSink { TelemetryTraceSink(Tracer t); }      // Span implements SpanHandle
final telemetryProvider = Provider<Telemetry>((_) => throw UnimplementedError());
```
Behaviour: bounded queue per signal, drop-oldest when full, periodic export on `exportInterval` plus explicit `flush()`; export failures increment `telemetry.dropped` and log once per minute at WARN; every attribute map passes `LogSanitizer.sanitize` before enqueue; the app never awaits an export on a request path. Default endpoint port for OTLP/HTTP is 4318. Level default INFO; DEBUG enabled when `environment` is `prealpha`/`alpha`.

### 4.4 penguin_api
```dart
// TokenProvider, AuthEvent, MetricsSink, TraceSink come from penguin_core.
class RetryPolicy { const RetryPolicy({this.maxAttempts = 3, this.baseDelay = const Duration(milliseconds: 500), this.multiplier = 2.0, this.maxDelay = const Duration(seconds: 8), this.jitter = true, this.retryStatuses = const {408, 429, 500, 502, 503, 504}}); Duration delayFor(int attempt, Random rng); bool shouldRetry(http.BaseRequest request, http.BaseResponse? response, Object? error, int attempt); /* never 401/403; POST/PUT/PATCH only with an Idempotency-Key header; ClientException/timeouts count as retryable */ }
class PenguinApiClient {
  PenguinApiClient({required AppConfig config, required TokenProvider tokens, MetricsSink metrics = const NoopMetricsSink(), TraceSink traces = const NoopTraceSink(), PenguinLogger? log, RetryPolicy retry = const RetryPolicy(), http.Client? inner, Duration timeout = const Duration(seconds: 15)});
  void setBaseUrl(Uri url); // follows AppConfigController changes (Gazer domain switcher)
  http.Client get client; // the composed chain: SanitizedLogClient(TraceClient(RetryClient(AuthClient(inner))))
  Future<Result<T>> get<T>(String path, {Map<String, Object?>? query, required T Function(Object? json) decode});
  Future<Result<T>> post<T>(String path, {Object? body, String? idempotencyKey, required T Function(Object? json) decode});
  Future<Result<T>> put<T>(...); Future<Result<T>> delete<T>(...);
  Future<Result<ClientVersionInfo>> fetchClientVersion(); // GET /api/v1/client/version
}
class ClientVersionInfo { final String latestVersion; final String? minimumVersion; final Uri? storeUrl; final String? releaseNotes; factory fromJson(Map); }
// Middleware layers, each an http.BaseClient (exported for tests): AuthClient, RetryClient, TraceClient, SanitizedLogClient
Failure mapFailure(Object error, {http.BaseResponse? response}); // 401/403 → AuthFailure, 5xx → ServerFailure, ClientException/TimeoutException/SocketException → NetworkFailure
```
`AuthClient`: adds `Authorization: Bearer`; on 401 calls `tokens.refresh()` once and replays the request (requests are copied via `http.Request` re-creation — streamed bodies are buffered up front for that reason); second 401 or refresh failure → `AuthEvent.unauthenticated`. `TraceClient` (via `TraceSink`/`MetricsSink`): span `HTTP <METHOD>` with `http.request.method`, `url.path` (no query values), `http.response.status_code`; injects `traceparent`; records `http.client.request.duration` histogram. Query values and bodies are never logged above DEBUG and are sanitized at DEBUG.

### 4.5 penguin_auth
```dart
// Login is punted to the server (user direction 2026-09-14): the app opens the product's HOSTED login page in the system
// browser (Custom Tabs) via authorization code + PKCE; the server decides OIDC / SAML / local login and MFA; the app only
// receives the code on its redirect URI and exchanges it for tokens. The app never renders a username/password form or
// provider buttons. Companion apps of one family share the browser session → single sign-on per family.
class AuthConfig {
  /// Default for every app. `issuer` is the product's auth base (usually `apiBaseUrl`); discovery at
  /// `<issuer>/.well-known/openid-configuration` when available, else explicit endpoints.
  const AuthConfig.hosted({required Uri issuer, required String clientId, required String redirectUri, Uri? authorizationEndpoint, Uri? tokenEndpoint, Uri? endSessionEndpoint, List<String> scopes = const ['openid','profile','email','offline_access'], bool preferEphemeralSession = false});
  /// TRANSITIONAL fallback for a backend that has no hosted mobile login yet (penguincloud's `/api/v1/auth/login` today);
  /// renders flutter_libs `LoginPageBuilder` in-app. Every use is tracked in docs/AUTH.md until the backend catches up.
  const AuthConfig.password({String loginPath = '/api/v1/auth/login', String refreshPath = '/api/v1/auth/refresh', String logoutPath = '/api/v1/auth/logout', String profilePath = '/api/v1/auth/profile', bool mfa = true});
}
class JwtClaims { factory JwtClaims.decode(String jwt); /* base64url payload only — no signature check on client; server validates */ final String? sub, iss, tenant; final List<String> aud, scope, teams, roles; final DateTime? exp, iat; bool isExpired(Clock c, {Duration leeway = const Duration(seconds: 30)}); bool hasScope(String s); Map<String, Object?> get raw; }
class Session { const Session({required this.accessToken, this.refreshToken, required this.expiresAt, required this.claims}); Map toJson(); factory fromJson(Map); }
sealed class AuthState { const factory AuthState.unknown(); unauthenticated(); authenticating(); authenticated(Session s); expired(); }
abstract interface class AuthBackend { Future<Result<Session>> login(LoginRequest r); Future<Result<Session>> refresh(Session s); Future<Result<void>> logout(Session s); }
sealed class LoginRequest { const factory LoginRequest.interactive(); /* hosted browser flow — the default */ const factory LoginRequest.password({required String email, required String password, String? mfaCode}); const factory LoginRequest.fromLoginResponse(LoginResponse r); /* flutter_libs LoginPageBuilder result (transitional) */ }
class HostedLoginBackend implements AuthBackend { HostedLoginBackend(AuthConfig cfg, {AppAuthFacade? appAuth, Clock? clock}); } // flutter_appauth: authorizeAndExchangeCode (PKCE, discovery or explicit endpoints), token refresh, endSession on logout
class PasswordAuthBackend implements AuthBackend { PasswordAuthBackend(AuthConfig cfg, {required Uri apiBaseUrl, http.Client? client, Clock? clock}); }
class SessionStore { SessionStore({FlutterSecureStorage? storage}); Future<Session?> load(); Future<void> save(Session s); Future<void> clear(); }
class AuthController extends Notifier<AuthState> implements TokenProvider { Future<void> initialize(); Future<Result<void>> login(LoginRequest r); Future<void> logout(); /* schedules refresh at exp - 60s; refresh failure → expired */ }
final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
final authBackendProvider = Provider<AuthBackend>((_) => throw UnimplementedError());
String? authRedirect(AuthState state, GoRouterState route, {required String loginPath, required String homePath});
```
Tokens live only in `flutter_secure_storage` (via `SessionStore`); cleared on logout and on unrecoverable 401. Redirect scheme per app AND flavor = the variant's applicationId (`io.penguintech.<app>`, `.dev`, `.beta`), so flavors can be installed side by side without an app-chooser: `platform/android/gradle/penguin-android.gradle.kts` sets `manifestPlaceholders["appAuthRedirectScheme"]` from each variant's applicationId (required by `flutter_appauth`), and each app's `env/<flavor>.json` carries `OAUTH_CLIENT_ID` and `OAUTH_REDIRECT_URI` (`<applicationId>://oauth/callback`), read by `manifest.dart` via `String.fromEnvironment`. The product's auth server registers all three redirect URIs for the app's client. **Backend contract** (`docs/AUTH.md`, relayed to every product team): each product exposes an OAuth2 authorization-code + PKCE flow for public mobile clients (one `client_id` per app, no client secret), hosts its own login UI where OIDC/SAML/local and MFA are chosen server-side, issues the standard JWT claims from `security.md`, rotates refresh tokens, and offers `end_session`; discovery at `/.well-known/openid-configuration` is preferred.

### 4.6 penguin_flags
```dart
enum LicenseTier { free, professional, enterprise; bool satisfies(LicenseTier required); }
class FlagsConfig { const FlagsConfig({required this.productKey, this.posthogHost, this.posthogProjectKey, required this.licenseServerUrl, this.refreshInterval = const Duration(minutes: 15), this.bypassDomain = false}); factory fromAppConfig(AppConfig c); }
abstract interface class FlagSource { Future<Result<Map<String, Object?>>> fetch({required String distinctId, Map<String, String> properties = const {}}); }
class PostHogFlagSource implements FlagSource { PostHogFlagSource({required Uri host, required String projectKey, http.Client? client}); /* POST <host>/decide?v=3 {api_key, distinct_id, person_properties} → featureFlags; own http.Client, no product token */ }
abstract interface class LicenseSource { Future<Result<LicenseEntitlement>> fetch({required String productKey, String? licenseKey, required String installationId}); }
class LicenseEntitlement { final LicenseTier tier; final DateTime? expiresAt; final Map<String, Object?> features; }
class PenguinLicenseSource implements LicenseSource { /* endpoints per `integrating-license-server` skill; the implementer loads it */ }
class FlagCache { FlagCache({SharedPreferences? prefs}); Future<CachedFlags?> load(); Future<void> save(CachedFlags c); } // flags are not secrets → SharedPreferences is correct here
class FeatureFlags {
  FeatureFlags({required FlagsConfig config, required FlagSource flags, required LicenseSource license, required FlagCache cache, required PenguinLogger log, Clock? clock});
  Future<void> initialize({required String distinctId}); // loads cache first (instant), then refreshes in background; never throws
  bool isEnabled(String key);          // key must be '<productKey>.<feature>'; never-seen → false
  LicenseTier get tier;                // bypassDomain → enterprise; unreachable → cached; never-seen → free
  bool hasTier(LicenseTier required);
  DateTime? get lastRefreshed; Stream<void> get changes; Future<void> refresh();
}
class FeatureGate extends ConsumerWidget { const FeatureGate({required String flag, required Widget child, Widget? fallback, LicenseTier? tier}); }
final featureFlagsProvider = Provider<FeatureFlags>((_) => throw UnimplementedError());
final flagProvider = Provider.family<bool, String>((ref, key) => ref.watch(featureFlagsProvider).isEnabled(key));
```
Rules honoured: every feature module declares `flagKey`; unseen flags are OFF; license/flag server unreachable → cached value, never a crash; bypass is domain-based only (`AppConfig.isLicenseBypassDomain`); the server-side `--dev` flag is not a client concern.

### 4.7 penguin_offline
```dart
enum ConnectivityStatus { online, offline, unknown }
class ConnectivityMonitor { ConnectivityMonitor({Connectivity? plugin}); Stream<ConnectivityStatus> get status; ConnectivityStatus get current; Future<void> start(); Future<void> dispose(); }
class CachedEntry { final String collection, id; final Map<String, Object?> data; final DateTime fetchedAt; Duration age(Clock c); }
abstract interface class OfflineStore { Future<void> put(String collection, String id, Map<String, Object?> data, {DateTime? fetchedAt}); Future<CachedEntry?> get(String collection, String id); Future<List<CachedEntry>> list(String collection); Future<void> remove(String collection, String id); Future<void> clear(String collection); }
class OfflineDatabase { OfflineDatabase.open(String path); OfflineDatabase.inMemory(); /* package:sqlite3; schema via PRAGMA user_version migrations; tables cache_entries(collection TEXT, id TEXT, json TEXT, fetched_at INTEGER, PRIMARY KEY(collection,id)) and pending_writes(id TEXT PRIMARY KEY, created_at INTEGER, method TEXT, path TEXT, body TEXT, idempotency_key TEXT, attempts INTEGER, last_error TEXT) */ void close(); }
class SqliteOfflineStore implements OfflineStore { SqliteOfflineStore(OfflineDatabase db); } // parameterised statements only, never string-built SQL
Future<OfflineDatabase> openAppDatabase({required String productKey}); // <getApplicationSupportDirectory()>/penguin_offline/<productKey>.sqlite
class PendingWrite { final String id, method, path; final Map<String, Object?>? body; final String? idempotencyKey; final DateTime createdAt; final int attempts; final String? lastError; }
class SyncReport { final int sent, failed, deadLettered; }
class SyncQueue {
  SyncQueue({required OfflineDatabase db, required PenguinApiClient api, required ConnectivityMonitor connectivity, required PenguinLogger log, MetricsSink metrics = const NoopMetricsSink(), RetryPolicy retry = const RetryPolicy(maxAttempts: 5)});
  Future<void> enqueue(PendingWrite w); Stream<int> get depth; Future<SyncReport> drain(); // called automatically on offline→online
  Stream<PendingWrite> get deadLetters; // 4xx other than 408/429 → surfaced to the user, never silently dropped
}
class ConnectivityBanner extends ConsumerWidget {} // "⚠️ Offline — changes will sync when you're back online" / hidden when online
class StaleDataChip extends StatelessWidget { const StaleDataChip({required DateTime fetchedAt}); } // "Last synced 2h ago"
final connectivityProvider = StreamProvider<ConnectivityStatus>(...); final offlineStoreProvider = Provider<OfflineStore>(...); final syncQueueProvider = Provider<SyncQueue>(...);
```

### 4.8 penguin_update
```dart
sealed class UpdateStatus { const factory UpdateStatus.upToDate(); updateAvailable(ClientVersionInfo i); updateRequired(ClientVersionInfo i); unknown(Failure f); }
class UpdateChecker { UpdateChecker({required PenguinApiClient api, required PenguinLogger log}); Future<UpdateStatus> check({required String currentVersion}); /* pub_semver compare; timeout 5s; never throws */ }
class UpdatePrompt extends ConsumerWidget {} // available → MaterialBanner with "Update" (url_launcher → storeUrl or market://details?id=<applicationId>) and "Later"; required → non-dismissible dialog
final updateStatusProvider = FutureProvider<UpdateStatus>(...); // fired once at startup, non-blocking
```

### 4.9 penguin_ui
```dart
class AppBrand { const AppBrand({String? displayName, String? logoAsset, Color? seed}); }
class PenguinTheme { static ThemeData dark({Color? seed}); static ThemeData light({Color? seed}); } // the ONE design system for every app; apps never subclass or fork it // Material 3, dark default, gold/amber accent, registers ElderThemeData extension so flutter_libs widgets match
enum FormFactor { phone, tablet, expanded; static FormFactor of(BuildContext c); } // <600 / 600–899 / ≥900 logical px
class NavigationDestinationSpec { final String route, label; final IconData icon, selectedIcon; }
class ResponsiveScaffold extends StatelessWidget { const ResponsiveScaffold({required List<NavigationDestinationSpec> destinations, required int selectedIndex, required ValueChanged<int> onSelect, required Widget body, Widget? detail, PreferredSizeWidget? appBar}); } // phone: NavigationBar; tablet: NavigationRail; expanded: flutter_libs SidebarMenu + master/detail
class AdaptiveLayout extends StatelessWidget { const AdaptiveLayout({required WidgetBuilder phone, required WidgetBuilder tablet, WidgetBuilder? expanded}); }
class ErrorView extends StatelessWidget { const ErrorView({required Failure failure, VoidCallback? onRetry}); } class LoadingView {} class EmptyView { const EmptyView({required String message}); }
```
Golden tests cover `ResponsiveScaffold` at phone (390×844), tablet (834×1194) and expanded (1280×800) sizes.

### 4.10 shells/penguin_app_shell
```dart
abstract class FeatureModule {
  String get id;                         // e.g. 'springboard'
  String? get flagKey;                   // '<productKey>.<id>' — the SAME key the product's server/web UI use for this module; null only for the login/home module
  List<RouteBase> routes(Ref ref);
  List<NavigationDestinationSpec> get destinations;
  List<Override> get providerOverrides => const [];
  Future<void> init(Ref ref) async {}
}
class AppManifest {
  const AppManifest({required this.productKey, required this.appName, required this.appVersion, required this.config, required this.auth, required this.features,
    this.brand = const AppBrand(), this.homeRoute = '/home', this.loginRoute = '/login', this.loginBuilder, this.extraRoutes = const [], this.siblings = const []});
  final AppBrand brand; // name/logo/optional seed colour only — every app uses PenguinTheme unchanged (one UX across the roster)
  final Widget Function(BuildContext, WidgetRef)? loginBuilder; // default: HostedLoginScreen (branding + one "Continue to sign in" button → LoginRequest.interactive()); LoginPageBuilder only when auth is AuthConfig.password
}
Future<void> runPenguinApp(AppManifest manifest, {List<Override> overrides = const []});
class PenguinApp extends ConsumerWidget { const PenguinApp({required AppManifest manifest}); }
/// Sibling apps a manifest can hand off to (PenguinCloud → product apps, companions → their family's core app).
class SiblingApp { const SiblingApp({required this.id, required this.displayName, required this.applicationId, required this.scheme}); /* scheme: io.penguintech.<id> */ Uri deepLink(String route); Uri get storeUri; /* market://details?id=<applicationId> */ }
class SiblingAppLauncher { SiblingAppLauncher({UrlLauncher? launcher}); Future<LaunchOutcome> open(SiblingApp app, {String route = '/'}); } // tries the deep link, falls back to the store; never throws
enum LaunchOutcome { opened, sentToStore, failed }
// AppManifest gains `List<SiblingApp> siblings = const []`; the registry of all fourteen apps lives in penguin_core as `KnownApps` (id, displayName, applicationId, productKey) so every manifest references the same constants.
class Bootstrap { static Future<BootstrapResult> run(AppManifest m, {List<Override> overrides}); } // exposed for tests
class BootstrapResult { final List<Override> overrides; final Duration startupDuration; final List<BootstrapWarning> warnings; }
```
Bootstrap order and failure policy: `AppConfig` → `Telemetry.start` (exporter failure → NoopExporter + WARN) → `FeatureFlags.initialize` (cache first, refresh in background) → `AuthController.initialize` → `UpdateChecker.check` (fire-and-forget) → `ConnectivityMonitor.start` + `SyncQueue`. No step may throw out of `runPenguinApp`; each records a `BootstrapWarning` and the app continues. `app.startup.duration` is recorded once the first frame is scheduled. `default_login.dart`: `HostedLoginScreen` (app name/logo, "Continue to sign in" → `controller.login(const LoginRequest.interactive())`, inline error + retry, no credential fields) is the default; only when the manifest's auth is `AuthConfig.password` does it wrap flutter_libs `LoginPageBuilder`. `PenguinApp` builds `MaterialApp.router` with routes from modules whose `flagKey` is enabled (re-evaluated on `FeatureFlags.changes`), `authRedirect`, a `ConnectivityBanner` above the router shell, `UpdatePrompt`, and flutter_libs `ConsoleVersion` overlay below prod.

### 4.11 penguin_testing
`FakeClock`, `FakeTokenProvider`, `FakeAuthBackend` (scripted results), `FakeFlagSource`, `FakeLicenseSource`, `InMemoryFlagCache`, `InMemoryTelemetryExporter` (lists of exported logs/metrics/spans + `expectHistogram(name)`), `FakeConnectivityMonitor` (`setStatus`), `InMemoryOfflineStore`, `FakeUpdateChecker`, `ScriptedHttpClient` (a `MockClient` from `package:http/testing.dart` fed by a queue of scripted responses, recording every request), `pumpPenguinApp(WidgetTester, AppManifest, {overrides})`, `penguinGolden(String name, {Size size})`, `OtlpSinkClient` (reads `/summary` from `tooling/otlp_sink`), and `fixtures/` with 3–4 items per shared model (users, springboard items, version infos).

## 5. Per-app folder standard (goes into CLAUDE.md verbatim)

```
apps/<app_name>/
├── pubspec.yaml               name: <app_name>; resolution: workspace; deps: penguin_app_shell + packages via path; exact versions
├── env/                       PUBLIC build config only (URLs, project keys) — one JSON per flavor, no secrets
│   ├── dev.json  beta.json  prod.json
├── lib/
│   ├── main.dart              runPenguinApp(manifest) — ≤15 lines, no logic, no widgets
│   ├── manifest.dart          AppManifest: productKey, config (AppConfig.fromEnvironment), auth, features, theme overrides
│   └── features/<feature>/    one folder per feature, self-contained, gated by '<productKey>.<feature>'
│       ├── <feature>_module.dart   FeatureModule: routes, destinations, providers, init
│       ├── data/              repositories + DTOs; only place that calls PenguinApiClient / OfflineStore
│       ├── domain/            entities + pure logic; no Flutter imports
│       └── presentation/      screens/ widgets/ providers/ (Riverpod)
├── android/                   flutter-generated; app/build.gradle.kts applies platform/android/gradle conventions; flavors dev/beta/prod
├── ios/                       flutter-generated; dormant until iOS is sequenced (kept compiling, not built in CI)
├── assets/                    images/ icons/ (launcher icons via flutter_launcher_icons config in pubspec)
├── test/                      mirrors lib/: features/<feature>/..._test.dart; goldens/ ; fixtures/ (3–4 mock items per feature)
├── integration_test/          critical flows (login, offline write → sync)
├── README.md                  what works offline, env/flavor table, run/build commands, native modules used
└── CHANGELOG.md
```
Naming: app dir and pubspec `name` are `snake_case`; Android `applicationId` is `io.penguintech.<app_name>` with `.dev`/`.beta` suffixes per flavor; flag keys are `<productKey>.<feature>` for single-app products and `<productKey>.<app>.<feature>` for multi-app families (§1.1); every screen has a widget test; every feature has ≥3 fixture items. The roster in §1.1 is the source of truth for ids, product keys, and applicationIds (`KnownApps` in `penguin_core`).

## 6. Android platform conventions

- `platform/android/gradle/libs.versions.toml` pins AGP, Kotlin, and plugin dependencies; apps' `settings.gradle.kts` include it as a version catalog.
- `platform/android/gradle/penguin-android.gradle.kts` (applied from each app's `app/build.gradle.kts`): `minSdk = 24` (≥ the rules' 21 floor; Flutter 3.44.8's own default), `targetSdk = 36`, `compileSdk = 36` (Flutter 3.44.8 defaults; ≥ the rules' 35 floor), `ndkVersion = "28.2.13676358"`, AGP `9.0.1`, Kotlin `2.3.20`, Gradle wrapper `9.1.0`, JVM 17, `ndk.abiFilters = arm64-v8a, x86_64` (+ armeabi-v7a for release APK splits), flavors `dev`/`beta`/`prod` with `applicationIdSuffix`, `isMinifyEnabled` + `--obfuscate --split-debug-info` for release, `INTERNET` permission declared in every app manifest.
- `platform/android/gradle/signing.gradle.kts`: release signing from env only — `PENGUIN_ANDROID_KEYSTORE_PATH`, `PENGUIN_ANDROID_KEYSTORE_PASSWORD`, `PENGUIN_ANDROID_KEY_ALIAS`, `PENGUIN_ANDROID_KEY_PASSWORD`. A release build with any of them missing fails; release is never signed with the debug key.
- `platform/android/plugins/<name>/`: a federated Flutter plugin package (`flutter: plugin: platforms: android:`), Kotlin under `android/src/main/kotlin/io/penguintech/<name>/`, JUnit tests under `android/src/test/`, Dart API + tests in `lib/` + `test/`, `README.md` with the justification required by `docs/NATIVE_MODULES.md`. iOS implementations are added only when iOS is sequenced.

## 7. Toolchain image & scripts

`tooling/docker/Dockerfile.flutter-android` (build host linux/amd64; produces Android artifacts for arm64-v8a + x86_64 + armeabi-v7a):
- `FROM debian:bookworm-slim@sha256:<digest>`; apt packages version-pinned; JDK 17 headless.
- Android command-line tools `commandlinetools-linux-15859902_latest.zip` downloaded from `dl.google.com`, **SHA256 `4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583` verified**; `sdkmanager` installs `platform-tools`, `platforms;android-36`, `build-tools;36.0.0`, `ndk;28.2.13676358` (Flutter 3.44.8's default NDK, required by `sqlite3`'s native-asset build).
- Flutter SDK: `git clone --depth 1 --branch 3.44.8` then assert `git rev-parse HEAD` equals the pinned framework revision `058e0af2c2…`; `flutter precache --android`; licenses accepted.
- `USER 1000` (`appuser`), no root at runtime, `HEALTHCHECK NONE`, multi-stage: `toolchain` → `deps` (`melos bootstrap`) → `analyze` → `test` → `build` → `FROM scratch` output stage exporting `.apk`/`.aab`.
- Published by `toolchain-image.yml` to `ghcr.io/penguintechinc/penguinm/flutter-android:<flutter-version>-<epoch64>` on changes under `tooling/docker/**` (and `workflow_dispatch`); `ci.yml` and `release-android.yml` run their Android jobs inside that image, referenced by digest once the first publish exists (a plan task pins it).

Scripts (all `set -euo pipefail`, Bash 3.2-compatible):

| Script | Does | Fails when |
|---|---|---|
| `install-pre-commit.sh [--verify]` | installs/validates the git hooks from `.pre-commit-config.yaml` | hooks missing, empty, or stubbed |
| `check-pins.sh` | scans every `pubspec.yaml`, workflow, Dockerfile for mutable refs; asserts Flutter version agreement | any `^`/`~`/`any`/range, unpinned action or image, or 0 files scanned |
| `coverage-gate.sh [--min 90]` | per package: parses `coverage/lcov.info`, prints `LH/LF %`, aggregates | any package < 90%, any package with LF = 0, or 0 packages found |
| `telemetry-validate.sh` | starts `tooling/otlp_sink` on 127.0.0.1:4318, runs `apps/penguin_reference` telemetry smoke test against it, prints counts | logs < 1, metric points < 1, histograms < 1, sink failed to start |
| `new-app.sh <name> <product_key> <display_name>` | `flutter create --org io.penguintech --platforms android,ios --empty apps/<name>`, then `mason make penguin_app`, wires gradle conventions, adds workspace member + CI matrix entry | name not snake_case, dir exists |
| `build-android.sh <app> <flavor> [apk\|aab]` | runs the build inside the toolchain image, copies artifacts to `build/artifacts/<app>/` | any step non-zero |
| `version.sh` | applies `VERSION` (+ epoch build) to every app pubspec | version format invalid |

## 8. CI/CD

| Workflow | Trigger | Jobs |
|---|---|---|
| `ci.yml` | `pull_request`; `push` to `release/**`, `main` | `dart`: flutter-action@3.44.8 → `melos bootstrap` → `dart format --set-exit-if-changed` → `flutter analyze` (zero infos/warnings) → `melos run test` (coverage per package) → `coverage-gate.sh` → `telemetry-validate.sh` → `check-logging.sh` → `check-pins.sh`. `android`: matrix over `[penguin_reference, penguincloud]`, inside the toolchain image, `flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json`, uploads APK artifact |
| `security.yml` | same as ci + weekly schedule | gitleaks, trivy fs (vuln + config), osv-scanner (reusable workflow), semgrep (`p/dart`, `p/kotlin`, `p/secrets`) installed with `uv pip install --require-hashes -r tooling/security/requirements.txt` (both `semgrep-action` repos are archived — no action to pin), zizmor on workflows, hadolint on the Dockerfile — each step's status propagates; no `\|\| true` |
| `toolchain-image.yml` | `push` touching `tooling/docker/**`; `workflow_dispatch` | buildx → push `ghcr.io/penguintechinc/penguinm/flutter-android:<ver>-<epoch64>`, prints digest |
| `release-android.yml` | `release` with `types: [prereleased, released]` | matrix over `[penguin_reference, penguincloud]`: signed `aab` (`prod` flavor) inside the image, secrets from GitHub secrets as env (never CLI args), upload artifact + attach to the release; Play upload track `internal` on prerelease, `production` on released; missing secrets → job fails |
| `e2e-android.yml` | `workflow_dispatch`, `release` | Android emulator runner (API 35, x86_64) executes `integration_test/` for each app |

All `uses:` pinned to full commit SHAs with a `# vX.Y.Z` comment. Playwright is not used (no web target). Artifacts of any kind never include `env/*.json` secrets because there are none.

## 9. Make targets

`setup` (fvm-less: verifies `flutter --version` = 3.44.8, `dart pub get`, `melos bootstrap`, installs hooks) · `install-hooks` · `verify-hooks` · `bootstrap` · `lint` (format check + analyze + custom_lint) · `format` · `test` · `test-unit` · `test-integration` (emulator required, documented) · `coverage` (= test + coverage-gate) · `test-security` (gitleaks, trivy, osv-scanner, semgrep, zizmor, hadolint) · `smoke-test` (bootstrap + analyze + `penguin_reference` tests + telemetry-validate + check-pins, < 2 min) · `build-android APP=<app> FLAVOR=<dev|beta|prod> FORMAT=<apk|aab>` · `docker-build` (toolchain image) · `new-app NAME= PRODUCT= DISPLAY=` · `seed-mock-data` (regenerates `test/fixtures` from `penguin_testing` generators, prints counts) · `clean` · `pre-commit` (lint → test-security → smoke-test → test → coverage → check-pins, stops on first failure, summary to `/tmp/pre-commit-penguinm-<epoch>/summary.log`) · `version`.

Every target that runs a checker propagates its exit status; `make pre-commit` prints the count of packages, tests, and files each gate examined.

## 10. Testing strategy

| Layer | What | Where | Gate |
|---|---|---|---|
| Unit | pure Dart: Result, JwtClaims, RetryPolicy, LogSanitizer, OTLP encoding, semver compare, flag resolution | each package `test/` | ≥90% per package |
| Widget | every widget in `penguin_ui`, `penguin_offline`, `penguin_update`, `penguin_flags`, shell chrome, every app screen | same | ≥90% |
| Golden | `ResponsiveScaffold` ×3 sizes, `ConnectivityBanner`, `UpdatePrompt`, each app's home at phone + tablet | `test/goldens/` | goldens updated only via `--update-goldens` deliberately |
| Contract | `OtlpHttpJsonExporter` against `tooling/otlp_sink`; `PostHogFlagSource` and `PenguinLicenseSource` against recorded JSON fixtures | package tests | part of `make test` |
| Telemetry smoke | reference app boots with the real exporter → sink counts logs ≥1, metric points ≥1, histograms ≥1, spans ≥1 | `telemetry-validate.sh` | every commit |
| Integration | login → home, offline write → reconnect → synced | `integration_test/` per app | `e2e-android.yml` (release + manual) |
| Native | JUnit for each Kotlin plugin | `platform/android/plugins/*/android/src/test` | `ci.yml kotlin` job |
| Logging conformance | `check-logging.sh` asserts ≥1 file scanned, `PenguinLogger` used, zero `print(`/`debugPrint(` in package + app `lib/` (otlp_sink exempt) | `ci.yml dart` | every commit |

Mock data: `penguin_testing/lib/fixtures/` generators produce 3–4 items per model; `make seed-mock-data` writes them under each app's `test/fixtures/` and prints how many files were written.

## 11. Migrations

### 11.1 flutter_libs (from penguin-libs@120fb97)
- Copy `packages/flutter_libs/{lib,test,example,README.md,CHANGELOG.md,LICENSE,analysis_options.yaml,pubspec.yaml}`; drop `pubspec.lock`, `.gitignore` negation, `.version`, `.flutter-plugins-dependencies`. Add `resolution: workspace`; bump SDK constraints to the workspace values. A pub workspace has one resolution, so two of its pins move to the workspace versions: `flutter_secure_storage 9.2.4 → 11.1.1` (adapt `token_storage.dart` + its test to the v10+ API), `file_picker 8.3.7 → 12.3.0` (its `win32 ^5` clashed with secure storage's `win32 ^6`; adapt `form_field_builder.dart`), and `flutter_lints 5.0.0 → 6.0.0`; `http`, `shared_preferences`, `url_launcher`, `crypto`, `mocktail` stay. `example/` becomes a workspace member.
- Include the deprecation fix already on that commit (`form_builder_field.dart`, `form_field_builder.dart`) so `flutter analyze` is clean.
- Raise coverage 45% → ≥90%: new tests for `form_builder/*` (5 files), `sidebar_menu/{sidebar_menu,sidebar_types}`, `login_page_builder/widgets/{social_icons,social_login_buttons,cookie_consent_banner,login_footer}`, `console_version/{console_version,app_console_version,version_logger}`, `form_modal_builder/{form_field_builder,form_field_config,form_tab}`, `theme/elder_theme_data`, `login_page_builder/theme/elder_login_theme`.
- Move `penguin-libs/docs/flutter-libs/{API,README,CHANGELOG}.md` → `docs/flutter_libs/`. `docs/standards/MOBILE.md` is superseded by `docs/APP_STANDARDS.md` here.
- `dart:io` in `saml_utils.dart` stays (mobile-only repo; web is not a target). Public "Elder" names stay; `penguin_ui` wraps them.
- Commit body carries `Imported from penguin-libs@120fb97 (fix/flutter-deprecations = ae8dd73 + deprecation fix)`.

### 11.2 penguincloud (from penguincloud/services/mobile, green: analyze clean, 18/18 tests)
| Source | Destination |
|---|---|
| `lib/providers/auth_provider.dart`, `services/{api_client,auth_service,secure_storage}.dart` | deleted; replaced by `penguin_auth` (`AuthConfig.password(...)` with the existing `/api/v1/auth/{login,refresh,logout,profile}` paths) + `penguin_api` |
| `lib/config/environment.dart` | `env/{dev,beta,prod}.json` + `AppConfig.fromEnvironment`; the hardcoded `appVersion` is removed (read from `package_info_plus`) |
| `lib/app.dart`, `main.dart` | `lib/main.dart` (≤15 lines) + `lib/manifest.dart` |
| `screens/login_screen.dart` | shell login on the transitional `AuthConfig.password` path (`LoginPageBuilder` + MFA, since penguincloud has no hosted mobile login yet) with the tablet branding pane as `loginBuilder`; tracked in `docs/AUTH.md` |
| `screens/springboard_screen.dart`, `widgets/springboard_tile.dart`, `models/springboard_item.dart`, `utils/constants.dart` | `features/springboard/` (`springboard_module.dart`, `domain/springboard_item.dart`, `presentation/{springboard_screen,springboard_grid,springboard_tile}.dart`), flag `penguincloud.springboard` |
| `screens/profile_screen.dart`, `models/user.dart` | `features/profile/` (`profile_module.dart`, `domain/user.dart`, `presentation/profile_screen.dart`), flag `penguincloud.profile` |
| `widgets/adaptive_layout.dart`, duplicated amber/slate colour constants | `penguin_ui` (`AdaptiveLayout`, `PenguinTheme`) |
| `local_auth`, `provider` deps | dropped (unused / replaced) |
| Android `com.penguintech.mobile`, no permissions, debug-key release signing, no flavors | `io.penguintech.penguincloud` (never published — signed with the debug key), `INTERNET` declared, conventions from §6, flavors dev/beta/prod |
| iOS deployment target 13.0 vs Podfile 15.0 | both set to 15.0 (≥ the rules' 14.0 floor); no other iOS work |
| Tests (18) | ported to Riverpod overrides via `penguin_testing`; added: 401 → refresh → replay, springboard role filtering, auth redirect, goldens for home at phone + tablet |

### 11.3 gazer — superseded, not migrated

The survey of `waddlebot/mobile/flutter_gazer` (kept in the plan ledger for the record) found its two native plugins never registered and never streamed. That app has since been rewritten as **Gazer Mobile v2** (`waddlebot/mobile/gazer`, branch `feature/gazer-mobile-v2`: Riverpod, Pigeon bridge, RootEncoder RTMP pipeline, own JUnit5/MockK/JaCoCo Kotlin gates, container-only `make mobile-*` toolchain on Flutter 3.47.2, M1 complete, M2 planned). The waddlebot session moves it into this repo with full history and a handoff document once its last integration lands. Until then `apps/gazer` stays free. Because v2 pins Flutter 3.47.2 / Dart ≥3.13.2 and `dio`, it cannot join the 3.44.8 pub workspace on arrival; it lands as a standalone app directory with its own lockfile and toolchain, and its convergence onto `penguin_app_shell` and the shared packages is a separate spec written from the handoff.

## 12. Follow-ups outside this repo

| Repo | Change | Why |
|---|---|---|
| `penguin-libs` | remove `packages/flutter_libs`, `ci.yml:199-216`, `publish.yml:418-464` + `flutter-libs-v*` trigger, `docs/flutter-libs/`, README package table row + install snippet, `PACKAGE_PUBLISHING_STATUS.md` rows, `SECURITY.md:38` claim | package moved here |
| `penguincloud` | remove `services/mobile`, Makefile targets `setup-flutter dev-mobile test-flutter smoke-test-mobile build-flutter lint-flutter format-flutter` (+ aggregations), `tests/smoke/build/test-mobile-android.sh`, `scripts/mobile/build-android.sh`, `FLUTTER_VERSION` | app moved here |
| `waddlebot` | owned by the waddlebot session: Gazer v2 move into `penguinm` + retirement of `mobile/flutter_gazer`, `flutter-gazer.yml`, and the native Hub skeletons | app moves here |
| `admin` rules | drop "(layout PROPOSED)" in `client.md:22` once this lands; `building-mobile-apps` skill referenced by `client-flutter.md` does not exist yet — write it from `docs/APP_STANDARDS.md` | consistency |
| this repo (after the Gazer v2 handoff) | Gazer v2 convergence spec: shared shell/packages adoption, Flutter version alignment (3.47.2 vs 3.44.8), `dio` → `package:http` per the supply-chain rule, single toolchain image | v2 arrives standalone by design |

## 13. Security & observability checklist (applies to every app)

- Login is server-hosted (authorization code + PKCE in the system browser); the app never renders credentials or provider choice; the in-app password form is a documented transitional fallback per app.
- Tokens: `flutter_secure_storage` only; cleared on logout; never logged (sanitizer masks by key pattern at every level).
- No secrets in the repo or in `env/*.json`; release signing and store credentials from CI secrets as env vars.
- TLS: `https` base URLs in `beta`/`prod` env files; cleartext only in `dev` for emulator loopback, and `android:usesCleartextTraffic` limited to the `dev` flavor manifest.
- OTel: logs + metrics (histograms first) + traces from every app via the shell; endpoint from config, vendor-neutral; a dead exporter never affects the UI.
- Feature flags: every `FeatureModule` gated; unseen → OFF; license tier checked by required tier, never by boolean.
- Offline: connectivity banner, stale-data age, queued writes with dead-letter surfacing; retries back off exponentially and never retry 401/403.
- Update: non-blocking startup check; required updates block with a store link.
- Supply chain: exact pins everywhere, `check-pins.sh` in CI, no PRC-origin dependencies. Rejected during pinning: `dio` (publisher `flutter.cn`, PRC), `libausbc`/`flutter_uvc_camera` (PRC), `golden_toolkit` (discontinued), `jwt_decoder` (abandoned), `sqlite3_flutter_libs` (EOL), `semgrep-action` (archived). Publisher per package is recorded in the plan's Appendix A.
