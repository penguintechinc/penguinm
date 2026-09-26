/**
 * Shared Android build convention for every penguinm app. Applied from each app's
 * `app/build.gradle.kts` via
 * `apply(from = "../../../../platform/android/gradle/penguin-android.gradle.kts")`,
 * after that file's `plugins {}` block has already applied `com.android.application`
 * and `org.jetbrains.kotlin.android` (their classes must be on the script classpath
 * for the `extensions.configure<...>` calls below to resolve).
 *
 * Pins the SDK/NDK/JVM/ABI/flavor conventions from spec §6
 * (docs/superpowers/specs/2026-09-14-penguinm-monorepo-design.md) in one place so no
 * app hand-rolls its own compileSdk/targetSdk/minSdk/NDK/flavor setup. AGP (9.0.1) and
 * Kotlin (2.3.20) are pinned in libs.versions.toml + each app's settings.gradle.kts,
 * not here — this file only configures the `com.android.application` extension once
 * those plugins are already applied.
 */

import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.variant.ApplicationAndroidComponentsExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

/**
 * Human-readable app name each flavor's `app_name` resValue is derived from. Every
 * app/build.gradle.kts must set `project.extra["penguinDisplayName"]` BEFORE applying
 * this script — it is read eagerly below, not lazily, since this shared script has no
 * other way to know an app's display name.
 */
val displayName =
    project.extra["penguinDisplayName"] as? String
        ?: error(
            "app/build.gradle.kts must set project.extra[\"penguinDisplayName\"] " +
                "before applying penguin-android.gradle.kts",
        )

extensions.configure<ApplicationExtension> {
    // Flutter 3.44.8 defaults (spec §6) — pinned explicitly rather than delegated to
    // `flutter.compileSdkVersion` / `flutter.targetSdkVersion` / `flutter.ndkVersion` so
    // a Flutter upgrade can never silently drift these without a reviewed change here.
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    defaultConfig {
        minSdk = 24
        targetSdk = 36

        // Baseline (inherited by every build type unless overridden below): arm64-v8a +
        // x86_64 cover every current physical device and every CI/local emulator.
        ndk {
            abiFilters += setOf("arm64-v8a", "x86_64")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // AGP 9 disables per-flavor `resValue` by default; every env flavor below sets its
    // on-device `app_name` via resValue, so the feature must be explicitly enabled or
    // configuration fails with "Product Flavor ... contains custom resource values, but
    // the feature is disabled."
    buildFeatures {
        resValues = true
    }

    // `env` is the sole flavor dimension: dev/beta/prod select the applicationId
    // suffix, the on-device app name, and (via
    // `--dart-define-from-file=env/<flavor>.json`) which backend the app talks to.
    // Only the dev flavor's manifest (app/src/dev/AndroidManifest.xml) allows
    // cleartext traffic — beta/prod stay HTTPS-only.
    flavorDimensions += "env"

    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "$displayName Dev")
        }
        create("beta") {
            dimension = "env"
            applicationIdSuffix = ".beta"
            resValue("string", "app_name", "$displayName Beta")
        }
        create("prod") {
            dimension = "env"
            resValue("string", "app_name", displayName)
        }
    }

    buildTypes {
        // Per-buildType `ndk.abiFilters` below is a full explicit set, not a delta on
        // top of `defaultConfig` — AGP replaces (does not union) the ABI filter set
        // when a build type declares its own, so each block must list every ABI it
        // wants. This keys the widened ABI set to the `release` *variant* itself
        // (merged the same way regardless of how Gradle was invoked — `assembleRelease`,
        // an IDE sync, or an aggregate `./gradlew build`), not to which task name was
        // typed on the command line.
        getByName("release") {
            isMinifyEnabled = true
            // 32-bit hardware (armeabi-v7a) still ships in the field; only release
            // artifacts pay the extra native-lib size for it — build-android.sh ships
            // both `apk` and `aab` release artifacts, and an `aab` must already contain
            // every ABI Play Feature Delivery is expected to split later.
            ndk {
                abiFilters += setOf("arm64-v8a", "x86_64", "armeabi-v7a")
            }
            // Dart-level obfuscation (`--obfuscate --split-debug-info=<dir>`) is a
            // `flutter build` CLI flag, not a Gradle/R8 setting, so it has no DSL
            // equivalent here. tooling/scripts/build-android.sh does not currently pass
            // it — flagged as a gap in the T5 report for the task that owns that
            // script.
        }
        getByName("debug") {
            ndk {
                abiFilters += setOf("arm64-v8a", "x86_64")
            }
        }
    }
}

/**
 * Configure the `appAuthRedirectScheme` manifest placeholder for each variant.
 * flutter_appauth requires this placeholder to inject the correct redirect scheme into
 * the manifest (AndroidManifest.xml references `${appAuthRedirectScheme}`). Each variant
 * gets its own applicationId (base + flavor suffix), so variants can be installed
 * side by side without an app chooser. The redirect scheme follows the variant's
 * applicationId (e.g., `io.penguintech.waddles`, `io.penguintech.waddles.dev`,
 * `io.penguintech.waddles.beta`) so each flavor has its own redirect URI and OAuth
 * callback target.
 */
extensions.configure<ApplicationAndroidComponentsExtension> {
    onVariants { variant ->
        variant.manifestPlaceholders.put("appAuthRedirectScheme", variant.applicationId)
    }
}

// The Kotlin Gradle plugin's own `kotlin {}` extension type differs by target and isn't
// worth depending on from a shared script applied via `apply(from = ...)`; configuring
// every KotlinCompile task directly is the documented, target-agnostic way to pin
// jvmTarget from a convention script like this one.
tasks.withType<KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}
