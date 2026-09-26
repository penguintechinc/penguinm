# penguinm Monorepo Skeleton — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up `penguinm` as PenguinTech's Flutter mobile monorepo: workspace tooling, ten shared packages, one app shell, an app template, two migrated apps plus a reference app, two Android plugin packages, containerized toolchain, CI, hooks, and docs — all green under `make pre-commit`.

**Architecture:** Dart pub workspace + Melos. Apps are an `AppManifest` plus `FeatureModule`s; the shell boots core → telemetry → flags → auth → update → offline and owns routing/chrome. Cross-cutting interfaces (`TokenProvider`, `MetricsSink`, `TraceSink`) live in `penguin_core` so `api`/`offline`/`update` never import `telemetry` or `auth`.

**Tech Stack:** Flutter 3.44.8 / Dart 3.12.2, flutter_riverpod 3.4.3 (hand-written providers, zero codegen), go_router 17.5.0, package:http 1.6.0, flutter_secure_storage 11.1.1, flutter_appauth 12.1.0, sqlite3 3.6.0, connectivity_plus 7.3.1, melos 8.7.0, mason_cli 0.1.3; Kotlin 2.3.20 / AGP 9.0.1 / compileSdk 36 for plugins; Debian bookworm-slim toolchain image; GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-14-penguinm-monorepo-design.md` — every task implements a numbered spec section; read it before starting a task.

## Global Constraints

- Flutter `3.44.8` stable, Dart `>=3.12.2 <4.0.0`; pinned in `.fvmrc`, `.flutter-version`, Dockerfile, every workflow.
- Every dependency exact-pinned (no `^`/`~`/`any`/ranges); versions come ONLY from Appendix A; do not add a dependency that is not in Appendix A — stop and report instead.
- **No `dio`** (PRC publisher) — HTTP is `package:http`; **no codegen** (`build_runner`, `freezed`, `json_serializable`, `riverpod_generator`, `drift`) and **no `custom_lint`/`riverpod_lint`** — hand-written `fromJson`/providers/SQL.
- **Do not edit any `pubspec.yaml` except in the task that owns it** (T1a owns them all); a needed dep missing from your pubspec is a blocker to report, not to fix.
- Never commit. The orchestrator commits after user approval. Never push. Never `git stash`.
- 90% line coverage per package (`flutter test --coverage` → `coverage/lcov.info`), asserted by `tooling/scripts/coverage-gate.sh`.
- `flutter analyze` must report zero issues (infos included); `dart format --set-exit-if-changed .` clean.
- Every class and public function gets a 2–3 line `///` doc comment. No ASCII-art dividers. No `print(` outside `tooling/otlp_sink`.
- No secrets, tokens, or real hostnames other than `license.penguintech.io` and the three WaddleBot domains in Gazer's settings feature.
- Android: `minSdk 24`, `targetSdk 35`, `compileSdk 35`, JVM 17, applicationId `io.penguintech.<app>`, release never signed with the debug key.
- Android-only CI; `ios/` directories exist but are never built.
- Each agent works ONLY in the files its task lists; scratch files go under `<scratchpad>/<task-id>/`.
- Agent report format: verdict first line (pass/fail/blocked + what changed), ≤10 lines unless reporting errors, `path:line` refs, exact error text only.

## Waves (dependency order)

| Wave | Tasks | Runs after |
|---|---|---|
| 0 | T1a workspace + members, T1b Makefile/scripts/hooks | — (T1a ∥ T1b) |
| 1 | T2 flutter_libs green, T3 core, T4 otlp_sink, T5 android conventions, T8 toolchain image, T9 workflows, T10/T11/T12 flutter_libs tests (after T2), T13 docs | wave 0 |
| 2 | T15 telemetry, T16 api, T17 auth, T18 flags, T19 ui | T3 |
| 3 | T21 offline, T22 update | T16 |
| 4 | T23 testing | waves 2–3 |
| 5 | T24 shell, T14 template brick | T23 |
| 6 | T25 reference app, T26 penguincloud | wave 5 |
| 7 | T28 integration + pre-commit green, T29 image digest pin (post-first-push) | wave 6 |

---

### Task T1a: Workspace root and every member skeleton

**Files:**
- Create: `pubspec.yaml` (melos 8 reads its config from the root pubspec's `melos:` key — there is no `melos.yaml`), `analysis_options.yaml`, `.fvmrc`, `.flutter-version`, `VERSION`, `.gitignore` (replace), `packages/penguin_lints/{pubspec.yaml,lib/analysis_options.yaml,README.md}`
- Create (pubspec + `lib/<name>.dart` barrel + `README.md` + `test/.keep`-free minimal test that imports the barrel): `packages/{penguin_core,penguin_api,penguin_auth,penguin_telemetry,penguin_flags,penguin_offline,penguin_update,penguin_ui,penguin_testing}`, `shells/penguin_app_shell`, `tooling/otlp_sink`
- Create via `flutter create --org io.penguintech --platforms android,ios --empty`: `apps/penguin_reference`, `apps/penguincloud`; then replace each generated `pubspec.yaml`, delete generated `test/widget_test.dart`, add `env/{dev,beta,prod}.json`. (`apps/gazer` is reserved for the incoming Gazer v2 move — do not create it. No plugin packages are scaffolded — ruling R11.)
- Copy: `packages/flutter_libs/` from `git -C /home/penguin/code/penguin-libs archive 120fb97 packages/flutter_libs | tar -x --strip-components=1 -C packages/` — then delete `packages/flutter_libs/{pubspec.lock,.gitignore,.version,.flutter-plugins-dependencies}` and set `resolution: workspace` + workspace SDK constraints in `packages/flutter_libs/pubspec.yaml` and `packages/flutter_libs/example/pubspec.yaml`

**Interfaces — Produces:** a workspace where `flutter pub get` at the root succeeds with every member listed; member names exactly: `penguin_lints penguin_core penguin_api penguin_auth penguin_telemetry penguin_flags penguin_offline penguin_update penguin_ui penguin_testing penguin_app_shell flutter_libs flutter_libs_example otlp_sink penguin_reference penguincloud` (16).

Root `pubspec.yaml` shape:
```yaml
name: penguinm_workspace
description: PenguinTech mobile monorepo (Flutter). Not published.
publish_to: none
environment:
  sdk: '>=3.12.2 <4.0.0'
workspace:
  - packages/penguin_lints
  - packages/penguin_core
  # ... every member above, one per line
dev_dependencies:
  melos: <Appendix A>
```
Every member pubspec: `resolution: workspace`, `environment: {sdk: '>=3.12.2 <4.0.0', flutter: '>=3.44.8'}`, dependencies exactly per the spec §2 graph with versions from Appendix A; apps depend on `penguin_app_shell` (path: `../../shells/penguin_app_shell`) and on packages by path. Dev deps everywhere: `flutter_test` (sdk), `mocktail`, `penguin_lints` (path); packages that use widgets also `penguin_testing` (path) — except `penguin_core` and `penguin_testing` itself (no cycle).

`melos.yaml`:
```yaml
name: penguinm
repository: https://github.com/penguintechinc/penguinm
packages: [packages/*, packages/flutter_libs/example, shells/*, apps/penguin_reference, apps/penguincloud, tooling/otlp_sink]  # apps/gazer arrives with its own toolchain; listed explicitly so it is not swept in
command: { bootstrap: { runPubGetInParallel: false } }
scripts:
  analyze: { run: melos exec -c 1 -- flutter analyze --fatal-infos, description: analyze every package }
  format: { run: dart format --set-exit-if-changed . }
  test: { run: melos exec -c 4 --dir-exists=test -- flutter test --coverage --reporter=compact }
  build:android: { run: "melos exec --scope='apps/*' -- flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json" }
```
`.gitignore` (replace the seed): `.dart_tool/ build/ coverage/ .flutter-plugins .flutter-plugins-dependencies *.iml .idea/ .env* .worktrees/ .PLAN .TODO **/android/.gradle/ **/android/local.properties **/android/key.properties **/ios/Flutter/ephemeral/ **/ios/Flutter/flutter_export_environment.sh **/ios/Pods/ *.keystore *.jks /build/artifacts/` — and explicitly NOT `pubspec.lock`.
`.fvmrc`: `{"flutter": "3.44.8"}`; `.flutter-version`: `3.44.8`; `VERSION`: `0.1.0`.
`packages/penguin_lints/lib/analysis_options.yaml` per spec §4.1 minus the `riverpod_lint` line; root `analysis_options.yaml`: `include: package:penguin_lints/analysis_options.yaml` plus `analyzer: { exclude: ['**/*.g.dart', '**/*.freezed.dart', 'templates/**', '.worktrees/**'] }`.
`env/dev.json` per app: `{"PENGUIN_ENV":"prealpha","API_BASE_URL":"http://10.0.2.2:5000","OTEL_EXPORTER_OTLP_ENDPOINT":"http://10.0.2.2:4318","OTEL_EXPORTER_OTLP_PROTOCOL":"http/json","POSTHOG_HOST":"","POSTHOG_PROJECT_KEY":"","LICENSE_SERVER_URL":"https://license.penguintech.io"}`; `beta.json` with `https://<app>.penguintech.cloud` and `PENGUIN_ENV: beta`; `prod.json` with `https://<product>.app`-style placeholder domains from `penguintech-reference` (penguincloud → `https://api.penguincloud.io`, reference → `https://api.penguintech.cloud`) and `PENGUIN_ENV: prod`.

- [ ] Step 1: Write root + `packages/penguin_lints` + copy flutter_libs; run `flutter pub get` at root — expect failure listing missing members (proves the workspace list is honoured).
- [ ] Step 2: Create every member per the Files list; each barrel is `library;` + one `///` doc line; each package gets `test/<name>_barrel_test.dart` asserting the barrel imports (`test('barrel imports', () { expect(true, isTrue); })` with the import at the top).
- [ ] Step 3: `flutter pub get` at root → exit 0; `ls pubspec.lock` exists; no member has its own `pubspec.lock`.
- [ ] Step 4: `dart run melos bootstrap` → exit 0; `dart run melos list` prints 16 packages.
- [ ] Step 5: `dart run tooling/scripts/check-pins.sh` is not yet present (T1b) — instead grep: `grep -rE '^\s+[a-z_]+: [\^~]' --include=pubspec.yaml . | wc -l` → 0.
- [ ] Step 6: Report: member count, `flutter pub get` output tail (3 lines), any pubspec you could not pin.

### Task T1b: Makefile, scripts, hooks, CODEOWNERS

**Files:** Create `Makefile`, `.pre-commit-config.yaml`, `.github/CODEOWNERS`, `tooling/scripts/{install-pre-commit.sh,check-pins.sh,coverage-gate.sh,check-logging.sh,telemetry-validate.sh,new-app.sh,build-android.sh,version.sh}`, `tooling/scripts/README.md`.

**Interfaces — Produces:** make targets named exactly as spec §9; scripts with the contracts in spec §7 table. `telemetry-validate.sh` invokes `dart run otlp_sink --port 4318` (T4) and `flutter test test/telemetry_smoke_test.dart --dart-define=OTLP_SINK=http://127.0.0.1:4318` inside `apps/penguin_reference` (T25) — write it now against those names. `new-app.sh` calls `mason make penguin_app` (T14).

Load the `setup-git-hooks` skill for the hook contents. Pre-commit hook: `gitleaks protect --staged --redact`, `dart format --set-exit-if-changed` on staged `.dart`, `flutter analyze --fatal-infos` on affected packages, `zizmor .github/workflows` when workflows are staged, `hadolint tooling/docker/Dockerfile.flutter-android` when it is staged. Pre-push: `trivy fs --scanners vuln,misconfig,secret --exit-code 1 .`, `osv-scanner --lockfile pubspec.lock`, `semgrep --config p/dart --config p/kotlin --config p/secrets --error .`.

- [ ] Step 1: Write `check-pins.sh` first with tests-as-fixtures: create `<scratchpad>/T1b/fixtures/{good,bad}/pubspec.yaml`; run the script against each; expect exit 0 / exit 1 with the offending line printed, and "scanned N pubspecs" on both.
- [ ] Step 2: Write `coverage-gate.sh`: input dirs with `coverage/lcov.info`; fixture with LH/LF at 95% passes, 80% fails, LF=0 fails, zero packages fails; prints one row per package.
- [ ] Step 3: Write `check-logging.sh`: scans `packages/*/lib shells/*/lib apps/*/lib`; asserts files scanned ≥1; fails on `print(` / `debugPrint(` / `developer.log(`; passes when `PenguinLogger` is imported somewhere in `shells/`.
- [ ] Step 4: Write the remaining scripts (`set -euo pipefail`, Bash 3.2, usage text, non-zero on any failure).
- [ ] Step 5: Write `Makefile` (`.DEFAULT_GOAL := help`, `help` target lists all), `.pre-commit-config.yaml`, `CODEOWNERS` (`*  @Chromeninja @PenguinzTech`).
- [ ] Step 6: `bash -n` every script; `shellcheck` if installed; `make help` prints every target in spec §9; `tooling/scripts/install-pre-commit.sh --verify` exits 1 before install and 0 after `make install-hooks`.
- [ ] Step 7: Report: targets count, scripts count, fixture results table.

### Task T2: flutter_libs green in the workspace

**Files:** Modify `packages/flutter_libs/**` (already copied by T1a); Create `docs/flutter_libs/{API.md,README.md,CHANGELOG.md}` (moved from `/home/penguin/code/penguin-libs/docs/flutter-libs/`, names de-hyphenated inside).

- [ ] Step 0: T1a moved `flutter_secure_storage` to 11.1.1 — update `lib/src/login_page_builder/utils/token_storage.dart` and `test/login_page_builder/token_storage_test.dart` to the v10+ API (`AndroidOptions`/`IOSOptions` constructors changed; `encryptedSharedPreferences` option removed — read the package CHANGELOG under `~/.pub-cache/hosted/pub.dev/flutter_secure_storage-11.1.1/CHANGELOG.md`).
- [ ] Step 1: `cd packages/flutter_libs && flutter analyze --fatal-infos` → fix every remaining info (T1a copied the deprecation fix; expect only lint-rule infos from the stricter `penguin_lints`, e.g. missing docs → add `///` comments, `require_trailing_commas` → format).
- [ ] Step 2: `dart format .`; `flutter test` → 144/144.
- [ ] Step 3: Move docs; update `packages/flutter_libs/README.md` install section to the workspace path dependency.
- [ ] Step 4: Report: analyze issue count before/after, test count.

### Task T3: penguin_core

**Files:** `packages/penguin_core/lib/penguin_core.dart` (barrel), `lib/src/{app_config.dart,app_config_controller.dart,environment.dart,result.dart,failure.dart,logger.dart,console_logger.dart,log_sanitizer.dart,clock.dart,token_provider.dart,sinks.dart,providers.dart}`, tests `test/{app_config,app_config_controller,result,failure,log_sanitizer,console_logger,clock,sinks}_test.dart`.

**Interfaces — Produces:** exactly spec §4.2 (all names/signatures), plus `KnownApps` (`lib/src/known_apps.dart`): a `const` list of `KnownApp(id, displayName, applicationId, productKey, family)` for the fourteen apps in spec §1.1, with `KnownApps.byId(String)`; tests assert 14 entries, unique ids/applicationIds, `applicationId == 'io.penguintech.$id'`. `AppConfig.fromEnvironment` reads `String.fromEnvironment` keys; missing `API_BASE_URL` → `ArgumentError`. `LogSanitizer.sanitize` is recursive over nested maps/lists and masks values whose key matches the pattern case-insensitively; `maskValue('abcdef1234')` → `'****1234'`, values ≤4 chars → `'****'`. `Result.fold`, `map`, `isOk`, `valueOrNull`. `AppConfigController` persists the override via a `KeyValueStore` interface (`Future<String?> read(String)`, `Future<void> write(String, String)`, `remove`) with `SharedPreferencesStore` and `InMemoryKeyValueStore` implementations in this package.

- [ ] Step 1: Tests first (named): `sanitize masks token keys at any depth`, `sanitize leaves non-sensitive keys`, `maskValue keeps last four`, `Result fold ok/err`, `AppConfig.fromEnvironment throws without API_BASE_URL`, `AppConfig.fromEnvironment parses OTLP headers k=v,k=v`, `isLicenseBypassDomain for penguintech.cloud and <product>.app`, `AppConfigController.setApiBaseUrl persists and updates state`, `ConsoleLogger emits single-line JSON with level and sanitized attrs`, `Noop sinks are no-ops`.
- [ ] Step 2: Run → fail (missing symbols). Implement. Run → pass. `flutter test --coverage` → LH/LF ≥ 90%.
- [ ] Step 3: `flutter analyze --fatal-infos` clean; `dart format` clean. Report counts.

### Task T4: tooling/otlp_sink

**Files:** `tooling/otlp_sink/{bin/otlp_sink.dart,lib/otlp_sink.dart,lib/src/{server.dart,counters.dart},test/server_test.dart,README.md}`.

**Produces:** `dart run otlp_sink --port 4318` serves `POST /v1/logs|/v1/metrics|/v1/traces` (OTLP JSON), `GET /summary` → `{"logRecords":N,"metricDataPoints":N,"histograms":N,"spans":N}`, `POST /reset`. Counting rules: log records = length of every `resourceLogs[].scopeLogs[].logRecords[]`; metric data points = sum over `metrics[].{sum,gauge,histogram}.dataPoints[]`; histograms = metrics with a `histogram` key; spans = `resourceSpans[].scopeSpans[].spans[]`. Uses `dart:io` HttpServer only (no deps beyond `args`). `print` allowed here.

- [ ] Tests: `counts log records`, `counts sum and histogram data points separately`, `counts spans`, `reset zeroes`, `malformed JSON → 400 and counters unchanged`. Coverage ≥90%. Report.

### Task T5: Android conventions applied to apps and plugins

**Files:** Create `platform/android/gradle/{libs.versions.toml,penguin-android.gradle.kts,signing.gradle.kts,README.md}`, `platform/android/README.md` (native-module policy; `plugins/` directory is created empty with a `.gitkeep`-free README only), `platform/ios/README.md`; Modify `apps/{penguin_reference,penguincloud}/android/{settings.gradle.kts,app/build.gradle.kts,app/src/main/AndroidManifest.xml,app/src/dev/AndroidManifest.xml}`, `apps/*/android/gradle.properties`.

**Produces:** spec §6 exactly (`compileSdk 36`, `targetSdk 36`, `minSdk 24`, NDK `28.2.13676358`, AGP `9.0.1`, Kotlin `2.3.20` — what `flutter create` on 3.44.8 already generated; the catalog pins them explicitly); flavors `dev`/`beta`/`prod` (dimension `env`), `applicationIdSuffix ".dev"/".beta"`, `resValue "string" "app_name"` per flavor; `INTERNET` in every main manifest; `android:usesCleartextTraffic="true"` only in `src/dev/AndroidManifest.xml`; `signing.gradle.kts` fails the `release` build type when any `PENGUIN_ANDROID_*` env var is missing with the message `Release signing requires PENGUIN_ANDROID_KEYSTORE_PATH, PENGUIN_ANDROID_KEYSTORE_PASSWORD, PENGUIN_ANDROID_KEY_ALIAS, PENGUIN_ANDROID_KEY_PASSWORD`. No plugin test deps yet (no plugin packages exist — R11).

- [ ] Step 1: Write the convention files; wire one app; run `cd apps/penguin_reference/android && ./gradlew -q help --offline || ./gradlew -q help` — Java is NOT installed on this host, so instead validate inside the toolchain image once T8 exists; until then: `kotlinc` absent too — validate with `flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json` inside `docker run --rm -v "$PWD":/work -w /work ghcr.io/cirruslabs/flutter:3.44.8 ...` is NOT allowed (unpinned third-party image). Therefore: mark Gradle validation as **deferred to T28** (runs in the T8 image) and validate now by static review + `flutter analyze` + `grep` assertions listed in Step 2.
- [ ] Step 2: Assertions: every `apps/*/android/app/build.gradle.kts` contains `apply(from = "../../../../platform/android/gradle/penguin-android.gradle.kts")` and `signing.gradle.kts`; every main manifest contains `android.permission.INTERNET`; only `src/dev/AndroidManifest.xml` contains `usesCleartextTraffic`; `applicationId = "io.penguintech.<app>"`; `gradle.properties` has no `-Xmx8G`.
- [ ] Step 3: Report with the assertion table and "Gradle execution deferred to T28".

### Task T6: DROPPED

Ruling R11 (2026-09-14): Gazer Mobile v2 (a full rewrite, M1 complete, in `waddlebot` on `feature/gazer-mobile-v2`) is being moved into this repo by the waddlebot session with its history and a handoff document. The old `mobile/flutter_gazer` app and its never-registered plugin stubs are therefore not migrated, and no plugin packages are scaffolded from them. Gazer work in `penguinm` resumes from that handoff.

### Task T7: DROPPED

Ruling R11 (2026-09-14): Gazer Mobile v2 (a full rewrite, M1 complete, in `waddlebot` on `feature/gazer-mobile-v2`) is being moved into this repo by the waddlebot session with its history and a handoff document. The old `mobile/flutter_gazer` app and its never-registered plugin stubs are therefore not migrated, and no plugin packages are scaffolded from them. Gazer work in `penguinm` resumes from that handoff.

### Task T8: Toolchain image + toolchain-image workflow

**Files:** `tooling/docker/Dockerfile.flutter-android`, `tooling/docker/README.md`, `.github/workflows/toolchain-image.yml`, `.hadolint.yaml`.

**Produces:** spec §7 image. Use `moby-expert` conventions: `FROM debian:bookworm-slim@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171`; `ARG FLUTTER_VERSION=3.44.8 FLUTTER_REVISION=058e0af2c2 CMDLINE_TOOLS_ZIP=commandlinetools-linux-15859902_latest.zip CMDLINE_TOOLS_SHA256=4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583 ANDROID_PLATFORM=36 BUILD_TOOLS=36.0.0 NDK_VERSION=28.2.13676358`; also install `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`-free (no desktop) — `clang`/`cmake`/`ninja` are needed by `sqlite3`'s native-asset build for host tests; apt with `--no-install-recommends`, versions pinned; `sha256sum -c` on the cmdline-tools zip; `git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter /opt/flutter && test "$(git -C /opt/flutter rev-parse --short=10 HEAD)" = "${FLUTTER_REVISION}"`; `flutter config --no-analytics --enable-android`; `flutter precache --android`; `yes | sdkmanager --licenses`; `useradd -u 1000 appuser`; `USER 1000`; `WORKDIR /work`; `HEALTHCHECK NONE`; stages `toolchain` (published) → `deps` → `analyze` → `test` → `build` → `output FROM scratch`. Build locally: `docker build --target toolchain -f tooling/docker/Dockerfile.flutter-android -t penguinm/flutter-android:local .` must succeed (rootful Docker on this host is a known deviation; note it).

- [ ] Step 1: Write Dockerfile; `hadolint` → 0 findings; `docker build --target toolchain` → success; `docker run --rm penguinm/flutter-android:local flutter --version` prints 3.44.8; `docker run --rm penguinm/flutter-android:local id -u` → 1000.
- [ ] Step 2: `toolchain-image.yml`: on push (paths `tooling/docker/**`) + `workflow_dispatch`; `docker/setup-buildx-action`, `docker/login-action` (GHCR, `GITHUB_TOKEN`), `docker/build-push-action` (all SHA-pinned from Appendix A), tag `ghcr.io/penguintechinc/penguinm/flutter-android:3.44.8-<epoch64>` and `:3.44.8`, output digest to the job summary. `zizmor` → 0 findings.
- [ ] Step 3: Report: build time, image size, hadolint/zizmor counts.

### Task T9: CI, security, CodeQL, release, e2e workflows

**Files:** `.github/workflows/{ci.yml,security.yml,release-android.yml,e2e-android.yml}` (no `codeql.yml` yet — there is no first-party Kotlin beyond generated `MainActivity.kt`; it is added with the Gazer v2 intake — R11), `tooling/security/requirements.in` (`semgrep==<latest on PyPI today>`) + `tooling/security/requirements.txt` generated with `uv pip compile --generate-hashes tooling/security/requirements.in -o tooling/security/requirements.txt`, `.github/PULL_REQUEST_TEMPLATE.md`. `.github/dependabot.yml` is NOT created (manual dependency review policy).

**Produces:** spec §8 exactly; every `uses:` SHA-pinned with `# vX.Y.Z` comment from Appendix A; `android` jobs run `container: { image: ghcr.io/penguintechinc/penguinm/flutter-android:3.44.8 }` with a comment `# TODO-PIN: replace tag with digest after first toolchain-image publish (T29)` — this is the single permitted deferred pin, tracked by T29; `release-android.yml` uses `on: release: types: [prereleased, released]`, matrix `app: [penguin_reference, penguincloud]` (gazer joins after its intake), env from secrets (`PENGUIN_ANDROID_KEYSTORE_B64` decoded to a temp file → `PENGUIN_ANDROID_KEYSTORE_PATH`), Play upload step conditional on `github.event.action` for track, failing when secrets are empty (`test -n "$…"`). No `|| true` anywhere; `permissions:` minimal per job.

- [ ] `zizmor .github/workflows` → 0 findings; `actionlint` if installed; `grep -c 'uses:' | grep -v '@[0-9a-f]\{40\}'` → 0 unpinned. Report.

### Task T10: flutter_libs tests — form_builder

**Files:** Create `packages/flutter_libs/test/form_builder/{form_builder_test.dart,form_builder_field_test.dart,form_builder_modal_test.dart,form_builder_types_test.dart}`; extend `form_builder_controller_test.dart`.

- [ ] Widget tests covering every field type rendered by `form_builder_field.dart` (text, password, email, number, dropdown, radio, checkbox, switch, date, multiline — enumerate from `FormFieldType`), validation callbacks, modal open/submit/cancel, controller value round-trips. Target: each of the 5 files ≥90% lines (`lcov --list` per file). Report per-file LH/LF.

### Task T11: flutter_libs tests — sidebar + social + banners

**Files:** Create `test/sidebar_menu/{sidebar_menu_test.dart,sidebar_types_test.dart}`, `test/login_page_builder/{social_icons_test.dart,social_login_buttons_test.dart,cookie_consent_banner_test.dart,login_footer_test.dart}`.

- [ ] Widget tests: menu renders categories/items, role filtering hides items, selection callback, collapsed/expanded; every `SocialProvider` icon paints; buttons call `onPressed` with provider; cookie banner accept/reject/customize flows and persisted state; footer links use `url_launcher` mock. Per-file ≥90%. Report.

### Task T12: flutter_libs tests — console_version, form_modal_builder remainder, theme

**Files:** Create `test/console_version/{console_version_test.dart,app_console_version_test.dart,version_logger_test.dart}`, `test/form_modal_builder/{form_field_builder_test.dart,form_field_config_test.dart,form_tab_test.dart}`, `test/theme/{elder_theme_data_test.dart,elder_login_theme_test.dart}`.

- [ ] Tests: `AppConsoleVersion` fetches `/version` via injected `http.Client` (mock 200/500/timeout), `VersionLogger` output shape, `ConsoleVersion` overlay renders/hides; every branch of `form_field_builder.dart` (291 LF — the largest gap); `ElderThemeData.copyWith/lerp`, extension registration. Per-file ≥90%. Report.

### Task T13: Docs, CLAUDE.md, READMEs

**Files:** `README.md` (replace), `CLAUDE.md`, `apps/README.md`, `docs/{ARCHITECTURE.md,APP_STANDARDS.md,ADDING_AN_APP.md,AUTH.md,NATIVE_MODULES.md,OFFLINE.md,RELEASE.md,TESTING.md,README.md}`. `docs/AUTH.md` = the hosted-login model (spec §4.5): sequence (app → system browser → product login page [OIDC/SAML/local chosen server-side] → redirect `io.penguintech.<app>://oauth/callback` → token exchange), the backend contract every product must expose, the per-app `client_id` convention, family SSO via the shared browser session, and the table of apps still on the transitional in-app password fallback (penguincloud today). `docs/APP_STANDARDS.md` states: modules and flag keys mirror the product's server/web UI modules (same `<product>.<module>` keys), one shared design system with branding limited to `AppBrand`.

**Produces:** `apps/README.md` and `CLAUDE.md` carry the app roster table from spec §1.1 verbatim (14 apps: dir, product key, family, purpose, anticipated native modules) and the naming rules from §5. `CLAUDE.md` follows the house shape (headings: "DO NOT MODIFY THIS FILE OR `.claude/` STANDARDS", "Global vs Local Rules and Skills", "MCP Servers", "Setup Script") **plus** a "Repository Layout" section (spec §2 tree) and a "Per-App Folder Standard" section containing spec §5 verbatim, and a "Commands" section listing `make` targets. `docs/APP_STANDARDS.md` supersedes `penguin-libs/docs/standards/MOBILE.md` (carry its form-factor table, native-module policy, testing matrix; fix stale pins to 3.44.8 / Appendix A). `docs/NATIVE_MODULES.md` = justification policy + template. `docs/OFFLINE.md` = what works offline per app (table, filled by T25–T27 later — leave a per-app subsection with the reference app filled and the others listing "see apps/<app>/README.md"). Terse house style: tables/bullets, no paragraphs.

- [ ] Every internal link resolves (`grep -o '](\([^)]*\.md\)' | sort -u` → each exists). Report file list + link count checked.

### Task T15: penguin_telemetry

**Files:** `packages/penguin_telemetry/lib/penguin_telemetry.dart`, `lib/src/{config.dart,telemetry.dart,logger.dart,meter.dart,instruments.dart,tracer.dart,span.dart,ids.dart,queue.dart,exporter.dart,otlp_json.dart,otlp_http_json_exporter.dart,noop_exporter.dart,sinks.dart,standard_metrics.dart,providers.dart}`, tests `test/{otlp_json,otlp_http_json_exporter,queue,logger,meter,tracer,span,telemetry,sinks}_test.dart`, `test/contract/otlp_sink_contract_test.dart` (starts `tooling/otlp_sink` as a `Process`, exports, asserts `/summary` counts — tag `@Tags(['contract'])`).

**Produces:** spec §4.3 exactly. OTLP JSON shapes: logs `{resourceLogs:[{resource:{attributes:[{key,value:{stringValue}}]},scopeLogs:[{scope:{name,version},logRecords:[{timeUnixNano,severityNumber,severityText,body:{stringValue},attributes:[...],traceId?,spanId?}]}]}]}`; metrics with `sum{dataPoints[{startTimeUnixNano,timeUnixNano,asDouble,attributes}],isMonotonic:true,aggregationTemporality:2}`, `histogram{dataPoints[{count,sum,bucketCounts,explicitBounds,...}],aggregationTemporality:2}`, `gauge{dataPoints}`; traces `{resourceSpans:[{resource,scopeSpans:[{scope,spans:[{traceId(32 hex),spanId(16 hex),parentSpanId?,name,kind,startTimeUnixNano,endTimeUnixNano,attributes,status:{code}}]}]}]}`. IDs from `Random.secure()`. `defaultMsBoundaries = [5,10,25,50,100,250,500,1000,2500,5000,10000]`.

- [ ] Tests first: encoding golden JSON for one log/one counter/one histogram/one span; queue drop-oldest and `droppedCount`; exporter POSTs to `/v1/logs` with headers and returns failure (no throw) on 500/timeout; `Telemetry.start` with `NoopExporter` when endpoint null; logger sanitizes attributes; `trace()` ends span on exception and records error; `TelemetryMetricsSink.histogram` records; contract test passes against the real sink. Coverage ≥90% excluding the contract test. Report.

### Task T16: penguin_api

**Files:** `packages/penguin_api/lib/penguin_api.dart`, `lib/src/{client.dart,retry_policy.dart,middleware/{auth_client.dart,retry_client.dart,trace_client.dart,sanitized_log_client.dart},failure_mapper.dart,client_version_info.dart,providers.dart}`, tests `test/{client,retry_policy,auth_client,retry_client,trace_client,sanitized_log_client,failure_mapper,client_version_info}_test.dart` using `MockClient` from `package:http/testing.dart` (write `test/support/scripted_client.dart`: a `MockClient` fed by a queue of scripted responses that also records every request).

**Produces:** spec §4.4 exactly (with `MetricsSink`/`TraceSink` from core; `package:http`, never dio). Each middleware is an `http.BaseClient` wrapping an inner client. `RetryPolicy.delayFor(attempt, rng)` = `min(maxDelay, baseDelay * multiplier^(attempt-1))` ± up to 20% jitter. `AuthClient` replays once after a successful `refresh()` (buffer request bodies so they can be re-sent); `RetryClient` honours `Retry-After` seconds when present (write our own — `package:http/retry.dart` cannot see the request method in `when`). `SanitizedLogClient` logs method/path/status/duration at DEBUG only and never bodies unless `logBodies: true` (then sanitized). `mapFailure` table per spec. Export `apiClientProvider = Provider<PenguinApiClient>((_) => throw UnimplementedError())`.

- [ ] Tests first: retry on 503 then success (2 requests seen), no retry on 401, no retry on POST without `Idempotency-Key`, backoff sequence deterministic with seeded rng, 401 → refresh → replay succeeds (body re-sent intact), 401 → refresh fails → `AuthEvent.unauthenticated` emitted and `AuthFailure` returned, `traceparent` header injected and histogram recorded with `http.response.status_code`, `ClientException` → `NetworkFailure`, timeout → `NetworkFailure`, `fetchClientVersion` parses JSON, `setBaseUrl` affects next request. Coverage ≥90%. Report.

### Task T17: penguin_auth

**Files:** `packages/penguin_auth/lib/penguin_auth.dart`, `lib/src/{auth_config.dart,jwt_claims.dart,session.dart,auth_state.dart,login_request.dart,auth_backend.dart,hosted_login_backend.dart,app_auth_facade.dart,password_auth_backend.dart,session_store.dart,auth_controller.dart,redirect.dart,providers.dart}`, tests for each (`jwt_claims_test` uses hand-built base64url JWTs — decoding is `dart:convert` only, no JWT package; `hosted_login_backend_test` mocks `flutter_appauth` via the abstract `AppAuthFacade` (`authorizeAndExchangeCode`, `token`, `endSession`) with a `FlutterAppAuthFacade` production adapter; `password_auth_backend_test` uses `MockClient` from `package:http/testing.dart`; `auth_controller_test` uses `ProviderContainer` + `FakeClock` — define a local `test/support/fake_clock.dart` since `penguin_testing` comes later).

**Produces:** spec §4.5 exactly — the DEFAULT backend is `HostedLoginBackend` (authorization code + PKCE in the system browser; discovery from `<issuer>/.well-known/openid-configuration` when `authorizationEndpoint`/`tokenEndpoint` are null; `endSession` on logout when available; the app never renders a credential form). `PasswordAuthBackend` is the transitional fallback. `JwtClaims.decode` handles missing padding, `scope` as space-separated string or list, `aud` string or list; never validates signature (document why). `AuthController.initialize()` → loads session; expired with refresh token → `refresh`; schedules a `Timer` at `exp - 60s` via `Clock`; `logout()` always clears the store even if backend logout fails (logs WARN). `PasswordAuthBackend` posts `{email,password,mfa_code?}` and accepts either `{access_token,refresh_token,expires_in}` or flutter_libs `LoginResponse` JSON (`token`/`refreshToken`/`user`).

- [ ] Tests first: decode standard claims, expired/leeway, `hasScope`, session JSON round-trip, store save/load/clear with `FlutterSecureStorage` mocked via its platform channel (`FlutterSecureStorage.setMockInitialValues`), controller state transitions (unknown→unauthenticated, login ok→authenticated, refresh failure→expired, logout→unauthenticated), scheduled refresh fires via `FakeClock` advance, `authRedirect` matrix (unauth on protected → login; auth on login → home; null otherwise), hosted backend maps the facade's token response to `Session`, uses explicit endpoints when given and discovery otherwise, cancelled browser flow → `AuthFailure` without state corruption, logout calls `endSession` then clears. Coverage ≥90%. Report.

### Task T18: penguin_flags

**Files:** `packages/penguin_flags/lib/penguin_flags.dart`, `lib/src/{config.dart,license_tier.dart,flag_source.dart,posthog_flag_source.dart,license_source.dart,penguin_license_source.dart,license_entitlement.dart,flag_cache.dart,feature_flags.dart,feature_gate.dart,providers.dart}`, tests for each + `test/fixtures/{posthog_decide.json,license_entitlement.json}`.

**Produces:** spec §4.6 exactly. **Load the `integrating-license-server` skill** for the license endpoints, request/response shapes, and tier semantics; implement `PenguinLicenseSource` against them; record the endpoint paths you used in the package README. `FeatureFlags.isEnabled` asserts the key prefix equals `productKey.` (assertion error in debug, `false` in release). `initialize`: cache load → state; then background refresh with `unawaited` + error → WARN + `lastRefreshed` unchanged. `tier`: `bypassDomain ? enterprise : entitlement?.tier ?? cached ?? free`.

- [ ] Tests first: unseen flag false, cached flags served before refresh completes, refresh failure keeps cache, PostHog decide parsing (bool + variant string → enabled), license fixture → tier, bypass domain → enterprise, `hasTier` ordering, `FeatureGate` shows child/fallback and reacts to `changes`, key-prefix assertion. Coverage ≥90%. Report.

### Task T19: penguin_ui

**Files:** `packages/penguin_ui/lib/penguin_ui.dart`, `lib/src/{theme.dart,form_factor.dart,navigation_destination_spec.dart,responsive_scaffold.dart,adaptive_layout.dart,error_view.dart,loading_view.dart,empty_view.dart}`, tests + `test/goldens/*.png` generated with `--update-goldens` once and committed (Linux fonts: use `Ahem`-free approach by loading `Roboto` from the Flutter SDK cache via `FontLoader` in `test/flutter_test_config.dart`, and document that goldens are Linux-rendered).

**Produces:** spec §4.9 exactly, including `AppBrand`. `PenguinTheme.dark()` seeds `ColorScheme.fromSeed(seedColor: ElderColors.primaryGold-equivalent, brightness: dark)` and registers `ElderThemeData` extension; surfaces slate; `PenguinTheme.light()` symmetric.

- [ ] Tests: `FormFactor.of` at 599/600/899/900 widths; scaffold shows `NavigationBar` <600, `NavigationRail` 600–899, `SidebarMenu` ≥900 with detail slot; `AdaptiveLayout` picks builder; `ErrorView` retry callback; goldens ×3 sizes for the scaffold. Coverage ≥90%. Report.

### Task T21: penguin_offline

**Files:** `packages/penguin_offline/lib/penguin_offline.dart`, `lib/src/{connectivity_monitor.dart,connectivity_status.dart,offline_database.dart,cached_entry.dart,offline_store.dart,sqlite_offline_store.dart,pending_write.dart,sync_queue.dart,sync_report.dart,widgets/{connectivity_banner.dart,stale_data_chip.dart},providers.dart}`, tests using `OfflineDatabase.inMemory()` (`sqlite3.openInMemory()`).

**Produces:** spec §4.7 exactly — `package:sqlite3` 3.6.0 with parameterised statements, `PRAGMA user_version` migrations (v1 creates both tables), no codegen. `sqlite3` 3.x builds its native library through Dart build hooks; if `flutter test` on this host fails to build it (no C toolchain), load the system library in tests only via `open.overrideFor(OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'))` from `package:sqlite3/open.dart` inside `test/flutter_test_config.dart`, and say so in the report. `ConnectivityMonitor` maps `connectivity_plus` results: any of wifi/mobile/ethernet/vpn → online, none → offline. `SyncQueue.drain()` processes FIFO, per-item backoff via `RetryPolicy`, 401/403 → stop draining and emit nothing further (auth will handle), other 4xx (except 408/429) → dead-letter, 5xx/timeout → retry up to `maxAttempts` then dead-letter; `depth` gauge via `MetricsSink.gauge('sync.queue.depth')` after every change. Widgets read providers.

- [ ] Tests first: store put/get/list/age, queue enqueue → depth stream, drain success order, dead-letter on 422 with `deadLetters` emission, retry then dead-letter on repeated 503, auto-drain on offline→online transition (fake monitor), banner visible only offline, chip formats "just now/5m ago/2h ago/3d ago". Coverage ≥90%. Report.

### Task T22: penguin_update

**Files:** `packages/penguin_update/lib/penguin_update.dart`, `lib/src/{update_status.dart,update_checker.dart,update_prompt.dart,store_url.dart,providers.dart}`, tests.

**Produces:** spec §4.8. `storeUrlFor(applicationId, ClientVersionInfo)` → `info.storeUrl ?? Uri.parse('market://details?id=$applicationId')`. Version compare via `pub_semver` (`Version.parse` tolerant of a `+build` suffix; strip it).

- [ ] Tests: up to date, available, required (current < minimum), API failure → unknown without throw, timeout 5s enforced via fake adapter delay + `FakeAsync`, prompt shows banner with two actions / dialog non-dismissible for required, launches store URL via mocked `url_launcher` platform channel. Coverage ≥90%. Report.

### Task T23: penguin_testing

**Files:** `packages/penguin_testing/lib/penguin_testing.dart`, `lib/src/{fake_clock.dart,fake_token_provider.dart,fake_auth_backend.dart,fake_flag_source.dart,fake_license_source.dart,in_memory_flag_cache.dart,in_memory_telemetry_exporter.dart,fake_connectivity_monitor.dart,in_memory_offline_store.dart,fake_update_checker.dart,scripted_http_client.dart,golden.dart,otlp_sink_client.dart,fixtures/{users.dart,springboard_items.dart,client_versions.dart,communities.dart,members.dart,chat_messages.dart}}`, tests for every fake (yes, fakes get tests: ≥90%). `scripted_http_client.dart` generalises T16's test helper (`ScriptedHttpClient` built on `MockClient`: queue responses, record requests, optional per-request delay).

**Produces:** spec §4.11 names. `pumpPenguinApp` depends on the shell (T24) — define it here against the shell's public API from spec §4.10 (`AppManifest`, `PenguinApp`) and mark the file `// ignore_for_file: depend_on_referenced_packages` is NOT acceptable — instead: `penguin_testing` does NOT depend on the shell; `pumpPenguinApp` lives in the shell's own `lib/testing.dart` (T24). Remove it from this task. Fixtures: 4 items each, deterministic IDs (`user-0001`…).

- [ ] Tests: each fake's scripted behaviour; exporter `expectHistogram` passes/fails correctly; fixtures counts = 4. Report.

### Task T24: shells/penguin_app_shell

**Files:** `shells/penguin_app_shell/lib/penguin_app_shell.dart`, `lib/testing.dart` (exports `pumpPenguinApp`), `lib/src/{app_manifest.dart,feature_module.dart,bootstrap.dart,bootstrap_result.dart,penguin_app.dart,router.dart,default_login.dart,chrome.dart,run_penguin_app.dart,providers.dart}`, tests `test/{bootstrap,router,penguin_app,default_login,feature_module}_test.dart` using `penguin_testing` fakes; `test/goldens/` for the chrome at phone + tablet.

**Produces:** spec §4.10 exactly, including `SiblingApp`/`SiblingAppLauncher`/`LaunchOutcome` (`lib/src/sibling_apps.dart`; `UrlLauncher` is a one-method abstraction over `url_launcher`'s `canLaunchUrl`/`launchUrl` so tests inject a fake): deep link first, store fallback, never throws; `AppManifest.siblings`. `Bootstrap.run` returns overrides for: `appConfigProvider` (initial), `telemetryProvider`, `loggerProvider`, `metricsSinkProvider`, `traceSinkProvider`, `featureFlagsProvider`, `authBackendProvider`, `apiClientProvider` (define in `penguin_api` providers — T16 exports `apiClientProvider = Provider<PenguinApiClient>((_) => throw UnimplementedError())`), `connectivityMonitorProvider`, `syncQueueProvider`, `updateStatusProvider`. Every step wrapped in `try/catch` → `BootstrapWarning(step, error)` + WARN log. `router.dart` builds `GoRouter` from enabled modules (`ref.watch(flagProvider(module.flagKey))`), `ShellRoute` with `ResponsiveScaffold` destinations from modules, `redirect: authRedirect(...)`, `refreshListenable` from auth state. `default_login.dart`: `HostedLoginScreen` is the default (brand name/logo, one "Continue to sign in" button → `LoginRequest.interactive()`, inline error + retry, NO credential fields); only when the manifest's auth is `AuthConfig.password` does it wrap flutter_libs `LoginPageBuilder` with `LoginApiConfig(loginUrl: config.apiBaseUrl + auth.loginPath)` and `onLoginSuccess → controller.login(LoginRequest.fromLoginResponse(r))`. `AppManifest.brand` (`AppBrand`) is the only per-app styling input — `PenguinTheme` is applied unchanged. `chrome.dart`: `ConnectivityBanner` + `UpdatePrompt` + `ConsoleVersion` (non-prod) stacked above the router outlet. `pumpPenguinApp(tester, manifest, {overrides})` pumps `ProviderScope(overrides: [...fakes, ...overrides], child: PenguinApp(manifest))`.

- [ ] Tests first: bootstrap with all fakes produces every override and zero warnings; exporter failure → warning + Noop; flag OFF hides module route (navigating returns 404 page) and destination; auth redirect end-to-end (pump unauthenticated → login page; fake login → home); `app.startup.duration` histogram recorded in `InMemoryTelemetryExporter`; goldens. Coverage ≥90%. Report.

### Task T14: templates/penguin_app mason brick + new-app.sh integration

**Files:** `templates/penguin_app/{brick.yaml,README.md,__brick__/{pubspec.yaml,README.md,CHANGELOG.md,env/{dev,beta,prod}.json,lib/main.dart,lib/manifest.dart,lib/features/home/{home_module.dart,domain/greeting.dart,presentation/home_screen.dart,presentation/home_providers.dart},test/features/home/{home_module_test.dart,home_screen_test.dart},test/fixtures/greetings.dart,test/telemetry_smoke_test.dart,integration_test/app_test.dart}}`, `templates/README.md`; Modify `tooling/scripts/new-app.sh` (T1b wrote it) only if a flag name must change.

**Produces:** brick vars `name` (snake), `product_key`, `display_name`, `org` (default `io.penguintech`), `api_base_url_dev` (default `http://10.0.2.2:5000`). Generated `main.dart` is exactly:
```dart
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'manifest.dart';

/// Entry point — all wiring lives in the shell; see manifest.dart.
Future<void> main() => runPenguinApp(buildManifest());
```
`telemetry_smoke_test.dart`: reads `OTLP_SINK` from `String.fromEnvironment`; skipped (with reason printed) when empty; otherwise boots via `Bootstrap.run` with a real `OtlpHttpJsonExporter` to the sink, logs one INFO, records one histogram, one span, flushes, then asserts `/summary` counts ≥1 each via `OtlpSinkClient`.

- [ ] `mason make` into `<scratchpad>/T14/out` with sample vars → `flutter analyze` and `flutter test` pass inside the workspace only after T25 registers it; here: verify generation and that `dart format` is clean on output. Report.

### Task T25: apps/penguin_reference

**Files:** regenerate `apps/penguin_reference/{lib,test,env,README.md,CHANGELOG.md,integration_test}` from the brick via `tooling/scripts/new-app.sh --overwrite penguin_reference penguinm "Penguin Reference"` (add `--overwrite` to the script if missing — coordinate: T1b owns the script; T25 may add this flag), keep T1a's pubspec/android; add a second feature `features/offline_demo/` (list of `CachedEntry` notes, add note → `SyncQueue.enqueue`, shows `StaleDataChip` + dead-letter snackbar) gated by `penguinm.offline_demo`.

- [ ] `flutter analyze`, `flutter test --coverage` ≥90%, goldens home phone/tablet, `make smoke-test` passes including `telemetry-validate.sh` (needs T4 + T1b). Report counts and the telemetry summary JSON.

### Task T26: apps/penguincloud migration

**Files:** `apps/penguincloud/{lib/main.dart,lib/manifest.dart,lib/features/springboard/**,lib/features/profile/**,test/**,integration_test/login_flow_test.dart,README.md,CHANGELOG.md,docs/}`; Modify `android/app/src/main/AndroidManifest.xml` label; iOS deployment target 15.0 in `ios/Podfile` + `project.pbxproj`.

Source: `/home/penguin/code/penguincloud/services/mobile` — follow spec §11.2 mapping table exactly. Keep the springboard tile behaviour (SnackBar on tap) and role filtering; port the tablet login branding pane as `loginBuilder`.

- [ ] Port tests to Riverpod overrides (`ProviderScope` + `penguin_testing`), add the four new tests listed in §11.2, goldens. `flutter analyze` clean, coverage ≥90%. `README.md`: offline table (springboard is read-only cached; profile requires connectivity), env table, run commands. Report.

### Task T27a: DROPPED

Ruling R11 (2026-09-14): Gazer Mobile v2 (a full rewrite, M1 complete, in `waddlebot` on `feature/gazer-mobile-v2`) is being moved into this repo by the waddlebot session with its history and a handoff document. The old `mobile/flutter_gazer` app and its never-registered plugin stubs are therefore not migrated, and no plugin packages are scaffolded from them. Gazer work in `penguinm` resumes from that handoff.

### Task T27b: DROPPED

Ruling R11 (2026-09-14): Gazer Mobile v2 (a full rewrite, M1 complete, in `waddlebot` on `feature/gazer-mobile-v2`) is being moved into this repo by the waddlebot session with its history and a handoff document. The old `mobile/flutter_gazer` app and its never-registered plugin stubs are therefore not migrated, and no plugin packages are scaffolded from them. Gazer work in `penguinm` resumes from that handoff.

### Task T28: Integration — make pre-commit green

**Files:** any file needed to fix fallout; `docs/OFFLINE.md` per-app rows; `.PLAN`/`.TODO` updated.

- [ ] Step 1: `make bootstrap && make lint` → 0 issues across 19 packages.
- [ ] Step 2: `make test` → all pass; `make coverage` → every package ≥90% with LF>0; print the table. Every test invocation (the root `pubspec.yaml` melos `test` script, the Makefile `test`/`test-unit`/`smoke-test` targets, `ci.yml`) passes a per-test `--timeout=60s` so a hanging test FAILS the gate instead of stalling it (a hung penguin_flags test stalled two agents for 45+ minutes during this build); prove it by running one deliberately hanging test in a scratch file and showing the gate fails.
- [ ] Step 3: `make smoke-test` (includes `telemetry-validate.sh`) → prints `logRecords≥1 metricDataPoints≥1 histograms≥1 spans≥1`.
- [ ] Step 4: `make test-security` → gitleaks 0 leaks, trivy 0 HIGH/CRITICAL, osv-scanner 0 vulns, semgrep 0 findings, zizmor 0, hadolint 0 — print counts of files/packages scanned.
- [ ] Step 5: Gradle validation deferred from T5: `docker run --rm -v "$PWD":/work -w /work -u 1000 penguinm/flutter-android:local bash -c 'cd apps/<app> && flutter build apk --debug --flavor dev --dart-define-from-file=env/dev.json'` for `penguin_reference` and `penguincloud`. Fix conventions until green. Also assert `grep -rl "barrel imports" --include=*_test.dart . | wc -l` → 0 and that `apps/gazer` does not exist (reserved for the incoming move).
- [ ] Step 6: `make pre-commit` → summary log path + all PASS. `check-pins.sh` reports 0 mutable refs. Report the full gate table.

### Task T29: Pin the toolchain image digest (after first push)

- [ ] After the branch is pushed and `toolchain-image.yml` has run: copy the digest from the job summary into `ci.yml`, `release-android.yml`, `e2e-android.yml` (`image: ghcr.io/penguintechinc/penguinm/flutter-android@sha256:…`), remove the `TODO-PIN` comments, re-run `check-pins.sh`.

---

## Self-review

- Spec coverage: §2 layout → T1a/T1b/T13; §3 → T1a/T1b; §4.1 → T1a; §4.2 → T3; §4.3 → T15; §4.4 → T16; §4.5 → T17; §4.6 → T18; §4.7 → T21; §4.8 → T22; §4.9 → T19; §4.10 → T24; §4.11 → T23 (+T24 for `pumpPenguinApp`); §5 → T13 (CLAUDE.md) + T14 (brick enforces it); §6 → T5; §7 → T8 + T1b + T4; §8 → T9 (+T29); §9 → T1b; §10 → every package task + T28; §11.1 → T1a/T2/T10–T12; §11.2 → T26; §11.3 → dropped (R11: Gazer v2 arrives via the waddlebot session's move); §12 → follow-ups (not tasks); §13 → enforced by T16/T17/T18/T21/T24/T28.
- Type consistency: `MetricsSink`/`TraceSink`/`TokenProvider` defined once in T3, consumed in T15/T16/T21/T24; `apiClientProvider` defined in T16, consumed in T21/T22/T24; `pumpPenguinApp` lives in the shell only.
- Placeholders: the single deferred value is the toolchain image digest (T29), explicitly tracked.

## Appendix A — Pins (verified against Flutter 3.44.8 / Dart 3.12.2 on 2026-09-14)

### A.1 pub.dev (exact versions; publisher in parentheses)

| Package | Version | Used by |
|---|---|---|
| melos | 8.7.0 (invertase.io) | root dev |
| mason_cli | 0.1.3 (brickhub.dev) | global tool via `dart pub global activate mason_cli 0.1.3` in `new-app.sh` |
| flutter_riverpod | 3.4.3 (dash-overflow.net) | core, every widget package, shell, apps |
| go_router | 17.5.0 (flutter.dev) | auth (redirect), shell, apps |
| http | 1.6.0 (dart.dev) | api, auth, flags, telemetry, update, flutter_libs |
| flutter_secure_storage | 11.1.1 (steenbakker.dev) | auth, flutter_libs |
| flutter_appauth | 12.1.0 (dexterx.dev) | auth |
| sqlite3 | 3.5.2 (simonbinder.eu) — 3.6.0 needs `hooks ^2.2.0` → `meta ^1.19.0`, incompatible with Flutter 3.44.8's `meta 1.18.0` (found by T1a) | offline |
| path_provider | 2.1.6 (flutter.dev) | offline |
| path | 1.9.1 (dart.dev) | offline, otlp_sink |
| connectivity_plus | 7.3.1 (fluttercommunity.dev) | offline |
| shared_preferences | 2.5.5 (flutter.dev) | core (KeyValueStore), flags cache, flutter_libs |
| package_info_plus | 10.2.1 (fluttercommunity.dev) | shell (app version), gazer |
| url_launcher | 6.3.2 (flutter.dev) | update, flutter_libs, gazer |
| pub_semver | 2.2.1 (dart.dev) | update |
| crypto | 3.0.7 (dart.dev) | flutter_libs |
| file_picker | 12.3.0 (miguelpruivo, PT) — 8.3.7 needs `win32 ^5.9`, disjoint with `flutter_secure_storage 11.1.1`'s `win32 ^6`; 12.x dropped the win32 dep (found by T1a) | flutter_libs |
| uuid | 4.6.0 (yuli.dev) | offline (write ids), gazer |
| intl | 0.20.3 (dart.dev) | offline (chip), gazer |
| equatable | 2.1.0 (fluttercommunity.dev) | gazer |
| socket_io_client | 3.1.6 (rikulo, Taiwan) | gazer chat |
| camera | 0.12.1 (flutter.dev) | gazer streaming |
| args | 2.7.0 (dart.dev) | otlp_sink |
| flutter_lints | 6.0.0 (flutter.dev) | penguin_lints |
| mocktail | 1.0.5 (felangel.dev) | dev everywhere |
| flutter_launcher_icons | 0.14.4 (fluttercommunity.dev) — NOT a workspace dep (`cli_util ^0.4` clashes with melos 8.7.0); run via `dart pub global activate flutter_launcher_icons 0.14.4` from a script | tooling only |

Rejected: `dio` 5.11.1 (flutter.cn — PRC), `golden_toolkit` (discontinued), `jwt_decoder` (abandoned 2021), `dart_jsonwebtoken` (unneeded — decode only), `drift`/`drift_flutter`/`sqlite3_flutter_libs` (codegen / EOL), `build_runner` (2.15.1 would be the only compatible version; unneeded), `riverpod_annotation`/`riverpod_generator`/`riverpod_lint`/`custom_lint`/`freezed`/`json_serializable` (analyzer deadlocks; unneeded), `opentelemetry` 0.18.11 (logs unimplemented; we ship our own OTLP/HTTP JSON exporter), `posthog_flutter` (bundles native SDKs; we call the HTTP API), `alchemist` (unneeded), `local_auth` (unused by any app today).

### A.2 GitHub Actions (full SHA, tag as comment)

| Action | `uses:` |
|---|---|
| actions/checkout | `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1` |
| actions/setup-java | `actions/setup-java@de7274f081f381c8f8158605e0321c36c376e2e6 # v6.0.1` |
| actions/upload-artifact | `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1` |
| actions/download-artifact | `actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c # v8.0.1` |
| actions/cache | `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0` |
| subosito/flutter-action | `subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2.23.0` |
| android-actions/setup-android | `android-actions/setup-android@40fd30fb8d7440372e1316f5d1809ec01dcd3699 # v4.0.1` |
| gradle/actions/setup-gradle | `gradle/actions/setup-gradle@9c971963bec38e04b3d30dcc455b5382be2fdbfb # v6.3.0` |
| gitleaks/gitleaks-action | `gitleaks/gitleaks-action@e0c47f4f8be36e29cdc102c57e68cb5cbf0e8d1e # v3.0.0` |
| aquasecurity/trivy-action | `aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25 # v0.36.0` |
| google/osv-scanner-action (reusable) | `google/osv-scanner-action/.github/workflows/osv-scanner-reusable.yml@a345acffa64b0eaede81a3d9aae6141214d9c8fc # v2.6.0` |
| zizmorcore/zizmor-action | `zizmorcore/zizmor-action@cc914d7f3750a2d13d75c7f184a1060aa0e9d482 # v0.6.4` |
| github/codeql-action/init, analyze | `github/codeql-action/<init|analyze>@b96794f015dfd88f77b49b1c93e0fa7110f94c63 # v4.38.0` |
| softprops/action-gh-release | `softprops/action-gh-release@efb35369e0ad2afab669f228072c1b0d510eae64 # v3.0.3` |
| r0adkll/upload-google-play | `r0adkll/upload-google-play@e738b9dd8f2476ea806d921b64aacd24f34515a5 # v1.1.5` |
| docker/setup-buildx-action, docker/login-action, docker/build-push-action | **T8 resolves** with `gh release view -R <repo> --json tagName` + `git ls-remote --tags` (dereference `^{}`), recorded in its report |
| reactivecircus/android-emulator-runner | `reactivecircus/android-emulator-runner@a421e43855164a8197daf9d8d40fe71c6996bb0d # v2.38.0` (resolved by T9) |
| astral-sh/setup-uv | `astral-sh/setup-uv@bec219d24cd3e171d82865faccec33120bb574f4 # v10.1.0` (authorized by the controller in T9's dispatch; resolved by T9) |
| semgrep | no action — `uv pip install --require-hashes -r tooling/security/requirements.txt` |

### A.3 Docker / Android SDK / Flutter Android defaults

| Item | Value |
|---|---|
| `debian:bookworm-slim` | `@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171` |
| Android cmdline-tools | `commandlinetools-linux-15859902_latest.zip`, SHA256 `4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583` |
| SDK packages | `platform-tools`, `platforms;android-36`, `build-tools;36.0.0`, `ndk;28.2.13676358` |
| Flutter 3.44.8 defaults | compileSdk 36, minSdk 24, targetSdk 36, NDK 28.2.13676358, AGP 9.0.1, Kotlin 2.3.20, Gradle 9.1.0; framework revision `058e0af2c2` |
| JDK | Debian `openjdk-17-jdk-headless` — T8 pins the exact apt version present in bookworm at build time and records it here |
| Kotlin test deps | `junit:junit:4.13.2`, `org.jetbrains.kotlin:kotlin-test:2.3.20` |
