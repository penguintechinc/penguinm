pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// AGP/Kotlin versions are literal here — Gradle's settings-phase plugin resolution
// cannot dereference an external catalog file — but must match
// platform/android/gradle/libs.versions.toml, which is the source of truth and is
// wired in below as the `libs` version catalog for build.gradle.kts dependencies.
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

dependencyResolutionManagement {
    versionCatalogs {
        create("libs") {
            from(files("../../../platform/android/gradle/libs.versions.toml"))
        }
    }
}

include(":app")
