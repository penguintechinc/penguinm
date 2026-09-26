# penguin_rasp — RASP (Runtime Application Self-Protection) design

**Status:** approved (decisions locked 2026-09-26). Target branch: `feature/penguin-rasp` off `release/v0.1.X`.

## Goal

A shared `penguin_rasp` package wrapping **freerasp** (Talsec, EU/Slovakia — not PRC) behind an interface in `penguin_core`, wired into `runPenguinApp` so every app gets runtime tamper/hook/root/debug/emulator detection. Every threat hit **and** every engine failure emits an OTel metric **and** a sanitized penguin log. Blocking terminates the app, gated by a build-time toggle so debug/emulator builds run for testing.

## Non-negotiable requirements

1. **OTel + logs on every hit and every failure** (user directive). Metric via `MetricsSink`, log via `PenguinLogger` (auto-sanitized). Dead exporter never breaks the app.
2. **Fail-soft**: a RASP init/detection/telemetry failure never crashes or blocks the app (mirrors every existing `Bootstrap` phase).
3. **Feature-flag gated**: `${productKey}.rasp` PostHog flag, default OFF (never-seen ⇒ false), so RASP is a runtime kill-switch too.
4. **No PII / device fingerprints** in threat data, metrics, or logs — only the threat category and action.
5. **Supply chain**: freerasp pinned to an exact version; no PRC deps.
6. **Coverage ≥90%** per package via a fake engine; the native `FreeraspEngine` adapter is thin glue.

## Architecture (mirrors the TokenProvider/MetricsSink seams)

```
penguin_core        RaspEngine (abstract interface) + NoopRaspEngine default
                    value types: RaspThreat, RaspThreatType, RaspAction, RaspPolicy, RaspConfig
                    raspEngineProvider (default Noop) in providers.dart
      ▲
penguin_rasp        FreeraspEngine implements RaspEngine   (freerasp adapter, native, thin)
                    RaspGuard                               (runtime: subscribe→telemetry+policy; TESTABLE core)
                    raspEnforcementEnabled                  (build-time toggle)
      ▲
penguin_testing     FakeRaspEngine                          (emits synthetic threats; used by rasp + shell tests)
      ▲
penguin_app_shell   ShellServices.raspEngine  (injectable seam; null ⇒ Bootstrap builds FreeraspEngine)
                    AppManifest.raspPolicy    (default const RaspPolicy(); non-breaking)
                    Bootstrap.run: new fail-soft "RASP" phase after Feature-flags:
                      if manifest.raspPolicy.enabled && flags.isEnabled('${productKey}.rasp'):
                        guard = RaspGuard(engine, metrics, logger, policy,
                                          enforce: raspEnforcementEnabled, onBlock: terminate)
                        await guard.start()            // fail-soft try/catch → BootstrapWarning('rasp', e)
                        finalOverrides.add(raspEngineProvider.overrideWithValue(engine))
```

## Interface & value types (penguin_core, `lib/src/rasp_engine.dart`)

```dart
/// Runtime application self-protection engine: detects device/app integrity
/// threats and surfaces them as a stream. A no-op default keeps RASP optional.
abstract interface class RaspEngine {
  /// Begin detection. Idempotent; safe to call once at bootstrap.
  Future<void> start(RaspConfig config);
  /// Threats as they are detected. Never emits PII.
  Stream<RaspThreat> get threats;
  /// Stop detection and release resources.
  Future<void> stop();
}

/// A detected runtime threat, category + timestamp only (no device fingerprint/PII).
final class RaspThreat {
  const RaspThreat(this.type, this.detectedAt);
  final RaspThreatType type;
  final DateTime detectedAt;
}

/// Threat categories penguin_rasp recognises (superset mapped from freerasp + an
/// OS-version check). `other` catches any freerasp threat not individually modelled.
enum RaspThreatType {
  rootJailbreak, hooking, debugger, emulator, tampering,
  untrustedInstallSource, unsupportedOs, deviceBinding, screenCapture, other,
}

/// What to do when a threat fires. `block` terminates only when enforcing.
enum RaspAction { alert, block }

/// Per-app RASP policy carried on AppManifest.
final class RaspPolicy {
  const RaspPolicy({
    this.enabled = false,
    this.blockThreats = defaultBlockThreats,
    this.minAndroidSdk,   // null ⇒ no OS-version gate
    this.minIosVersion,
  });
  final bool enabled;
  final Set<RaspThreatType> blockThreats;   // members ⇒ block; all others ⇒ alert
  final int? minAndroidSdk;
  final String? minIosVersion;

  /// User-chosen default block set (2026-09-26).
  static const Set<RaspThreatType> defaultBlockThreats = {
    RaspThreatType.hooking, RaspThreatType.tampering, RaspThreatType.debugger,
    RaspThreatType.rootJailbreak, RaspThreatType.unsupportedOs, RaspThreatType.emulator,
  };

  RaspAction actionFor(RaspThreatType t) =>
      blockThreats.contains(t) ? RaspAction.block : RaspAction.alert;
}

/// Immutable config handed to the engine at start (from RaspPolicy + app identity).
final class RaspConfig { /* packageName, expected signing hashes, bundleIds, isProd, minOs… */ }

/// Safe default: detects nothing.
final class NoopRaspEngine implements RaspEngine { /* start/stop no-op; threats = const Stream.empty() */ }
```

`raspEngineProvider` in `providers.dart` defaults to `const NoopRaspEngine()` (mirrors `metricsSinkProvider`).

## RaspGuard (penguin_rasp — the tested core)

```dart
class RaspGuard {
  RaspGuard({
    required RaspEngine engine, required MetricsSink metrics, required PenguinLogger logger,
    required RaspPolicy policy, required bool enforce, void Function()? onBlock,
  });
  Future<void> start();   // engine.start(config); listen threats → handle; fail-soft
  Future<void> stop();
}
```
Per threat: `metrics.counter('rasp.threat', 1, attributes: {'threat': type.name, 'action': action.name, 'enforced': enforce})`; `logger.warn('RASP threat detected', attributes: {'threat': type.name, 'action': action.name})`; if `action == block && enforce` ⇒ `onBlock()` (default terminate: `SystemNavigator.pop()` then `exit(0)`). Engine start/listen failure ⇒ `metrics.counter('rasp.failure', 1, attributes:{'phase': …})` + `logger.error(…, error:e, stackTrace:st)`, swallow (fail-soft). Metric name consts on a `RaspMetrics` class (`rasp.threat`, `rasp.failure`).

## Build-time enforcement toggle

```dart
// penguin_rasp, imports package:flutter/foundation.dart
const bool raspEnforcementEnabled =
    bool.hasEnvironment('RASP_ENFORCE') ? bool.fromEnvironment('RASP_ENFORCE') : kReleaseMode;
```
- Release builds: enforce (terminate on block) by default.
- Debug/profile (emulator, debugger, dev): do NOT enforce — detection + OTel + logs still fire; terminate suppressed. So devs run on emulators/debuggers freely.
- Override either way at build: `--dart-define=RASP_ENFORCE=true|false` (e.g. to test enforcement in debug, or ship a release smoke build without it).
- freerasp `isProd` set from `kReleaseMode` so its dev-mode callbacks don't spam release.

## Threat mapping (freerasp → RaspThreatType)

Pure function `mapFreeraspThreat(Threat) → RaspThreatType` (unit-tested): privilegedAccess⇒rootJailbreak, hooks⇒hooking, debug⇒debugger, simulator⇒emulator, appIntegrity⇒tampering, unofficialStore⇒untrustedInstallSource, deviceBinding⇒deviceBinding, screenshot/screenRecording⇒screenCapture, else⇒other. `unsupportedOs` is NOT a freerasp threat — it comes from a supplementary OS-version check in `RaspGuard.start()` comparing the running OS (device_info_plus) against `policy.minAndroidSdk`/`minIosVersion`, emitting a synthetic `RaspThreat(unsupportedOs)` if below.

## Testing

- `RaspGuard` (main coverage): `FakeRaspEngine` (penguin_testing) emits each threat type; assert exact metric calls, sanitized log calls, and that `onBlock` fires ⇔ (block-set member AND enforce), and NOT when enforce=false; OS-version gate; fail-soft when the engine throws (mocktail engine throwing on `start`/stream error).
- `mapFreeraspThreat` pure-function test (every freerasp threat → expected type).
- Enforcement const behavior (documented; const so tested via a param-injected variant in RaspGuard, `enforce:` is a ctor arg — that is how the toggle is testable).
- Shell bootstrap test: inject `FakeRaspEngine` via `ShellServices.raspEngine`; flag ON+policy.enabled ⇒ guard starts and a synthetic block threat triggers the injected `onBlock`; flag OFF ⇒ engine never started; engine throw ⇒ `BootstrapWarning('rasp', …)`, app still boots.
- `FreeraspEngine.start` itself (native) is exercised by the android CI build; its Dart logic is the mapping function (unit-tested) — the adapter body is excluded from the 90% gate as platform glue only if unavoidable.

## Reference integration

Enable RASP on `apps/penguin_reference` (the reference app): `AppManifest(raspPolicy: const RaspPolicy(enabled: true, minAndroidSdk: 26))`, flag `penguin_reference.rasp`. Confirms the wiring end-to-end and that a debug build still runs (enforce off in debug).

## Out of scope (v1)

iOS-specific tuning beyond config plumbing (Android-first per client rules); a lock-screen UI (decision was terminate, not lock); per-threat remote config beyond the PostHog on/off flag.
