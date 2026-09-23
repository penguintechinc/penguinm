# platform/android/plugins/

Empty by design — no penguinm app currently needs a native Android module. This
directory exists (with this file, not a `.gitkeep`) so the location is established
before the first plugin lands; git does not track empty directories otherwise.

Ruling R11 (spec plan ledger): none of the fourteen planned apps' "Anticipated native
modules" (spec §1.1) are scaffolded speculatively. A plugin package is added here only
when an app actually needs one, following the policy in `platform/android/README.md`.

## Adding the first plugin

See `platform/android/README.md`'s "Native-module policy" and "Adding a plugin"
sections. In short: written justification first (why Dart/Flutter cannot do this), then
`platform/android/plugins/<name>/` as a federated Flutter plugin package with Kotlin
under `android/src/main/kotlin/io/penguintech/<name>/` and JUnit tests under
`android/src/test/`.

Once a real plugin exists, `ci.yml`'s `kotlin` job (spec §10) picks it up automatically
via `platform/android/plugins/*/android/src/test` — no CI changes needed to add the
first one.
