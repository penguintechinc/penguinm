/**
 * Release signing convention, applied from each app's `app/build.gradle.kts` after
 * `penguin-android.gradle.kts`. Wires the four `PENGUIN_ANDROID_*` secrets from the
 * environment onto the `release` signing config and hard-fails any `*Release` build
 * when one is missing — release is never signed with the debug key (client.md Build &
 * Distribution; §6 of the design spec).
 */

import com.android.build.api.dsl.ApplicationExtension

val envKeystorePath = "PENGUIN_ANDROID_KEYSTORE_PATH"
val envKeystorePassword = "PENGUIN_ANDROID_KEYSTORE_PASSWORD"
val envKeyAlias = "PENGUIN_ANDROID_KEY_ALIAS"
val envKeyPassword = "PENGUIN_ANDROID_KEY_PASSWORD"
val releaseSigningEnvVars = listOf(envKeystorePath, envKeystorePassword, envKeyAlias, envKeyPassword)

/**
 * True only once every PENGUIN_ANDROID_* signing secret is present AND non-blank in the
 * environment — a var exported as an empty string (e.g. an unset CI secret interpolated
 * into `KEY=""`) must fail the same as a genuinely missing one, not silently sign with
 * an empty keystore path/password/alias.
 */
val hasReleaseSigningEnv = releaseSigningEnvVars.all { !System.getenv(it).isNullOrBlank() }

extensions.configure<ApplicationExtension> {
    signingConfigs {
        create("release") {
            if (hasReleaseSigningEnv) {
                storeFile = file(System.getenv(envKeystorePath)!!)
                storePassword = System.getenv(envKeystorePassword)
                keyAlias = System.getenv(envKeyAlias)
                keyPassword = System.getenv(envKeyPassword)
            }
            // When env vars are absent this signing config is left incomplete; the
            // taskGraph check below fails the build before any *Release task can run
            // with it, so an incomplete config is never actually used to sign anything,
            // and the release build type never falls back to the debug signingConfig.
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Deferred to task-graph time (not configuration time) so `flutter analyze`,
// `./gradlew help`, and every debug/profile/dev build keep working without the signing
// secrets present — only a requested task whose name contains "Release" (any flavor:
// assembleDevRelease, bundleProdRelease, ...) triggers the check below.
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { it.name.contains("Release", ignoreCase = true) }
    if (buildingRelease) {
        check(hasReleaseSigningEnv) {
            "Release signing requires PENGUIN_ANDROID_KEYSTORE_PATH, PENGUIN_ANDROID_KEYSTORE_PASSWORD, PENGUIN_ANDROID_KEY_ALIAS, PENGUIN_ANDROID_KEY_PASSWORD"
        }
    }
}
