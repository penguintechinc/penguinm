# Gazer Mobile 2.0 — Handoff to penguinm

For a fresh Claude Code session picking up Gazer work in `penguinm`, no prior context assumed.

## State

**M1 is complete and merged here.** Source: waddlebot `feature/gazer-mobile-v2` at
`368df0e4b0bd7a23785b593a243b67ac4e444e68` (SRC_TIP), gated on waddlebot integration
round 11 (`.superpowers/sdd/2026-09-07-gazer-mobile-v2-m1/integration-11-report.md`:
**Status GREEN**, base `63739ffa9103678a1032646042a7b7da57903f2f`, CI run
[`34889954508`](https://github.com/penguintechinc/waddlebot/actions/runs/34889954508),
all jobs success). The app's full commit history (124 commits) was preserved via
`git subtree split --prefix=mobile/gazer` (split tip `d98c3005a8167f2599ab5471d544eac7558ae8b2`,
125-line tree identical to the source) and imported here with `git subtree add
--prefix=gazer` — see `git log --oneline gazer-import` for the full chain, or
`git log --oneline <merge-commit>^2` to walk the pre-move history directly (the plain
`git log -- gazer` path-filter does **not** show it: the merge commit is the first one
whose tree actually has anything at `gazer/`, since the split commits have their content
at repository root — a normal `git subtree` quirk, not a defect).

**Gate numbers, re-verified fresh in this repo** (toolchain image `gazer-toolchain:3.47.2`,
digest `sha256:9a3ac180f359452d5d6b811c5f3185d62301d770fc09da2c2dff610797d09c7c`, pulled not
rebuilt) — compare against waddlebot's own last verification
(`docs/superpowers/plans/2026-09-07-gazer-mobile-v2-m1-verification.md`, run against
integration round 10, so slightly stale — more fix waves landed by round 11):

| Gate | This repo (round 11 code) | waddlebot verification doc (round 10) |
|---|---|---|
| `make mobile-lint` | BUILD SUCCESSFUL (flutter analyze + dart format + ktlintCheck + Android Lint) | PASS |
| `make mobile-test` | **327/327** Dart tests, coverage **93.89%** (1659/1767 lines, 44 files) | 326/326, 93.18% |
| `make mobile-test-android` | **146/146** JUnit tests (23 result files), 0 failures/errors/skips; JaCoCo **96.87%** (557/575 lines) | 126/126 (21 files), 96.76% |
| `make mobile-telemetry-check` | `telemetry sink received: logs=1 metrics=2 histograms=1 spans=2` | identical |
| `make mobile-test-integration` | Dart integration `+2: All tests passed!`; `go-live-unreachable.png` decoded at **53,008 bytes** (byte-identical to the verification doc); `connectedDebugAndroidTest` `Starting 1 tests` / `Finished 1 tests`, BUILD SUCCESSFUL | matches |

Higher counts here than the round-10 doc are expected (more tests landed in the final
fix waves between rounds 10 and 11) — not a discrepancy.

## How to build/test

- **Never invoke flutter/dart/gradle on the host.** Everything routes through
  `make mobile-*` targets in the repo-root `Makefile`, which run inside the
  `gazer-toolchain:3.47.2` container (client.md: containerized toolchain, no host
  Flutter). See the Makefile's `MOBILE_RUN`/`MOBILE_IMAGE` definitions.
- **Never rebuild the toolchain image locally unless the Dockerfile actually changed.**
  `make mobile-toolchain` builds it from `gazer/Dockerfile`; CI's `toolchain` job in
  `.github/workflows/gazer-mobile.yml` does content-hash tagging (`sha256sum
  gazer/Dockerfile | cut -c1-12`) and skips the build+push if that tag already exists in
  `ghcr.io/penguintechinc/penguinm/gazer-toolchain`. On this host specifically, the image
  is kept warm by a `gazer-toolchain-keepalive` container (`docker ps --filter
  name=gazer-toolchain-keepalive`) — do not `docker rmi` it.
- **`/dev/kvm` is required** for `make mobile-test-integration` and `make
  mobile-screenshots` (nested Android emulator). Check `ls -l /dev/kvm` and that your
  user has an ACL entry (`getfacl /dev/kvm`) or is in the `kvm` group. GitHub Actions
  `ubuntu-latest` runners enable it via udev rules in the `integration` job.
- Full target list: `mobile-toolchain`, `mobile-run CMD="..."`, `mobile-lint`,
  `mobile-test`, `mobile-test-android`, `mobile-test-integration`, `mobile-build`,
  `mobile-build-signed`, `mobile-security`, `mobile-codegen`, `mobile-clean`,
  `mobile-telemetry-check`, `seed-mock-data-mobile`, `mobile-screenshots`.
- **Pre-commit/pre-push hooks are real, not a stub** — this repo had no
  `.pre-commit-config.yaml` at all before this PR (every push failed with
  `InvalidConfigError`); it's fixed now (`make install-hooks` / `make verify-hooks`).
  Note the fix in `fix(hooks): pin every non-Gazer hook to the pre-commit stage
  explicitly` — several `pre-commit-hooks` entries ran at push-time too despite
  `default_stages: [pre-commit]`; every hook now has an explicit `stages:` key. If you
  add a new hook, give it an explicit `stages:` too — don't rely on `default_stages`
  alone.
- `gazer-lint` (flutter analyze + dart format + ktlint) and `dockerfile-rootless` run at
  **pre-push**, inside the container via `make mobile-lint` — expect `git push` to take
  as long as that target does.

## Open items

| Item | Status |
|---|---|
| Release signing | **Not set up in penguinm.** Needs: an upload keystore, the four `ANDROID_UPLOAD_KEY_STORE_B64`/`ANDROID_UPLOAD_KEY_STORE_PASSWORD`/`ANDROID_UPLOAD_KEY_ALIAS`/`ANDROID_UPLOAD_KEY_ALIAS_PASSWORD` secrets, and the `gazer-release` GitHub Environment (with a required reviewer), all created fresh in `penguintechinc/penguinm` — none of this carries over from waddlebot. `build-signed` in the workflow is already wired and correctly no-ops until a `gazer-v*` tag exists. |
| CODEOWNERS | **penguinm has no `.github/CODEOWNERS` at all.** Per house rules this must be chosen by a human, never guessed by an agent — ask who owns this repo before merging anything into `main`. |
| Manual physical-device stream/reconnect test | **Never run** (M1 verification doc: DEFERRED, not fabricated) — needs a human with a real phone and a real RTMP endpoint: install, stream 5 min, disable Wi-Fi mid-stream, confirm bitrate ±20% of 2000 kbps, dropped frames <1%, and Streaming→Reconnecting→Streaming recovery without a manual Stop/Go-Live cycle. |
| `rtmps://` rejected | Deliberate M1 scope cut (ruling R40): RootEncoder 2.8.1 validates the cert chain but never the TLS hostname, so `rtmps://` would accept any chain-valid cert for any name. `TargetValidator` rejects the scheme explicitly; planned for a later milestone. |
| `-d emulator-5554` hardcoded | **Accepted for M1**, not a bug to fix reflexively — a single AVD always lands on console port 5554 and the screenshot script already waits for the slot rather than racing another run. Document as a known one-emulator-at-a-time constraint if you add a second parallel emulator job. |
| Notification text during reconnect/idle backoff | **Genuinely open, deferred to M2** (ledgered as NB2 in waddlebot's progress.md) — the persistent notification still reads "Gazer is live" during the backoff/idle window instead of reflecting reconnect state. |
| `encodeFailures` not on the status row | **Checked here — already fixed**, contrary to what older review docs (`final-review-ui.md`) still say. `status_panel.dart` now reads a reactive `telemetryHealthProvider` (`TelemetryHealthStatus.ok/degraded/disabled`), and `GazerTelemetry`'s degraded computation (`gazer_telemetry.dart:520`) includes `encodeFailures`. Confirmed by the passing `gazer_telemetry_health_test.dart` cases in this repo's own `make mobile-test` run (e.g. "a collector that succeeds once and then dies reads as degraded, not exporting"). No action needed — don't re-open it from stale docs. |
| `waddlebot` → `penguinm` rename scope | Deliberately **not done** for app identity: `io.waddlebot.gazer` (Android package id), `waddlebot.gazer.*` (feature flag keys), and the waddlebot backend URLs Gazer talks to as a client are all unchanged — Gazer is still a client of the waddlebot product, only its source repo moved. Only repo-path references (`mobile/gazer` → `gazer/`) and the toolchain image name/OCI source label were updated. |
| Historical docs still say `mobile/gazer` | `docs/superpowers/plans/*-m1.md` (405 hits), the M1 design spec (4), the M1 verification doc (1), and the M2 plan (2, already self-aware) were **left untouched on purpose** — they're point-in-time records of work done in waddlebot; rewriting them would misrepresent history. Don't "fix" these later. |
| Separate, unrelated user directive in flight | waddlebot's `progress.md` (2026-09-14) also records a pending `waddlebot` → `waddles` repo/folder rename, explicitly sequenced to happen **after** this Gazer move lands. Not this session's job — mentioned only so a future session doesn't confuse the two. |

## Next work

- **M2 plan:** `docs/superpowers/plans/2026-09-14-gazer-mobile-v2-m2.md` (imported from
  waddlebot's `docs/gazer-m2-plan` branch). Scope per the user's 2026-09-14 ruling: UVC
  capture card + card audio only (Camera2 `LENS_FACING_EXTERNAL` + USB Audio Class for
  M2; libusb+libuvc JNI fallback for M3) — explicitly **not** preview, not WaddleBot
  login/chat/communities, not multi-destination/RTMPS/SRT/WebRTC. The plan already
  writes every path as `<app>/...` and documents `<app>` = `gazer/` here (see its
  "Global Constraints" section) — it assumes the `Makefile`/workflow move with the app
  under the same target/job names, which is exactly what this PR did.
- **Process:** M1 was executed as a spec → plan → subagent-driven implementation →
  multi-role review (`android`/`dart-core`/`platform`/`ui`) → fix-wave → re-review →
  integration-round loop, tracked in a running `progress.md` ledger with numbered
  `- Ruling:` lines resolving reviewer/planner disagreements (see Appendix below) and
  `USER DECISION`/`USER REQUIREMENT` lines recording out-of-band user calls. The
  `superpowers:writing-plans`, `superpowers:subagent-driven-development`,
  `superpowers:requesting-code-review`, and `superpowers:verification-before-completion`
  skills are the mechanism behind that loop — use them for M2 rather than improvising a
  new process. The full M1 working state (every review/fixwave/integration report, the
  ruling ledger, the two inventory research docs) is copied, uncommitted, into
  `/home/penguin/code/penguinm/.superpowers/sdd/2026-09-07-gazer-mobile-v2-m1/` and
  `/home/penguin/code/penguinm/.superpowers/research/{old-gazer-inventory,penguinm-inventory}.md`
  in the main penguinm checkout (not this worktree) for continuity — `.superpowers/` is
  gitignored, so it will not follow a fresh clone and will not appear in `git status` or
  any diff; copy it again from
  `/home/penguin/code/waddlebot/.worktrees/gazer-mobile-v2/.superpowers/` if it's gone.
- Start M2 in a new `feature/` worktree off this repo's `release/v0.1.X`, same as this
  import PR did.

## Appendix — M1 ruling ledger (verbatim from waddlebot's progress.md)

Every `- Ruling:` line from
`waddlebot:.superpowers/sdd/2026-09-07-gazer-mobile-v2-m1/progress.md`, in original
order. These record every planner/reviewer disagreement resolved during M1 — read them
before assuming a design choice in the code is accidental.

<!-- RULINGS_START -->
- Ruling: R1 l10n output path — Task 2's l10n.yaml `output-dir: lib/l10n/generated` contradicts every later import of `lib/l10n/app_localizations.dart`. Remove the override so gen-l10n emits into the arb dir (Flutter 3.47 default); fix Task 13's "Contract assumptions" text. — Cost if wrong: one import-path sweep.
- Ruling: R2 Task 25 Step 6 anchors on the pre-Task-21 `release.needs` line and its replacement drops `integration`. Anchor on `needs: [build, test, android-unit, security, integration]`, replacement `needs: [toolchain, build, test, android-unit, security, integration]`. — Cost if wrong: tag builds skip the emulator gate.
- Ruling: R3 Tasks 14/15/16 code omits imports of `../services/feature_flags.dart` and `../models/validation_issue.dart` in home_screen.dart, settings_validation.dart, settings_screen.dart (and Task 16's home_screen replacement). Add the imports in those code blocks; turn Task 22 Step 8's "closes a pre-existing gap" import into a verify step; correct Task 13's wrong claim that ValidationIssue lives in target_validator.dart. — Cost if wrong: compile errors at Task 14.
- Ruling: R4 Task 26 tablet screenshot is named `home-idle-tablet.png` in the test but `home-tablet.png` everywhere else. Standardize on `home-tablet.png`. — Cost if wrong: collector fails, one rename.
- Ruling: R5 Task 1 Makefile comment attributes mobile-screenshots/seed-mock-data-mobile to "Tasks 21-22"; they land in Task 26. Fix the comment text. — Cosmetic.
- Ruling: R6 Task 6 Step 9 attributes the JaCoCo pigeon exclusion to Task 1 and misquotes the pattern; it is Task 2's `**/pigeon/**`. Fix the text. — Cosmetic.
- Ruling: R7 Dockerfile must `userdel -r ubuntu` (and `groupdel ubuntu` if it survives) before creating appuser 1000:1000, so the container user matches the host uid used by `docker run --user 1000:1000`. — Cost if wrong: file ownership mismatch on the bind mount; visible immediately.
- Ruling: R8 (rules change 2026-09-09) critical-rules.md now mandates OTel logs+metrics+traces with env-configurable OTLP endpoint for every app; the spec/plan predate it. Add Task 27 "OTel emission" to M1 after Task 26 (Dart opentelemetry SDK, OTLP/http exporter, endpoint from a settings field defaulting to unset = disabled exporter that never breaks the app; logs from GazerLog, histograms for connect latency and bitrate, spans for prepare/start/stop). — Cost if wrong: one extra task; not load-bearing for the phone test.
- Ruling: R9 Flutter tool steps run as appuser: `chown -R appuser:appuser /opt/flutter` after extraction, move `USER appuser` above the flutter config/precache RUN, set `git config --global --add safe.directory /opt/flutter` for appuser, and if `flutter config --no-analytics` is rejected by 3.47.2 use `flutter --disable-analytics`. Android SDK stays root-installed and read-only for appuser (licenses accepted at build). — Cost if wrong: image rebuild (~6 min); no code impact.
- Ruling: R10 the brief's Dockerfile omitted the scanners; install pinned versions in the image: osv-scanner (Google, GitHub release binary + sha256), gitleaks (GitHub release tarball + sha256), semgrep (pip, exact version, in a dedicated venv owned by appuser or system pip with --break-system-packages avoided → use `python3 -m venv /opt/semgrep`). Versions looked up at fix time and recorded in the Dockerfile comments. — Cost if wrong: image rebuild; security target stays broken until fixed.
- Ruling: R11 MainActivity JaCoCo exclusion stands ONLY as a documented, name-scoped exclusion (flutter-create boilerplate has no JVM-testable logic); Task 20 must keep MainActivity a ≤3-line bridge that delegates to a unit-tested factory, and the exclusion comment must say so. Carry to Task 20 dispatch. — Cost if wrong: untested Activity glue hidden from the gate.
- Ruling: R12 the Dockerfile additions in 2b279ccc (additive, exactly pinned, required by the pinned plugin graph) are accepted as Task 2 scope; `fix(gazer-toolchain)` prefix accepted (conventional-commit `fix` is valid; the plan's prefix list is guidance). — Cost if wrong: none.
- Ruling: R13 finding (2) must be narrowed to an explicit by-name disable of the two failing vendored modules; any other subproject's tests stay enabled. Finding (3): capture literal `flutter pub get` solver output for each of the 5 substitutions (temporarily restore the brief's pin, run, capture, revert) into the report; pubspec comments may stay one-line.
- Ruling: R14 CI container jobs run with `options: --user 0:0` (root) ONLY so GitHub's runner steps (checkout, cache, upload-artifact) work; every toolchain command (flutter, dart, gradle, scanners, coverage gate) runs as appuser via `runuser -u appuser -- bash -eo pipefail -c '...'` after `chown -R appuser:appuser "$GITHUB_WORKSPACE"` (and after any cache restore into /home/appuser). Each job prints `id -u` from inside the runuser shell and asserts 1000. Documented in the workflow comments as a GitHub-platform exception, not a rootless-policy exception for the build tools. — Cost if wrong: another red run; no product code impact.
- Ruling: R15 (user directive 2026-09-10: "fan out up to 10 sub agents at a time ... get through tasks till 25") — parallel execution replaces the one-implementer-at-a-time rule. Mechanics: each parallel implementer runs in an isolated git worktree (Agent isolation=worktree) on a temp branch, commits there, never pushes; the controller cherry-picks reviewed commits onto feature/gazer-mobile-v2 in dependency order and pushes; CI on each integration push is the combined gate; conflicts go to a merge-fixer agent, never resolved by the controller by hand. Waves: W1 {4, 6, 17, 25-code}; W2 {5, 7, 8, 9, 10, 18, 6b (swap Task 4's temp GazerErrorCode for the Pigeon enum)}; W3 {11, 19}; W4 {12, 20}; W5 {13}; W6 {14, 15}; W7 {16, 23}; W8 {22, 24}; W9 {27, 21}; W10 {26}. Task 25's human step (keystore + secrets) is the stop point. — Cost if wrong: integration conflicts caught by CI; rework is per-task.
- Ruling: R16 enable Gradle dependency locking for `:app` only via the ROOT android/build.gradle.kts (`project(":app") { dependencyLocking { lockAllConfigurations() } }`), commit android/app/gradle.lockfile, drop `--allow-no-lockfiles`, and assert the scanner's reported package count > 0 for both lockfiles. Root build file chosen so it does not collide with Task 25's concurrent edit of app/build.gradle.kts. — Cost if wrong: lockfile churn when pins change (intended).
- Ruling: R17 fold Important (2) + the duplication minors into one change: composite action .github/actions/run-as-appuser/action.yml (chown workspace + /home/appuser, `id -u` assertion, `export HOME=/home/appuser PUB_CACHE=/home/appuser/.pub-cache GRADLE_USER_HOME=/home/appuser/.gradle`, `set -euo pipefail`, cd, exec) used by every toolchain step; Task 21 reuses it. — Cost if wrong: one CI iteration.
- Ruling: R18 Task 17's commit is integrated only together with Task 20 (feature branch stays lint-green); Task 20's worktree must `git cherry-pick 0165c974` before starting. Task 18/19 do not depend on the manifest. Reports from isolated worktrees are copied into the controller workspace by the controller. — Cost if wrong: a short red-lint window.
- Ruling: R19 harness worktrees are created from the repo's main HEAD, not the feature branch — every parallel implementer must first `git checkout -b <task-branch> <integration-base-sha>` (and cherry-pick named prerequisite commits) before working; reports are written inside the agent worktree and copied by the controller. Dependents may start on an unreviewed prerequisite commit (rework risk accepted for speed per user directive).
- Ruling: R20 coverage_gate.sh (Dart path) must exclude generated sources from the denominator: `lib/**/*.g.dart`, `lib/**/*.freezed.dart`, `lib/pigeon/**`, `lib/l10n/app_localizations*.dart` (mirrors JaCoCo's `**/pigeon/**`); the gate still fails on zero remaining files. Task 6's 25.97% was the generated pipeline.g.dart, not a Flutter bug. — Cost if wrong: hidden untested hand-written code (none of these patterns are hand-written).
- Ruling: R21 "6b" enum swap: Task 4's temporary lib/models/gazer_error_code.dart becomes `export 'package:gazer/pigeon/pipeline.g.dart' show GazerErrorCode;` (member order already identical), so existing imports (Task 4 models, Task 8) keep working and a single enum exists. — Cost if wrong: an import sweep.
- Ruling: R22 StreamTargetSettings gets a private const constructor and a `toString()` override that redacts streamKey/username/password (last-4 masking or '<redacted>'), with a test asserting the secret never appears; bundled into the gate/6b fixer dispatch. — Cost if wrong: a leaked secret in a crash log.
- Ruling: R23 Gradle dependency locking and the osv-scanner gate are scoped to what the app ships: the `:app` release and debug runtime + compile classpaths (`releaseRuntimeClasspath`, `releaseCompileClasspath`, `debugRuntimeClasspath`, `debugCompileClasspath`, and profile equivalents if present) instead of `lockAllConfigurations`. Build-tooling classpaths (AGP internals, ktlint, kotlin compiler, unified test platform) are excluded from THIS gate because they never ship in the APK and are governed by the pinned toolchain versions; the exclusion and its reason are documented in build.gradle.kts and the workflow. Any CVE on a shipped classpath is fixed, never accepted: force guava to 32.0.0-android via resolutionStrategy on those configurations (with a comment naming the GHSA/CVE), and if anything else remains on a shipped classpath the implementer reports it for an upgrade decision. — Cost if wrong: a tooling CVE goes unreported by this gate (mitigation: `make mobile-security` still runs osv-scanner over the full lockfile locally as an advisory step, non-gating, printed count).
- Ruling: R24 attribution change (harness, 2026-09-10): commit messages end with the Co-Authored-By trailer ONLY; the Claude-Session trailer in the plan briefs is no longer used. — Cost if wrong: none.
- Ruling: R25 Task 25 is integrated by PORTING, not cherry-picking: after Task 3's fix round lands on feature/gazer-mobile-v2, a port agent re-applies 967254a0's semantic changes (diff vs its own base) onto the feature HEAD in a fresh worktree branched from the feature HEAD, re-runs the four local verifications, commits; the task review happens once, on the ported commit. — Cost if wrong: one re-run of ~30 min of verification.
- Ruling: R26 riverpod_generator names the settings provider `settingsProvider` (strips "Notifier") and the mutator is `save(GazerSettings)`; all later tasks (13–16, 22–24, 27) use those names instead of the contract's settingsNotifierProvider/update. — Cost if wrong: compile errors caught immediately.
- Ruling: R24 superseded (harness attribution guidance restored 2026-09-10 evening): new commits end with BOTH trailers again — `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01N2rQgkHY872RubwXoBZxtE`. Agents already told "Co-Authored-By only" may land commits without the session trailer; accepted as-is. — Cost if wrong: none.
- Ruling: R27 generated Pigeon Kotlin is excluded from ktlint (mirrors JaCoCo); regenerated Pipeline.g.kt is committed unformatted; hint sent to integration #1.
- Ruling: R28 GazerPipeline never calls the engine or the listener while holding its lock: mutate/snapshot under `synchronized(lock)`, then perform engine calls and listener notifications outside; documented contract that listeners may re-enter. — Cost if wrong: a deadlock on stop during a disconnect.
- Ruling: R29 narrow JaCoCo exclusion for `**/pipeline/StreamService.class` + `StreamService$*.class` only, documented (thin lifecycle shell delegating to unit-tested helpers; behaviour covered by the instrumented StreamServiceTest in CI's emulator job). No Robolectric. — Cost if wrong: Service glue untested on JVM (covered by androidTest).
- Ruling: R30 the stop/teardown gaps are product defects (visible in the phone test) and are fixed now: stop() unbinds + StreamService.stop; ACTION_STOP → stopForeground(REMOVE)+stopSelf; androidTest exercises the broadcast path; PigeonHostApiImpl.dispose + GazerFlutterBindings.uninstall from MainActivity.cleanUpFlutterEngine; CopyOnWriteArrayList. — Cost if wrong: one more Kotlin fix round.
- Ruling: R31 Task 21 adds the emulator + system-image lines to the Dockerfile but does NOT rebuild the local image (host CDN stalls; build cache pruned); the CI toolchain job rebuilds from the new Dockerfile and the CI `integration` job is the gate for the emulator test; the local `make mobile-test-integration` run is deferred to Task 26 verification once the CI-built image is pulled again. — Cost if wrong: emulator path unvalidated locally until Task 26.
- Ruling: R32 the CI emulator `integration` job runs on bare ubuntu-latest, not inside gazer-toolchain (KVM cannot cross a container: boundary) — accepted as the single documented exception to container-only tooling, on condition every tool it installs is pinned to the toolchain's exact versions and every uses: is a full commit SHA. — Cost if wrong: emulator job drifts from the toolchain and passes/fails for reasons the local target cannot reproduce.
- Ruling: R33 (attribution guidance changed 2026-09-11) commits created from now on end with only 'Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>'; the Claude-Session trailer is no longer required and its absence is not a finding; existing commits carrying it stay as-is. — Cost if wrong: trailer inconsistency across the branch history, cosmetic.
- Ruling: R34 breaker tripped at round 5 on the emulator job; the open finding is a Task 21 test defect with a known fix, not a plan defect, and the job is load-bearing for the tag/release gate — continue as integration #7c with a fresh agent and up to 3 more CI rounds; test defects are fixed on the feature branch with fix(gazer): commits and covered by the final whole-branch review. R31 relaxed: pulling the CI-built toolchain image (Dockerfile unchanged since bb05a654) and running make mobile-test-integration locally is permitted when /dev/kvm is accessible, to iterate faster than CI; no local image rebuild. If still red after 3 more rounds → report to user as a blocker. — Cost if wrong: up to ~1 h of CI/agent time on a job the phone test does not need.
- Ruling: R35 the round-7c app-code fixes bypassed per-task review; a scoped review (opus) of e4ea0545..4548234a is dispatched now, concurrent with integration #8; any findings become a fix round on the feature branch before Task 26. — Cost if wrong: one extra review seat.
- Ruling: R36 add libx11-xcb1 to mobile/gazer/Dockerfile as part of Task 26 (forces one CI toolchain rebuild at the end, acceptable) so make mobile-test-integration is reproducible without a local workaround. — Cost if wrong: one ~40 min CI rebuild.
- Ruling: R36 amended — the local emulator's libX11-xcb dependency is satisfied by the emulator package's own bundled Qt libs via LD_LIBRARY_PATH scoped to the emulator child process (run_integration_test.sh:37-39); that is self-contained and documented, so Task 26 does NOT change the Dockerfile (avoids a 40 min CI toolchain rebuild + re-pull). — Cost if wrong: none functional; a future Dockerfile change may fold the apt package in.
- Ruling: R37 the final whole-branch review covers c1b5f04a..HEAD (96 commits, ~43.6K added lines, ~20.9K excluding generated/lock/plan/PNG) — too large for one reviewer pass; split into 4 parallel opus reviewers by subsystem (Dart core: models/services/providers/telemetry + Pigeon contract both sides; UI: app/screens/l10n/widgets/goldens; Android: Kotlin pipeline/service/tests/gradle/manifest; Platform: Dockerfile/Makefile/CI workflow/scripts/docs/README/screenshots), each fed final-review-carryover.md and the spec; controller merges findings into ONE fix wave + one scoped re-review per SDD. — Cost if wrong: cross-subsystem seams reviewed only via the Pigeon-contract overlap; mitigated by the emulator integration test and CI.
- Ruling: R38 the ONE final fix wave runs as 4 parallel fixers (dart-core, android, platform now from 8d9a05c6; ui when its review lands), each in an isolated worktree with a disjoint file set: dart-core owns lib/{services,models,telemetry,config,main.dart}, integration_test/, test/{services,models,telemetry,config,helpers,fixtures}, and status_panel.dart's telemetry row only; ui owns lib/{app.dart,screens,widgets,l10n,theme}, test/{screens,goldens,app_test}; android owns mobile/gazer/android/** (no pigeons/ change — report if a contract change is needed); platform owns Dockerfile, Makefile, .github/**, mobile/gazer/scripts/**, README, .gitignore. Integration #10 cherry-picks all, re-runs every gate + the Task 26 Step 13 verification checklist (the Phase B doc is amended, since it recorded the pre-fix tree), pushes, CI. Then 4 scoped re-reviews. — Cost if wrong: one extra integration round.
- Ruling: R39 semgrep's remote 'auto' ruleset is scanner tooling, not a shipped dependency; keep it with --metrics=off and the semgrep binary version pinned, record the ruleset date in the verification doc; vendoring rules is an M2 follow-up. — Cost if wrong: scan results vary with registry updates.
- Ruling: R40 rtmps:// — the Android fixer must verify RootEncoder 2.8.1's default TLS trust/hostname behavior from source and either (a) record it as platform-trust-store + hostname verification with a unit test asserting the client is configured that way, or (b) if not verifiable, have TargetValidator reject rtmps:// in M1 with a localized message (Dart change coordinated via the dart-core fixer). — Cost if wrong: rtmps unavailable until M2.
- Ruling: R41 the M1 verification document written in #9 Phase B is provisional; #10 re-runs the checklist on the post-fix tree and amends it in place (same file, dated 2026-09-11/12 as run).
- Ruling: R42 shipped marketing set = 5 distinct screens: home-idle-phone, settings-phone, status-panel-phone, home-tablet, settings-tablet (replaces the duplicate status-panel-tablet); capture after bounded pumpAndSettle. — Cost if wrong: one recapture.
- Ruling: R39 amended — semgrep 1.176.1 refuses --config auto with --metrics=off (registry configs require metrics); keep auto with --metrics=on for M1, documented in README; vendored local ruleset (metrics off) is the M2 follow-up. — Cost if wrong: semgrep telemetry egress (rule ids/file hashes, no source) during scans.
- Ruling: R43 coverage_gate.sh's lib-file completeness check carries an explicit, justified allowlist for files with zero executable statements (constants-only / bare freezed declarations); any other missing file still fails; ≥90% threshold unchanged. — Cost if wrong: an allowlisted file could later gain untested code hidden behind the overall threshold.
- Ruling: R44 the final review's one fix wave produced two Important regressions in the Android fixer's own diff; both are load-bearing (reconnect keeps the FGS; app swipe-away stops the stream per spec), so a scoped Android round 2 runs on fixwave-android (base 46460422): keep FGS+wake lock across ERROR with a 60 s idle-release timer cancelled by prepare/start/stop; remove stopWithTask; guard statsSampler.start(); single teardown on refused startForeground. Re-reviewed scoped, landed via integration #11 after #10. — Cost if wrong: ~1 h; the alternative (shipping a reconnect that drops the FGS) is not acceptable.
- Ruling: R45 NB1 fixed Kotlin-side in Android round 3: idle-release expiry also releases/unbinds the host (lock-guarded vs concurrent prepare) so the next prepare re-binds and re-starts the FGS as a user-initiated start; bindService()'s StreamService.start guarded → serviceStartDenied. Then scoped re-review; all round 2+3 commits land via integration #11. — Cost if wrong: ~40 min.
<!-- RULINGS_END -->

## Appendix — USER DECISION / USER REQUIREMENT lines mentioning Gazer

Verbatim from the same `progress.md` (`grep -in "USER DECISION\|USER REQUIREMENT" | grep
-i gazer`):

> USER DECISIONS (2026-09-14): rename scope = repo + folder + references
> (packages/namespaces/charts untouched); 'feature parity' = BOTH Gazer 2.0 parity with
> the old Gazer app (inventory → spec → plan) AND a v3 MVP audit of release/v3.0.X; then
> re-run security-auditor. Also: research https://github.com/Psychoboy/PenguinTwitchBot
> for app-bundle ideas (creator's permission). Sequence: Gazer merge → rename →
> parity/MVP work → security audit. Parallel read-only agents dispatched now:
> v3-mvp-audit (a07d…), penguintwitchbot-bundle-ideas (acae…), old-gazer-inventory
> (a19a…) → .superpowers/{sdd/...,research/}.

> USER DECISION (2026-09-14, Gazer parity): parity set = UVC capture card + card audio
> only (M2 Camera2 LENS_FACING_EXTERNAL + USB Audio Class; M3 libusb+libuvc JNI
> fallback); NOT preview, NOT WaddleBot login/chat/communities, NOT
> multi-destination/RTMPS/SRT/WebRTC. M2 plan writer dispatched (sonnet) from the
> existing spec's M2/M3 sections against the M1 code; execution starts after the M1
> merge on a new feature branch off release.

For the move directive itself (not labeled USER DECISION/USER REQUIREMENT, so outside
the strict grep above, but the actual origin of this PR):

> USER DIRECTIVE (2026-09-14): after Gazer's final updates, move it into the penguinm
> mobile monorepo under gazer/ (repo exists: penguintechinc/penguinm, default main,
> local ~/code/penguinm). Flagged: contradicts client.md 'mobile apps live in the
> product repo' — user's call; rule update belongs in the admin repo. penguinm inventory
> dispatched (haiku Explore, a1e7…); M2 plan writer told to use `<app>`-relative paths
> and penguinm's toolchain image path.
