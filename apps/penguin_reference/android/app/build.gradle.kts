plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Display name the shared dev/beta/prod flavor `app_name` resValues are built from;
// read by platform/android/gradle/penguin-android.gradle.kts. Must be set before that
// script is applied below.
project.extra["penguinDisplayName"] = "Penguin Reference"

// Shared conventions: SDK levels, NDK, JVM 17, dev/beta/prod flavors, minify — see
// platform/android/gradle/README.md. Applied before signing so signing's buildTypes
// configuration composes onto the release build type these scripts both touch.
apply(from = "../../../../platform/android/gradle/penguin-android.gradle.kts")
apply(from = "../../../../platform/android/gradle/signing.gradle.kts")

android {
    namespace = "io.penguintech.penguin_reference"

    defaultConfig {
        applicationId = "io.penguintech.penguin_reference"
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
}

flutter {
    source = "../.."
}

// freerasp (Talsec RASP SDK, pinned exact at packages/penguin_rasp/pubspec.yaml) is a
// transitive native-Android Flutter plugin dependency of every app via
// shells/penguin_app_shell -> packages/penguin_rasp -> freerasp — already visible in
// this module's generated GeneratedPluginRegistrant.java regardless of whether this
// app's AppManifest.raspPolicy is enabled (plugin registration is pubspec-graph-based,
// not runtime-flag-based). Verified against the published freerasp 8.2.2 package
// (~/.pub-cache/hosted/pub.dev/freerasp-8.2.2/android/build.gradle) and Talsec's docs
// that NO additional Gradle config is required here:
//   - Maven repos: freerasp's own android/build.gradle already injects Talsec's two
//     private repos (europe-west3-maven.pkg.dev/talsec-artifact-repository/{freerasp,
//     common}) via `rootProject.allprojects { repositories { ... } }` when Flutter
//     includes it as a subproject — this app's settings.gradle.kts has no centralized
//     `dependencyResolutionManagement.repositoriesMode` that would block that.
//   - minSdk: freerasp requires minSdkVersion >= 23; penguin-android.gradle.kts already
//     sets minSdk = 24.
//   - AGP/Kotlin/Gradle: freerasp requires AGP >= 8.8.1 / Kotlin >= 2.1.0 / Gradle
//     wrapper >= 8.12.1; this repo pins AGP 9.0.1 / Kotlin 2.3.20 / Gradle 9.1.0.
//   - ProGuard/R8: freerasp bundles its own consumer ProGuard rules in its AAR, applied
//     automatically by R8 to any app that depends on it — no app-side rule needed.
//   - AndroidManifest: no entries required for the threat categories this app's
//     RaspPolicy.defaultBlockThreats actually uses; the optional
//     DETECT_SCREEN_CAPTURE/DETECT_SCREEN_RECORDING/location/Wi-Fi permissions freerasp
//     documents are only needed for threat categories (screenCapture, location
//     spoofing, insecure Wi-Fi) this app's policy does not opt into.
// See docs/RASP.md for the full feature writeup.
