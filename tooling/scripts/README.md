# tooling/scripts

Every script here is `#!/usr/bin/env bash`, `set -euo pipefail`, Bash
3.2-compatible (no `declare -A`, `mapfile`, `&>>`), prints usage on
`-h`/`--help`, and exits non-zero on any failure. Run from anywhere — each
script resolves the repo root itself (`$(dirname "$0")/../..`).

| Script | Does | Fails when |
|---|---|---|
| `install-pre-commit.sh [--verify]` | Installs the git hooks declared in `.pre-commit-config.yaml` via the `pre-commit` framework (never hand-written hooks); `--verify` reports install state without installing | a hook is missing, not executable, empty, doesn't invoke the pre-commit framework, or `.pre-commit-config.yaml` is missing an expected hook id |
| `check-pins.sh [ROOT_DIR]` | Scans every `pubspec.yaml`, `.github/workflows/*.yml`, and `tooling/docker/Dockerfile.flutter-android` for mutable refs; asserts `.fvmrc`/`.flutter-version`/Dockerfile/workflow Flutter-version pins agree | any `^`/`~`/`any`/range dependency, a git dependency without a 40-hex `ref:`, an unpinned `uses:`, a missing `@sha256:` digest, a version-pin disagreement, or 0 pubspecs found |
| `coverage-gate.sh [--min PERCENT] [ROOT_DIR]` | Parses `coverage/lcov.info` per package (`packages/* shells/* apps/* platform/android/plugins/* tooling/otlp_sink`, `packages/flutter_libs/example` excluded) via `awk` (`LF:`/`LH:` sums — `lcov` is not required) | any package below the threshold (default 90%), any counted package has `LF=0`, or 0 packages counted |
| `check-logging.sh [ROOT_DIR]` | Scans `packages/*/lib shells/*/lib apps/*/lib` for hand-rolled logging | 0 files scanned, any `print(`/`debugPrint(`/`developer.log(` found, or `PenguinLogger` is never referenced under `shells/` |
| `telemetry-validate.sh` | Starts `tooling/otlp_sink` on `127.0.0.1:4318`, runs `apps/penguin_reference`'s telemetry smoke test against it, asserts the sink received real records | sink doesn't answer `/summary` within 30s, sink exits early, the smoke test fails, or `logRecords`/`metricDataPoints`/`histograms`/`spans` < 1 |
| `new-app.sh [--overwrite] <name> <product_key> <display_name>` | Scaffolds `apps/<name>` (`flutter create` on first run only, then `mason make penguin_app` from `templates/penguin_app`), registers it in the root `pubspec.yaml` `workspace:` list (and `melos.yaml`/CI matrix where recognizable) | `<name>` is not snake_case, or the app dir already exists without `--overwrite` |
| `build-android.sh <app> <flavor> [apk\|aab]` | Runs `flutter build` for `apps/<app>` inside `penguinm/flutter-android:local` (`docker run --rm -u 1000 -v "$PWD":/work`), copies the artifact to `build/artifacts/<app>/` | app dir missing, image missing (`make docker-build` first), `env/<flavor>.json` missing, build fails, or no artifact produced |
| `version.sh` | Applies `VERSION` (+ epoch build number) to every `apps/*/pubspec.yaml` `version:` field | `VERSION` missing/malformed, an app pubspec has no `version:` field, or no app pubspecs found |

## Testability: optional `ROOT_DIR` argument

`check-pins.sh`, `coverage-gate.sh`, and `check-logging.sh` accept an
optional trailing `ROOT_DIR` argument (default: repo root) so they can be
exercised against an isolated fixture directory in tests without needing a
full repo scaffold — e.g.:

```bash
tooling/scripts/check-pins.sh /tmp/fixtures/good      # exit 0
tooling/scripts/check-pins.sh /tmp/fixtures/bad       # exit 1, offending lines printed
tooling/scripts/coverage-gate.sh /tmp/fixtures/pass95 # exit 0
tooling/scripts/coverage-gate.sh /tmp/fixtures/fail80 # exit 1
```

## Hooks (`.pre-commit-config.yaml`)

Hooks run via the `pre-commit` framework only — see the `setup-git-hooks`
skill. Most hooks in this repo use `language: system` against the
already-pinned toolchain (gitleaks, shellcheck, hadolint, zizmor, trivy,
osv-scanner, semgrep — versions asserted by `check-pins.sh` /
`.github/workflows/security.yml`) rather than pre-commit's own per-hook
environment management, to avoid slow golang/docker builds duplicating CI's
own pinning.

| Stage | Hooks |
|---|---|
| pre-commit | hygiene (`pre-commit-hooks`), `gitleaks`, `shellcheck`, `dart-format`, `flutter-analyze` (affected packages only), `zizmor` (workflows staged), `hadolint-flutter-android` (Dockerfile staged) |
| pre-push | `trivy-fs`, `osv-scanner`, `semgrep` |

Install/verify: `make install-hooks` / `make verify-hooks`, or directly via
`tooling/scripts/install-pre-commit.sh [--verify]`.
