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
