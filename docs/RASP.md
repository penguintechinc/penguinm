# RASP (Runtime Application Self-Protection)

Every app can detect device/app integrity threats at runtime via `package:penguin_rasp`
(a `freerasp`/Talsec adapter) wired into `runPenguinApp`'s Bootstrap sequence. Disabled
by default; each app opts in explicitly and the runtime flag stays the final kill-switch.

## What it detects

`RaspThreatType` (in `penguin_core`) is the full category set — a superset mapped from
freerasp plus one supplementary OS-version check:

| Type | Detects |
|---|---|
| `rootJailbreak` | Device is rooted (Android) / jailbroken (iOS) |
| `hooking` | Hooking/instrumentation framework (e.g. Frida, Xposed) |
| `debugger` | Debugger attached to the running process |
| `emulator` | Running inside an emulator/simulator |
| `tampering` | App binary/resources tampered with |
| `untrustedInstallSource` | Installed from an untrusted source (not an official store) |
| `unsupportedOs` | OS version below the app's configured minimum (supplementary check, not from freerasp) |
| `deviceBinding` | Device/app-instance integrity binding failed |
| `screenCapture` | Screenshot/screen recording detected |
| `other` | Any freerasp threat not individually modelled (includes malware detection) |

No PII or device fingerprint is ever carried on a `RaspThreat`, a metric attribute, or a
log line — category + timestamp only.

## Per-app policy (`RaspPolicy`)

Carried on `AppManifest.raspPolicy`, defaults to disabled:

```dart
const RaspPolicy({
  this.enabled = false,
  this.blockThreats = defaultBlockThreats, // hooking, tampering, debugger,
                                            // rootJailbreak, unsupportedOs, emulator
  this.minAndroidSdk,   // null = no OS-version gate on Android
  this.minIosVersion,   // null = no OS-version gate on iOS
});
```

Threats not in `blockThreats` only alert (metric + log); threats in the set additionally
terminate the app, but only when enforcement is on (see below). `apps/penguin_reference`
sets `RaspPolicy(enabled: true, minAndroidSdk: 24)` — the default block set, unchanged;
24 matches the platform's `minSdk` convention
(`platform/android/gradle/penguin-android.gradle.kts`).

## Runtime kill-switch: `${productKey}.rasp` flag

RASP only actually starts when **both** are true:

1. `manifest.raspPolicy.enabled`
2. The PostHog flag `${productKey}.rasp` is on (default OFF; unseen ⇒ false)

For `apps/penguin_reference` (`productKey: 'penguinm'`) that flag key is
**`penguinm.rasp`**. This is a genuine runtime kill-switch, independent of the build —
flip it off in PostHog and every app instance stops starting RASP on its next flag
refresh, no redeploy needed. In tests (no PostHog/flag cache), the flag is always unseen
⇒ false, so RASP never starts and no native engine is touched.

## Build-time enforcement toggle: `RASP_ENFORCE`

Detection and telemetry always fire once RASP is running; whether a **blocking** threat
actually terminates the app is a separate, build-time decision:

```dart
const bool raspEnforcementEnabled = bool.hasEnvironment('RASP_ENFORCE')
    ? bool.fromEnvironment('RASP_ENFORCE')
    : kReleaseMode;
```

- Default: release builds enforce, debug builds don't — so a debugger-attached or
  emulator dev build isn't killed mid-session.
- Override explicitly: `--dart-define=RASP_ENFORCE=true` or `=false` at build time.
- `enforce=false` never suppresses metrics/logs — only whether `onBlock` (app
  termination, wired to `SystemNavigator.pop()` + hard exit in the shell) is invoked.

## OTel signals

| Name | Kind | Attributes | Emitted when |
|---|---|---|---|
| `rasp.threat` | counter | `threat` (type name), `action` (`alert`/`block`), `enforced` (bool) | Every detected threat, always — even when not enforcing |
| `rasp.failure` | counter | `phase` (`start`/`stop`/`stream`) | Every engine start/stop/stream failure |

Paired with every metric: a sanitized `PenguinLogger` call — `logger.warn('RASP threat
detected', ...)` per threat, `logger.error('RASP engine failed to ...', ...)` per
failure. Neither carries PII or a device fingerprint — same category/phase fields as the
metric attributes.

## Fail-soft guarantee

A RASP init, detection, or telemetry failure **never** crashes or blocks the app.
`RaspGuard.start()`/`stop()` catch everything from the engine and its stream; a caught
failure is recorded as `rasp.failure` + an error log and swallowed. At the Bootstrap
level, any failure surfaces only as a `BootstrapWarning('rasp', e)` — every other
provider/phase still initializes normally.

## Known v1 gaps

### iOS

v1 is Android-first (per `client-flutter.md`): freerasp's iOS support needs a
`teamId` and, on both platforms, a `watcherMail` (security-report contact) in its
`TalsecConfig` — neither is yet plumbed through `penguin_core`'s `RaspConfig`.
`FreeraspEngine.buildTalsecConfig` currently passes both as empty strings. On iOS this
fails freerasp's own config validation closed; on Android `watcherMail` being blank has
no functional effect on detection (it only gates Talsec's weekly Security Report email).
Either way this is caught by `RaspGuard.start()`'s fail-soft try/catch — never a crash,
just RASP silently not running — until a follow-up task extends `RaspConfig` with both
fields. Android is unaffected by the iOS half of this gap.

### App-identity checks (tampering / untrusted install source)

App-integrity (tampering) and unofficial-store detection require configuring the
per-flavor Android `packageName` + release `signingCertHashes` (and, on iOS, `teamId`/
`watcherMail`, see above). These are per-app **deployment** config and are NOT yet wired
through `RaspConfig`/`AppManifest`, so `androidConfig` is currently null → those specific
checks are inactive. Setting them statically is deliberately avoided because the app uses
flavor `applicationId` suffixes (`.dev`/`.beta`), so a static base package name would
false-positive as tampering.

Device-level checks (root/jailbreak, hooking, debugger, emulator, and the OS-version gate)
DO run today — this gap is scoped to app-identity checks only. Tracked as a follow-up
("app-identity RASP config").
