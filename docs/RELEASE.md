# Release — Versioning, Play Store, CI/CD

## Versioning

**Monorepo versioning**: every app ships the **same version** as the repo. Version comes from root `VERSION` file (e.g., `0.1.0`), applied to every app's `pubspec.yaml` on `make version`.

```bash
# Apply VERSION (+ epoch build) to every app pubspec
make version
```

This updates:
```yaml
version: 0.1.0+1630703240  # version + epoch timestamp as build number
```

The epoch build number increments on every release build, ensuring Play Store sees it as a newer build even if version didn't change.

### Semantic Versioning

**Major.Minor.Patch**:
- **Major**: breaking API/feature changes or major product shift
- **Minor**: new features, backward compatible
- **Patch**: bug fixes, backward compatible

Example progression: `0.1.0` → `0.2.0` (new feature) → `0.2.1` (bug fix) → `1.0.0` (general availability).

## Build Variants (Flavors)

Three flavors: `dev`, `beta`, `prod`. Each has its own:
- **APK applicationId**: `io.penguintech.<app>` (dev: + `.dev`, beta: + `.beta`)
- **Config**: `env/{dev,beta,prod}.json`
- **Signing**: release builds require signing env vars (prod only)

| Flavor | API Base | Use | Signed |
|---|---|---|---|
| dev | http://127.0.0.1:8000 | Local development | Debug key |
| beta | https://myproduct.penguintech.cloud | Testing | Debug key |
| prod | https://myproduct.app | Production | Release key (from env) |

## Building Locally

```bash
# Debug APK (dev flavor)
flutter run --flavor dev

# Release APK (prod flavor, local build for testing)
flutter build apk --release --flavor prod --dart-define-from-file=env/prod.json

# Release AAB (for Play Store)
flutter build appbundle --release --flavor prod --dart-define-from-file=env/prod.json
```

**Never sign release builds with the debug key.** The signing workflow requires:
- `PENGUIN_ANDROID_KEYSTORE_PATH` (path to .jks or .keystore)
- `PENGUIN_ANDROID_KEYSTORE_PASSWORD`
- `PENGUIN_ANDROID_KEY_ALIAS`
- `PENGUIN_ANDROID_KEY_PASSWORD`

If any are missing, the build fails (safe).

## CI/CD Workflows

### ci.yml (Every PR, commit to release/* and main)

1. **Dart jobs**: `flutter analyze`, `dart format`, every package `flutter test --coverage`, `coverage-gate.sh`
2. **Android jobs**: matrix over apps, `flutter build apk --debug --flavor dev`, upload artifact
3. **Security**: gitleaks, trivy, osv-scanner, semgrep, zizmor, hadolint
4. **Telemetry**: `penguin_reference` smoke test, `tooling/otlp_sink` validates ≥1 log, ≥1 metric, ≥1 histogram
5. **Pins**: `check-pins.sh` verifies all versions are exact, Flutter 3.44.8 consistent

### release-android.yml (On GitHub release: types: [prereleased, released])

1. **Matrix** over `[penguin_reference, penguincloud]` (other apps added by their owners)
2. **Build**: signed AAB (`prod` flavor) inside toolchain image
3. **Signing secrets**: env vars from GitHub Actions secrets (never CLI args)
4. **Upload artifact**: AAB attached to the release
5. **Play Store upload**:
   - **Prerelease**: upload to `internal` track (testers only)
   - **Released**: upload to `production` track (public)

### toolchain-image.yml (On changes to tooling/docker/**, workflow_dispatch)

Builds and pushes `ghcr.io/penguintechinc/penguinm/flutter-android:<version>-<epoch64>`.

**First publish**: digest is pinned in `ci.yml` and `release-android.yml` (plan task T8/T9 records it).

### e2e-android.yml (workflow_dispatch, release)

Android emulator (API 35, x86_64) runs `integration_test/` for each app.

## Release Procedure

### 1. Update Version & CHANGELOG

Edit root `VERSION`:
```
0.1.1
```

Edit each app's `CHANGELOG.md`:
```markdown
## 0.1.1 - 2026-09-15

### Fixed
- Fixed offline sync retry logic

### Added
- New springboard feature

### Changed
- Updated UI for tablet landscape
```

Commit to release branch.

### 2. Run Pre-Release Tests

```bash
make pre-commit  # Must pass
make smoke-test  # Must pass
make test        # Must pass
```

### 3. Tag and Release on GitHub

```bash
git tag -a v0.1.1 -m "Release v0.1.1"
git push origin v0.1.1
gh release create v0.1.1 --prerelease  # beta/gamma (GitHub pre-release)
gh release create v0.1.1                # prod (GitHub release)
```

(or use GitHub web UI to create release)

### 4. CI/CD Automation Kicks In

**Prerelease** (GitHub pre-release):
- `release-android.yml` builds signed AAB (`prod` flavor)
- Uploads to Play Store `internal` track (testers only)
- GitHub Actions completes ✅

**Release** (GitHub release):
- `release-android.yml` builds signed AAB (`prod` flavor)
- Uploads to Play Store `production` track (public)
- GitHub Actions completes ✅

**Note**: The CI release process always uses the `prod` flavor for both prerelease and released. The `beta` flavor is a build variant for internal/manual testing only, not a CI release path.

### 5. Monitor Play Store

- **Internal track**: test with internal testers; ensure no crashes
- **Production track**: monitor crash rates, ANRs, ratings

If critical bug found:
- Hotfix on `release/v0.1.X` branch
- Tag `v0.1.2`
- Create new release
- CI uploads to prod track

## Play Store Setup (One-Time)

Each app requires:

- **Google Play account** and app listing created by product owner
- **Release signing key** (.jks or .keystore) generated and registered
- **GitHub secrets** configured:
  - `PENGUIN_ANDROID_KEYSTORE` (base64-encoded .jks)
  - `PENGUIN_ANDROID_KEYSTORE_PASSWORD`
  - `PENGUIN_ANDROID_KEY_ALIAS`
  - `PENGUIN_ANDROID_KEY_PASSWORD`
  - `GOOGLE_PLAY_KEY_JSON` (service account JSON for uploading)

See `release-android.yml` for how they're used.

## Version Check API

**Backend requirement**: Every app calls `/api/v1/client/version` at startup (non-blocking) to check for updates.

```dart
Future<UpdateStatus> check({required String currentVersion}) {
  // GET /api/v1/client/version?app=<app>&version=<currentVersion>
  // Response: { "latestVersion": "0.2.0", "minimumVersion": "0.1.0", "storeUrl": "..." }
}
```

| Field | Meaning |
|---|---|
| `latestVersion` | Newest available version (e.g., "0.2.0") |
| `minimumVersion` | If client < this, block with update prompt (optional) |
| `storeUrl` | Link to store page; if missing, use `market://details?id=<applicationId>` |

**Client behavior:**
- `currentVersion < minimumVersion` → show non-dismissible "Update required" dialog
- `currentVersion < latestVersion` → show dismissible "Update available" banner

## Hotfix for Production

If a critical bug is discovered in prod:

1. **Checkout release branch**: `git checkout release/v0.1.X`
2. **Create hotfix branch**: `git checkout -b fix/critical-bug`
3. **Fix the bug**, test locally and in CI
4. **Create PR** into `release/v0.1.X`, get review
5. **Merge** when green
6. **Update VERSION** to `0.1.2`
7. **Tag** and create GitHub release
8. CI uploads to prod automatically

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| Play Store upload fails | Signing env vars missing | Check GitHub Actions secrets are set |
| Version not applied to app | `make version` not run | Run `make version` before tagging |
| Tests pass locally but fail in CI | Env file not found | Ensure `env/*.json` are committed (they're config, not secrets) |
| Old version still on Play Store | Upload to wrong track | Check `release-android.yml` upload track (internal vs production) |

See `APP_STANDARDS.md` for build details and `TESTING.md` for pre-release validation.
