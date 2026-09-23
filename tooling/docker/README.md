# Flutter Android Toolchain Image

Containerized build environment for Flutter 3.44.8 + Android SDK development.

## What's Inside

| Tool | Version | Purpose |
|------|---------|---------|
| Debian Bookworm Slim | `88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171` | Base OS image |
| OpenJDK 17 | `17.0.20.1+1-1~deb12u1` | Java compiler for Android build tools |
| Flutter SDK | `3.44.8` (rev: `058e0af2c2`) | Flutter framework |
| Android Platform | `36` | Target Android API level |
| Android Build-Tools | `36.0.0` | Gradle build toolchain |
| Android NDK | `28.2.13676358` (r28c) | Native development kit, installed via curl for robustness |
| Git | `1:2.39.5-0+deb12u3` | Version control |
| Clang | `1:14.0-55.7~deb12u1` | C/C++ compiler for native builds |
| CMake | `3.25.1-1` | Build system for native code |
| Ninja | `1.11.1-2~deb12u1` | Fast build tool |

## Building Locally

### Build the Toolchain Stage

```bash
docker build --target toolchain \
  -f tooling/docker/Dockerfile.flutter-android \
  -t penguinm/flutter-android:local \
  .
```

This builds **only** the toolchain stage containing all build tools. Subsequent stages (deps, analyze, test, build) are used internally in CI and are optional for local development.

Expected build time: ~80 minutes cold (measured 2026-09-14: 4921 s, dominated by Android SDK/NDK downloads and Flutter precache); ~3 minutes when only the late user/permission layers change (cache hit on everything before them).

### Verify the Build

```bash
# Verify Flutter version
docker run --rm penguinm/flutter-android:local flutter --version

# Verify non-root user (should output 1000)
docker run --rm penguinm/flutter-android:local id -u
```

### CI Usage: `--user <uid>:0` Contract

The toolchain image requires a specific permissions contract for CI environments (e.g., GitHub Actions) that run as a non-root user other than 1000:

```bash
# Run with a different UID but group 0 (root group)
docker run --rm --user 1001:0 \
  -v $(pwd):/work \
  -w /work \
  penguinm/flutter-android:local \
  flutter build apk --release
```

**Requirements:**
- The image's Flutter, Android SDK, and pub cache directories are group-0 owned with `g=u` permissions
- This allows any UID in group 0 to read and write to those directories
- `appuser` (UID 1000) has **primary group 0** (arbitrary-UID pattern) and the image's default is `USER 1000:0`, so the default user and CI's `--user 1001:0` share the same group-0 write access
- A bind-mounted `/work` must be writable by the container UID: in CI the runner checks out as UID 1001, matching `--user 1001:0`; locally, run as your own UID with group 0 (`--user "$(id -u):0"`) so build output lands owned by you
- Always pass group `0` — never another group — or the toolchain directories become read-only and Flutter fails writing its engine stamp

### Use the Toolchain Interactively

```bash
docker run --rm -it \
  -v $(pwd):/work \
  penguinm/flutter-android:local \
  /bin/bash
```

## How CI Uses This Image

### Build Process

1. **Publish workflow** (`toolchain-image.yml`):
   - Triggered on changes to `tooling/docker/Dockerfile.flutter-android`
   - Builds the `toolchain` stage and publishes to `ghcr.io/penguintechinc/penguinm/flutter-android:3.44.8`
   - Tags include: `:3.44.8-<run_number>` (ephemeral) and `:3.44.8` (latest)

2. **CI workflows** (`ci.yml`, `release-android.yml`, `e2e-android.yml`):
   - Reference the published image by digest (pinned in CI workflows)
   - Run Android builds inside the image:
     ```bash
     docker run --rm \
       -v $(pwd):/work \
       ghcr.io/penguintechinc/penguinm/flutter-android@sha256:<digest> \
       flutter build apk --release
     ```

### Environment Variables

The toolchain respects standard Flutter/Android environment variables:

| Variable | Value | Purpose |
|----------|-------|---------|
| `FLUTTER_HOME` | `/opt/flutter` | Flutter installation directory |
| `ANDROID_HOME` | `/opt/android-sdk` | Android SDK root |
| `ANDROID_SDK_ROOT` | `/opt/android-sdk` | Android SDK root (alternate name) |
| `PATH` | Includes Flutter/Android tools | Command-line tool discovery |

## Security & Design

- **Base image**: Debian Bookworm Slim (minimal attack surface)
- **Non-root runtime**: `USER 1000:0` (`appuser`, primary group 0) — process runs as non-root
- **No health check**: Toolchain image is not a runtime service
- **Multi-stage build**: Only the `toolchain` stage is published; intermediate stages validate correctness
- **Pinned versions**: Every dependency pinned to exact version (apt packages, Flutter revision, Android SDK packages)
- **No secrets**: Image contains no API keys, credentials, or sensitive configuration

## Pin Table

All versions are locked to exact values to ensure reproducible builds.

| Dependency | Source | Current Version | Pin Method |
|---|---|---|---|
| Debian base | `hub.docker.com` | `bookworm-slim@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171` | SHA256 digest |
| Flutter | GitHub `flutter/flutter` | `3.44.8` (rev: `058e0af2c2`) | Git tag + commit verification + stable branch |
| cmdline-tools | Google `dl.google.com` | `commandlinetools-linux-15859902_latest.zip` | SHA256 hash |
| Android Platform | `sdkmanager` | `android-36` | Explicit version |
| Android Build-Tools | `sdkmanager` | `36.0.0` | Explicit version |
| Android NDK | Google `dl.google.com` (r28c) | `28.2.13676358` | SHA-1 hash + curl download (bypass sdkmanager) |
| JDK | Debian repo | `17.0.20.1+1-1~deb12u1` | Apt package version |
| Git | Debian repo | `1:2.39.5-0+deb12u3` | Apt package version |
| Clang | Debian repo | `1:14.0-55.7~deb12u1` | Apt package version |
| CMake | Debian repo | `3.25.1-1` | Apt package version |
| Ninja | Debian repo | `1.11.1-2~deb12u1` | Apt package version |

## Stall-Resilient Downloads

Large downloads (Android NDK, Flutter artifacts) may encounter slow CDN connections. The toolchain uses curl with stall-speed protection:

- **Speed limit:** 10 KB/s minimum maintained over 60 seconds — slower connections time out
- **Retry logic:** Up to 5 automatic retries with exponential backoff, plus resume support (`-C -`) to avoid re-downloading failed segments
- **Connection timeout:** 30 seconds maximum per connection attempt

These settings ensure builds fail fast on truly broken downloads (bad network, unavailable mirror) rather than hanging for hours.

## Maintenance

### Updating Flutter Version

To update to a new Flutter version:

1. Update `ARG FLUTTER_VERSION=X.Y.Z` in `Dockerfile.flutter-android`
2. Find the commit hash: `git log --oneline --tags | grep vX.Y.Z`
3. Update `ARG FLUTTER_REVISION=<short-sha>` (10-char form)
4. Test locally: `docker build --target toolchain -t penguinm/flutter-android:local .`
5. Verify: `docker run --rm penguinm/flutter-android:local flutter --version`
6. Update `.fvmrc` and `.flutter-version` in the repo root
7. The `toolchain-image.yml` workflow will publish the updated image on next commit

### Updating Android SDK Packages

To update Android SDK packages (Platform, Build-Tools, NDK):

1. Check the latest available versions
2. Update the corresponding `ARG` in `Dockerfile.flutter-android`
3. Rebuild and test locally
4. Update documentation if major changes occur

## Troubleshooting

### Build Fails: "sha256sum -c" Error

The cmdline-tools SHA256 hash is outdated. The hash in the Dockerfile must match the actual download.

**Solution**: Download the latest cmdline-tools, compute its hash, and update both the URL and `CMDLINE_TOOLS_SHA256` ARG.

### Build Fails: Flutter Revision Mismatch

The Flutter repository might have changed since the tag was created.

**Solution**: Verify the short revision with `git log` and update `FLUTTER_REVISION` ARG.

### Image Build Hangs During `flutter precache --android`

This is normal and expected — the first build downloads several GB of Flutter artifacts and Android SDK packages. Subsequent builds will be faster due to Docker layer caching.

**Prevention**: Use `docker build --progress=plain` to see detailed output.

## References

- [Flutter 3.44.8 Release](https://github.com/flutter/flutter/releases/tag/3.44.8)
- [Android SDK Command-line Tools](https://developer.android.com/studio/command-line)
- [Android Platform Versions](https://developer.android.com/guide/topics/manifest/uses-sdk-element)
