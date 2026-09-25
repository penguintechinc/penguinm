# Release — Versioning, Play Store, CI/CD

## Versioning

**Per-app versioning**: each app in `apps/` releases, versions, and branches **independently** — apps do not share a version number. An app's version comes from its own `apps/<app>/VERSION` file (e.g., `0.1.0`), applied to that app's `pubspec.yaml` with `make version APP=<app>`.

```bash
# Apply apps/<app>/VERSION (+ epoch build) to that app's pubspec only
make version APP=penguincloud
```

This updates:
```yaml
version: 0.1.0+1630703240  # apps/penguincloud/VERSION + epoch timestamp as build number
```

The epoch build number increments on every release build, ensuring Play Store sees it as a newer build even if the semantic version didn't change. `version.sh` touches **only** the named app's `pubspec.yaml` — running it for one app has zero effect on any other app's version.

**Shared-library versioning**: `packages/` and `shells/penguin_app_shell` are versioned with the **monorepo** as a whole, via the root `VERSION` file. Root `VERSION` is the shared-library version only — it no longer drives any `apps/*/pubspec.yaml` (that changed when per-app versioning landed; see `docs/ARCHITECTURE.md`). Shared-library release tooling that consumes root `VERSION` is a separate, not-yet-built workstream.

### Semantic Versioning

**Major.Minor.Patch**, per app:
- **Major**: breaking API/feature changes or major product shift
- **Minor**: new features, backward compatible
- **Patch**: bug fixes, backward compatible

Example progression for one app: `0.1.0` → `0.2.0` (new feature) → `0.2.1` (bug fix) → `1.0.0` (general availability). Two apps can be at completely different versions at the same time (e.g. `penguin_reference` at `0.3.0` while `penguincloud` is at `1.0.2`) — that's expected, not a drift bug.

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

### ci.yml (Every PR, commit to release/** and main)

1. **Dart jobs**: `flutter analyze`, `dart format`, every package `flutter test --coverage`, `coverage-gate.sh`
2. **Android jobs**: matrix over apps, `flutter build apk --debug --flavor dev`, upload artifact
3. **Security**: gitleaks, trivy, osv-scanner, semgrep, zizmor, hadolint
4. **Telemetry**: `penguin_reference` smoke test, `tooling/otlp_sink` validates ≥1 log, ≥1 metric, ≥1 histogram
5. **Pins**: `check-pins.sh` verifies all versions are exact, Flutter 3.44.8 consistent

`ci.yml` still runs a debug-build matrix over every app on every PR/push — that's unrelated to release versioning and continues unchanged. Only the **release** path (`release-android.yml`, below) is per-app.

### release-android.yml (On GitHub release: types: [prereleased, released], tag `<app>/vX.Y.Z`)

1. **Tag parsing (fail-closed)**: the release's tag (`github.event.release.tag_name`) is parsed as `<app>/vX.Y.Z`. The app slug — everything before the first `/` — is validated against the known-app allowlist in the workflow (`penguin_reference`, `penguincloud`; grows as apps are scaffolded — `apps/gazer` is excluded until its integration lands). A tag that doesn't match the `<app>/vX.Y.Z` pattern, or names an app not on the allowlist, fails the job before any build step runs — no matrix, no fallback build.
2. **Build**: signed AAB (`prod` flavor) for **only** the tagged app, inside the toolchain image
3. **Signing secrets**: env vars from GitHub Actions secrets (never CLI args)
4. **Upload artifact**: AAB attached to the release
5. **Play Store upload**:
   - **Prerelease**: upload to `internal` track (testers only)
   - **Released**: upload to `production` track (public)

Each app's release is fully independent — tagging `penguincloud/v1.2.0` builds and ships only PenguinCloud; `penguin_reference` (or any other app) is untouched by that release.

### toolchain-image.yml (On changes to tooling/docker/**, workflow_dispatch)

Builds and pushes `ghcr.io/penguintechinc/penguinm/flutter-android:<version>-<epoch64>`.

**First publish**: digest is pinned in `ci.yml` and `release-android.yml` (plan task T8/T9 records it).

### e2e-android.yml (workflow_dispatch, release)

Android emulator (API 35, x86_64) runs `integration_test/` for each app.

## Release Procedure (Per App)

Every step below targets **one app**. Run the full procedure again, independently, for each app you're releasing — there is no "release everything at once."

### 1. Update Version & CHANGELOG

Edit that app's version file, `apps/<app>/VERSION`:
```
0.1.1
```

Edit that same app's `CHANGELOG.md`:
```markdown
## 0.1.1 - 2026-09-15

### Fixed
- Fixed offline sync retry logic

### Added
- New springboard feature

### Changed
- Updated UI for tablet landscape
```

Commit to that app's release branch, `release/<app>/vX.Y.X` (e.g. `release/penguincloud/v0.1.X`).

### 2. Run Pre-Release Tests

```bash
make pre-commit  # Must pass
make smoke-test  # Must pass
make test        # Must pass
```

These still run against the whole workspace (shared packages affect every app), even though the version bump and release are scoped to one app.

### 3. Tag and Release on GitHub

```bash
git tag -a penguincloud/v0.1.1 -m "penguincloud release v0.1.1"
git push origin penguincloud/v0.1.1
gh release create penguincloud/v0.1.1 --prerelease  # beta/gamma (GitHub pre-release)
gh release create penguincloud/v0.1.1                # prod (GitHub release)
```

(or use the GitHub web UI — set the tag to `<app>/vX.Y.Z`, exactly matching the app's directory name under `apps/`)

### 4. CI/CD Automation Kicks In

**Prerelease** (GitHub pre-release):
- `release-android.yml` parses the tag, validates the app, and builds the signed AAB (`prod` flavor) for that app only
- Uploads to Play Store `internal` track (testers only)
- GitHub Actions completes ✅

**Release** (GitHub release):
- `release-android.yml` parses the tag, validates the app, and builds the signed AAB (`prod` flavor) for that app only
- Uploads to Play Store `production` track (public)
- GitHub Actions completes ✅

**Note**: The CI release process always uses the `prod` flavor for both prerelease and released. The `beta` flavor is a build variant for internal/manual testing only, not a CI release path.

### 5. Monitor Play Store

- **Internal track**: test with internal testers; ensure no crashes
- **Production track**: monitor crash rates, ANRs, ratings

If a critical bug is found for that app:
- Hotfix on its `release/<app>/v0.1.X` branch
- Tag `<app>/v0.1.2`
- Create new release
- CI uploads to prod track (that app only)

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

Each app queries its own `app=<app>` version state — `latestVersion`/`minimumVersion` are per-app values on the backend, matching per-app versioning on the client.

## Hotfix for Production

If a critical bug is discovered in prod for app `<app>`:

1. **Checkout that app's release branch**: `git checkout release/<app>/v0.1.X`
2. **Create hotfix branch**: `git checkout -b fix/critical-bug`
3. **Fix the bug**, test locally and in CI
4. **Create PR** into `release/<app>/v0.1.X`, get review
5. **Merge** when green
6. **Update** `apps/<app>/VERSION` to `0.1.2`
7. **Tag** `<app>/v0.1.2` and create a GitHub release
8. CI uploads to prod automatically — for that app only

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| Play Store upload fails | Signing env vars missing | Check GitHub Actions secrets are set |
| Version not applied to app | `make version APP=<app>` not run, or wrong `APP=` | Run `make version APP=<app>` before tagging; `make version` with no `APP=` fails with a usage message |
| `release-android.yml` fails at tag parsing | Tag isn't `<app>/vX.Y.Z`, or `<app>` isn't in the workflow's known-app allowlist | Re-tag as `<app>/vX.Y.Z` where `<app>` matches an `apps/` directory name exactly; add new apps to the allowlist in `release-android.yml` as they're scaffolded |
| Tests pass locally but fail in CI | Env file not found | Ensure `env/*.json` are committed (they're config, not secrets) |
| Old version still on Play Store | Upload to wrong track | Check `release-android.yml` upload track (internal vs production) |

See `APP_STANDARDS.md` for build details and `TESTING.md` for pre-release validation.
