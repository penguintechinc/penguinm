# platform/android/

Cross-app Android platform code: shared Gradle conventions (`gradle/`) and federated
native plugin packages (`plugins/`). Every penguinm app applies both; neither is ever
copied into an app's own `android/` directory.

| Directory | Contents |
|---|---|
| `gradle/` | Version catalog + convention scripts every app's Gradle files apply — see `gradle/README.md` |
| `plugins/` | Federated Flutter plugin packages with native Android (Kotlin) code — currently empty, see `plugins/README.md` |

## Native-module policy

Dart/Flutter is the default for every app. A native Kotlin module is justified only
when Dart genuinely cannot do the job — hardware/OS integration with no maintained
Dart-callable API (Camera2/UVC pipelines, `VpnService`, Credential Manager/passkeys,
hardware-backed keystores, background USB/BLE). This mirrors `client.md`'s "Dart unless
Dart cannot do the job" rule and the per-app "Anticipated native modules" column in
spec §1.1 (`docs/superpowers/specs/2026-09-14-penguinm-monorepo-design.md`).

Every native module needs a written justification per `docs/NATIVE_MODULES.md` (added
once the first plugin lands) before it's added to `plugins/`, covering: what Dart/Flutter
API was checked and found insufficient, the plugin's scope, and its test plan (JUnit for
the Kotlin side, `flutter_test` for the Dart API surface). Security-sensitive plugins
(credential storage, VPN tunnels) additionally need a `security.md`-conformant review —
no plaintext secrets, no logging of tokens/PII.

## Adding a plugin

1. Confirm the justification above and get it reviewed.
2. Scaffold `platform/android/plugins/<name>/` as a federated Flutter plugin package
   (`flutter: plugin: platforms: android:` in its `pubspec.yaml`), Kotlin under
   `android/src/main/kotlin/io/penguintech/<name>/`, JUnit tests under
   `android/src/test/`, and a Dart API + tests in `lib/` + `test/` — see spec §6.
3. Add it as a path dependency in every consuming app's `pubspec.yaml` (owned by the
   task that owns that app's `pubspec.yaml` — do not edit it from inside the plugin's
   own task).
4. Wire `platform/android/gradle/penguin-android.gradle.kts`'s consuming apps unchanged
   — Flutter's plugin registration handles the Gradle-level include automatically.

iOS implementations are added only once iOS is sequenced (`platform/ios/README.md`).
