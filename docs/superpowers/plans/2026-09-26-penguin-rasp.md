# penguin_rasp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Ship a shared `penguin_rasp` package (freerasp wrapper) wired into `runPenguinApp`; every threat hit and every engine failure emits an OTel metric + a sanitized log; blocking terminates the app, gated by a build-time toggle.

**Architecture:** `RaspEngine` interface + value types + Noop default in `penguin_core`; `FreeraspEngine` adapter + `RaspGuard` runtime in `penguin_rasp`; `FakeRaspEngine` in `penguin_testing`; fail-soft `ShellServices.raspEngine` seam + `AppManifest.raspPolicy` + a new Bootstrap phase in `penguin_app_shell`.

**Tech Stack:** Flutter 3.44.8 / Dart 3.12.2, flutter_riverpod 3.4.3, freerasp (Talsec, exact pin), device_info_plus (workspace-pinned), package:http (n/a here). No codegen.

**Spec:** `docs/superpowers/specs/2026-09-26-penguin-rasp-design.md` (read it — it carries the interface, RaspGuard behavior, enforcement toggle, threat mapping, and testing matrix).

## Global Constraints

- **OTel + sanitized log on EVERY threat hit AND EVERY engine failure** — metric via `MetricsSink.counter`, log via `PenguinLogger` (warn threat / error failure). Non-negotiable (user directive).
- **Fail-soft everywhere** — a RASP init/detection/telemetry failure never crashes or blocks the app; the Bootstrap phase catches and records `BootstrapWarning('rasp', e)`.
- **Feature-flag gated** `${productKey}.rasp` (default OFF; unseen ⇒ false). RASP only starts when the flag is on AND `manifest.raspPolicy.enabled`.
- **No PII / device fingerprint** in `RaspThreat`, metrics attributes, or logs — category + action only.
- **Exact version pins** (no `^`/`~`); freerasp from Talsec (EU, not PRC); `publish_to: none`, `resolution: workspace`.
- **Coverage ≥90% per package**; every public member has a `///` doc; trailing commas; no `print`.
- **Enforcement (terminate) toggle**: `raspEnforcementEnabled = bool.hasEnvironment('RASP_ENFORCE') ? bool.fromEnvironment('RASP_ENFORCE') : kReleaseMode`. Debug/emulator ⇒ no terminate (detection+telemetry still fire).
- **Block-by-default set** (user): hooking, tampering, debugger, rootJailbreak, unsupportedOs, emulator.
- Run melos via `dart pub global run melos` (workspace has flutter_localizations); analyze/test/coverage green before each task completes.

---

### Task 1: penguin_core — RaspEngine interface, value types, Noop default, provider

**Files:**
- Create: `packages/penguin_core/lib/src/rasp_engine.dart`
- Modify: `packages/penguin_core/lib/penguin_core.dart` (add `export 'src/rasp_engine.dart';`)
- Modify: `packages/penguin_core/lib/src/providers.dart` (add `raspEngineProvider`, mirror `metricsSinkProvider` at :24)
- Test: `packages/penguin_core/test/rasp_engine_test.dart`; extend `penguin_core_barrel_test.dart`

**Interfaces produced:** `RaspEngine`, `RaspThreat`, `RaspThreatType`, `RaspAction`, `RaspPolicy` (with `defaultBlockThreats` + `actionFor`), `RaspConfig`, `NoopRaspEngine`, `raspEngineProvider`. Exact shapes: see spec §"Interface & value types". Value types are immutable (`final class`, `const` ctors, `==`/`hashCode` where compared in tests — use records or manual equality; follow existing value-type style in penguin_core).

- [ ] Write failing tests: `RaspPolicy.actionFor` returns block for each default-block type and alert otherwise; `RaspPolicy` defaults (`enabled == false`, `blockThreats == defaultBlockThreats`); `NoopRaspEngine.start`/`stop` complete and `threats` is an empty stream that closes; `raspEngineProvider` reads `NoopRaspEngine` by default.
- [ ] Implement `rasp_engine.dart` per spec; add barrel export; add `raspEngineProvider = Provider<RaspEngine>((ref) => const NoopRaspEngine())`.
- [ ] `dart pub global run melos exec --scope=penguin_core -- flutter analyze` + `flutter test`; extend barrel test to assert the new exports are non-null.
- [ ] Commit `feat(penguin_core): RaspEngine seam + RASP value types + Noop default`.

### Task 2: penguin_testing — FakeRaspEngine

**Files:**
- Create: `packages/penguin_testing/lib/src/fake_rasp_engine.dart`
- Modify: `packages/penguin_testing/lib/penguin_testing.dart` (export)
- Test: `packages/penguin_testing/test/fake_rasp_engine_test.dart`

**Interfaces:** Consumes `RaspEngine`/`RaspThreat` (Task 1). Produces `FakeRaspEngine implements RaspEngine` with a controllable threat stream: `void emit(RaspThreatType type, {DateTime? at})`, records `started`/`stopped` bools and the `RaspConfig` passed, optional `throwOnStart`/`errorOnStream` to exercise fail-soft. Backed by a broadcast `StreamController<RaspThreat>` closed on `stop()`.

- [ ] Failing test: `emit` pushes a `RaspThreat` to a listener; `start` records config and flips `started`; `throwOnStart` makes `start` throw; `stop` closes the stream.
- [ ] Implement; export from barrel.
- [ ] analyze + test green (scope penguin_testing).
- [ ] Commit `feat(penguin_testing): FakeRaspEngine for RASP tests`.

### Task 3: penguin_rasp package scaffold + RaspGuard + enforcement toggle + workspace registration

**Files:**
- Create: `packages/penguin_rasp/pubspec.yaml` (model on `packages/penguin_update/pubspec.yaml`: publish_to none, resolution workspace, deps `flutter`, `flutter_riverpod: 3.4.3`, `penguin_core: {path: ../penguin_core}`; dev deps `flutter_test`, `mocktail: 1.0.5`, `penguin_lints`+`penguin_testing` paths). NO freerasp yet (Task 4 adds it).
- Create: `packages/penguin_rasp/lib/penguin_rasp.dart` (barrel), `lib/src/rasp_guard.dart`, `lib/src/rasp_metrics.dart` (`static const raspThreat='rasp.threat'; static const raspFailure='rasp.failure';`), `lib/src/rasp_enforcement.dart` (`raspEnforcementEnabled` const per spec).
- Modify: root `pubspec.yaml` — add `- packages/penguin_rasp` to the `workspace:` list (dependency-ordered, after penguin_core), then `dart pub global run melos bootstrap` so `pubspec.lock` updates.
- Test: `packages/penguin_rasp/test/rasp_guard_test.dart`, `rasp_enforcement_test.dart`, `penguin_rasp_barrel_test.dart`

**Interfaces:** `RaspGuard({required RaspEngine engine, required MetricsSink metrics, required PenguinLogger logger, required RaspPolicy policy, required bool enforce, void Function()? onBlock})`, `Future<void> start()`, `Future<void> stop()`. Behavior exactly per spec §RaspGuard: per-threat metric+log; block+enforce ⇒ onBlock; failure ⇒ `rasp.failure` metric + `logger.error`, swallowed. `onBlock` default terminate lives in the shell (Task 5), not here — RaspGuard just calls the injected `onBlock` (null ⇒ no-op) so it is fully testable without terminating the test runner.

- [ ] Failing tests with `FakeRaspEngine` + `MockMetricsSink`/`MockPenguinLogger` (mocktail): for EACH `RaspThreatType`, assert `metrics.counter('rasp.threat', 1, attributes:{'threat':name,'action':expected,'enforced':enforce})` and a `logger.warn` call; assert `onBlock` called iff (type in blockThreats AND enforce==true); assert `onBlock` NOT called when enforce==false even for block types; assert engine `throwOnStart` ⇒ `metrics.counter('rasp.failure',…)` + `logger.error` + `start()` completes normally (no rethrow); assert OS-version gate emits `unsupportedOs` when below `minAndroidSdk` (inject the detected version via a ctor seam/param so it is testable without a device).
- [ ] Implement RaspGuard, rasp_metrics, rasp_enforcement; register package in root workspace; `melos bootstrap`.
- [ ] analyze + test green (scope penguin_rasp); barrel test.
- [ ] Commit `feat(penguin_rasp): RaspGuard runtime + enforcement toggle + package scaffold`.

### Task 4: penguin_rasp — FreeraspEngine adapter (freerasp) + threat mapping + OS check

**Files:**
- Modify: `packages/penguin_rasp/pubspec.yaml` (add `freerasp: <exact latest stable>` and `device_info_plus: <workspace-aligned exact pin>`; confirm no PRC transitive deps via `osv-scanner`/manual check).
- Create: `lib/src/freerasp_engine.dart` (`FreeraspEngine implements RaspEngine`), `lib/src/threat_mapping.dart` (pure `RaspThreatType mapFreeraspThreat(<freerasp threat>)`), `lib/src/os_check.dart` (pure helper: given detected OS + policy min ⇒ bool unsupported).
- Modify barrel exports.
- Test: `threat_mapping_test.dart` (every freerasp threat → expected type, incl. `other` fallback), `os_check_test.dart`.

**Interfaces:** `FreeraspEngine` builds `TalsecConfig` from `RaspConfig` (packageName, signing cert hashes, bundleIds, `isProd: kReleaseMode`, supported stores), subscribes to freerasp's threat callbacks/streams, maps each via `mapFreeraspThreat`, and republishes as `RaspThreat` on its own `Stream`. `stop()` tears down. The OS-version supplementary check reads `device_info_plus` and, if below `policy.minAndroidSdk`/`minIosVersion`, emits a synthetic `RaspThreat(unsupportedOs)`.

- [ ] Read freerasp's current pub.dev API; pin the exact version. Verify Talsec/EU origin (not PRC) and license.
- [ ] Failing tests for `mapFreeraspThreat` (table of every freerasp threat) and `os_check` (below/at/above min for Android SDK int and iOS version string).
- [ ] Implement adapter + mapping + os_check; keep `FreeraspEngine`'s own body minimal (config build + stream plumbing) — all branching logic in the two pure, tested helpers.
- [ ] analyze + test green; `osv-scanner --lockfile pubspec.lock` clean.
- [ ] Commit `feat(penguin_rasp): FreeraspEngine adapter + threat mapping + OS gate`.

### Task 5: penguin_app_shell — seam, manifest field, fail-soft Bootstrap phase, terminate

**Files:**
- Modify: `shells/penguin_app_shell/lib/src/bootstrap.dart` — add `RaspEngine? raspEngine` to `ShellServices` (:96/:101/fields); add a new numbered "RASP" phase in `Bootstrap.run` AFTER Feature-flags (:215) and before/around API, following the existing try/catch + `BootstrapWarning` + provider-override idiom (:319). Build `engine = services.raspEngine ?? FreeraspEngine(...)`; only if `manifest.raspPolicy.enabled && featureFlags.isEnabled('${config.productKey}.rasp')`; construct `RaspGuard(engine, metrics, logger, manifest.raspPolicy, enforce: raspEnforcementEnabled, onBlock: _terminate)`; `await guard.start()`; `finalOverrides.add(raspEngineProvider.overrideWithValue(engine))`. Keep a reference so it is not GC'd.
- Modify: `shells/penguin_app_shell/lib/src/app_manifest.dart` — add `final RaspPolicy raspPolicy;` defaulted `const RaspPolicy()` (non-breaking, matches `brand`/`siblings` style).
- Create: `shells/penguin_app_shell/lib/src/rasp_terminate.dart` — `void raspTerminate()` → `SystemNavigator.pop(); ` then a hard exit; injectable so tests pass a spy.
- Modify: `run_penguin_app.dart` only if a new export/param is needed (likely none).
- Test: `shells/penguin_app_shell/test/bootstrap_rasp_test.dart`

**Interfaces consumed:** `RaspEngine`/`RaspPolicy`/`raspEngineProvider` (Task 1), `RaspGuard`/`raspEnforcementEnabled` (Task 3), `FreeraspEngine` (Task 4), `FakeRaspEngine` (Task 2). `metrics`/`logger`/`featureFlags` are already in scope in `Bootstrap.run` (:211-236).

- [ ] Failing bootstrap tests injecting `FakeRaspEngine` via `ShellServices.raspEngine`, flag overridden on/off: flag ON + `raspPolicy.enabled` ⇒ engine `started` and a `FakeRaspEngine.emit(hooking)` (enforce=true via injected guard/onBlock spy) calls the terminate spy; flag OFF ⇒ engine never started; `throwOnStart` ⇒ result has `BootstrapWarning('rasp', …)` and the app still boots (other providers intact). Assert metric+log emitted for the emitted threat.
- [ ] Implement seam + manifest field + phase + terminate; wire enforce via `raspEnforcementEnabled` (tests inject a fixed value).
- [ ] analyze + test green (scope penguin_app_shell).
- [ ] Commit `feat(penguin_app_shell): fail-soft RASP bootstrap phase + raspEngine seam + raspPolicy`.

### Task 6: reference integration, docs, full gate

**Files:**
- Modify: `apps/penguin_reference/lib/main.dart` (or its manifest builder) — `raspPolicy: const RaspPolicy(enabled: true, minAndroidSdk: 26)`; document the `penguin_reference.rasp` flag.
- Create: `docs/RASP.md` — what it detects, the flag, the `RASP_ENFORCE` build toggle, per-app policy, OTel signals (`rasp.threat`, `rasp.failure`), fail-soft + no-PII guarantees.
- Modify: `check-logging.sh` allowlist only if RaspGuard needs a sanctioned sink (it uses injected `PenguinLogger`, so NOT expected).
- Verify: `make coverage` ≥90% for penguin_core/penguin_testing/penguin_rasp/penguin_app_shell; `dart pub global run melos run analyze` clean; `make test-security` clean (osv/semgrep/trivy — freerasp native). The android CI build exercises `FreeraspEngine` natively — that is the native validation.

- [ ] Wire penguin_reference manifest + flag; add docs.
- [ ] Full local gate: analyze, test, coverage-gate ≥90%, telemetry-validate still 1/1/1/1, check-pins, check-logging, osv/semgrep/trivy.
- [ ] Commit `feat(penguin_reference): enable RASP + docs`.

---

## Self-review notes
- Spec coverage: interface (T1), fake (T2), runtime+toggle (T3), freerasp adapter+mapping+OS (T4), shell wiring+terminate (T5), reference+docs+gate (T6). Every spec section maps to a task.
- Type consistency: `RaspEngine`/`RaspThreat`/`RaspThreatType`/`RaspAction`/`RaspPolicy`/`RaspConfig`/`RaspGuard`/`raspEngineProvider`/`raspEnforcementEnabled`/`RaspMetrics` used identically across tasks.
- Terminate lives in the shell (T5), injected into RaspGuard as `onBlock`, so RaspGuard tests never kill the runner.
