# platform/android/gradle/

Shared Gradle Kotlin-DSL convention scripts, applied from every app's
`android/app/build.gradle.kts`. Nothing here is a Gradle plugin — these are plain
scripts brought in with `apply(from = "...")`, configuring the `com.android.application`
extension that the app's own `plugins {}` block already applied.

| File | Applied from | Owns |
|---|---|---|
| `libs.versions.toml` | each app's `android/settings.gradle.kts` (`dependencyResolutionManagement.versionCatalogs`) | AGP `9.0.1`, Kotlin `2.3.20`, Flutter plugin-loader `1.0.0` — the version catalog `libs.*` for use in `build.gradle.kts` dependency declarations |
| `penguin-android.gradle.kts` | `app/build.gradle.kts` | `compileSdk`/`targetSdk 36`, `minSdk 24`, NDK `28.2.13676358`, JVM 17, `dev`/`beta`/`prod` flavors (`env` dimension), per-flavor `applicationIdSuffix` + `app_name` resValue, `appAuthRedirectScheme` manifest placeholder per variant (flutter_appauth callback), release `isMinifyEnabled` + widened ABI filters |
| `signing.gradle.kts` | `app/build.gradle.kts`, after `penguin-android.gradle.kts` | env-only release signing (`PENGUIN_ANDROID_KEYSTORE_PATH`, `PENGUIN_ANDROID_KEYSTORE_PASSWORD`, `PENGUIN_ANDROID_KEY_ALIAS`, `PENGUIN_ANDROID_KEY_PASSWORD`); fails any `*Release` task when one is missing |

## Why `apply(from = ...)` instead of a real convention plugin

A real Gradle convention plugin (`build-logic/` composite build, `#java-gradle-plugin`)
is the more idiomatic long-term answer, but needs its own Gradle module + Kotlin
toolchain wiring that this repo's Java/Gradle-less host cannot validate yet (Gradle
execution is deferred to the toolchain image — see `tooling/docker/`). Plain
`apply(from = ...)` scripts need no extra build module and are exactly what
`flutter create`'s own generated files already use for `local.properties` /
`flutter.gradle`, so app `build.gradle.kts` files stay familiar.

## Adding a new app

Point its `android/settings.gradle.kts` and `android/app/build.gradle.kts` at these
files the same way `apps/penguin_reference` and `apps/penguincloud` do — see
`tooling/scripts/new-app.sh`, which wires this automatically. Never copy these files
into a new app's `android/` directory; apply them from the shared location so a
convention change (an SDK bump, a new flavor) only has to happen once.

## Keeping AGP/Kotlin versions in sync

`libs.versions.toml` is the source of truth, but Gradle's settings-phase plugin
resolution (`pluginManagement { plugins { id(...) version "..." } }` in each app's
`settings.gradle.kts`) cannot dereference an external catalog file at that point in the
build lifecycle, so the same version strings are also declared literally there. Bump
both together.
