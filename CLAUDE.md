# Claude Code Context (.claude/ supplement)

**This file supplements the root `README.md`.** It contains only rules and configuration unique to this repository. For project overview and commands, see `README.md`.

**Precedence**: `~/.claude/rules/*.md` wins over this file on conflict.

## 🚫 DO NOT MODIFY THIS FILE OR `.claude/` STANDARDS

**These are centralized template files that will be overwritten when standards are updated.**

- ❌ **NEVER edit** `CLAUDE.md` or `.claude/*.md`
- ✅ **CREATE NEW FILES** for app-specific context:
  - `docs/APP_STANDARDS.md` - App-specific architecture, requirements, context (this file supersedes `penguin-libs/docs/standards/MOBILE.md`)
  - `.claude/{subject}.local.md` - Project-specific overrides (e.g., `flutter.local.md`)

**App-Specific Addendums to Standardized Files:**

If this repo needs to add exceptions or clarifications to standardized `.claude/` files, create a `.local` variant instead:

- `flutter.md` (standardized) → Create `flutter.local.md` for app-specific Flutter patterns
- `testing.md` (standardized) → Create `testing.local.md` for app-specific test requirements

**Always check for and read `.local.md` files** alongside standard files to ensure you have the complete context.

## Global vs Local Rules and Skills

**Standard rules/skills/agents are symlinked globally at `~/.claude/{rules,skills,agents}/`** via `make sync-standards` (`scripts/sync-standards.sh`; source: `~/code/admin/.claude/{rules,skills,agents}/`) — NOT copied into this repo.

- **Global** (`~/.claude/rules/*.md`, `~/.claude/skills/*/SKILL.md`): Managed centrally, apply to all projects
- **Local** (`{REPO_ROOT}/.claude/rules/*.local.md`): Project-specific overrides, stay in the repo

`make sync-standards-local` refreshes only the symlinks (no downstream repo push); preserves `.local.md` files.

---

## MCP Servers

- **mem0**: Canonical persistent memory layer — always preferred over file-based memory (`.PLAN`/`.TODO` are crash-recovery only, not a substitute). `search_memories` at the start of every session before asking the user to re-explain anything; `add_memory` for architecture, conventions, debugging insights, decisions, preferences; `update_memory` when prior context changes. When in doubt, save it. **If the mem0 server is unreachable, say so explicitly in your report** (e.g. "mem0 unreachable — recall skipped") — graceful degradation must stay visible, never silent.
- **gemini**: Research (Google Search grounding) and media generation, exposed via the `gemini-expert` agent and `gemini-research`/`gemini-create`/`gemini-api-dev` skills. Prefer over WebSearch for research, and for image/video/audio generation. All seven tools run on the `google-genai` SDK and require `GEMINI_API_KEY` — see Setup Script below.

---

## Setup Script

This repo includes `setup.sh` which configures the local Claude Code environment:

```bash
.claude/setup.sh              # Full setup (statusline + mem0 + gemini + settings)
.claude/setup.sh statusline   # Statusline only
.claude/setup.sh mem0         # mem0 + Qdrant only
.claude/setup.sh gemini       # Gemini MCP only
.claude/setup.sh settings     # Settings update only
```

At session start, verify the environment is configured. If `~/.claude/statusline-command.sh`, `~/.claude/mcp/mem0/mcp-server.py`, or `~/.claude/mcp/gemini/mcp-server.py` does not exist, run `setup.sh` from this repo.

### Status Line

The setup script symlinks `statusline-command.sh` to `~/.claude/` and configures `settings.json`. The statusline displays model, effort, repo, branch, context usage, cost, and duration.

### mem0 (Local Persistent Memory)

The setup script deploys a local Qdrant container and configures a mem0 MCP server using Ollama for embeddings (`nomic-embed-text`) and LLM (`gemma3:1b`). All memory operations are fully local — no external API calls.

**Manage Qdrant:**
```bash
docker compose -f ~/.claude/mcp/mem0/docker-compose.yml up -d    # start
docker compose -f ~/.claude/mcp/mem0/docker-compose.yml down      # stop
```

**Qdrant dashboard:** http://localhost:6333/dashboard

### Gemini (Research & Media Generation)

The setup script deploys the Gemini MCP server to `~/.claude/mcp/gemini/` with its own venv and registers the server with Claude Code. It powers the `gemini-expert` agent (research, second opinions, image/video/music generation) and the `gemini-research`/`gemini-create`/`gemini-api-dev` skills.

**One auth path for all seven tools**, two ways to supply it (get a key at https://aistudio.google.com/apikey — the free tier works, including Search grounding, no billing required):
- Export `GEMINI_API_KEY` in your shell profile, or
- Save the key to `~/.gemini-token`, owner-read-only (`chmod 400 ~/.gemini-token`) — the server reads this file at startup only when no `GEMINI_API_KEY`/`GOOGLE_API_KEY` is already in the environment.

Never pass it as a literal CLI argument or paste it into chat — the setup script does not bake it into the MCP registration. Text/reasoning tools (research, prompt, second_opinion, analyze) use Google Search grounding on the standard API-key tier via `google-genai`'s `generate_content`. There is no separate CLI login step — the old free-OAuth `gemini` CLI path (`gemini auth`) was retired by Google on 2026-06-18 and is no longer used here.

---

## Repository Layout

```
penguinm/
├── pubspec.yaml                 pub workspace root (workspace: members list, melos dev-dep)
├── pubspec.lock                 the ONLY lockfile — committed
├── melos config                 under root pubspec's `melos:` key (melos 8 ignores melos.yaml)
├── analysis_options.yaml        include: package:penguin_lints/analysis_options.yaml
├── .fvmrc  .flutter-version     3.44.8 (stable)
├── VERSION                      0.1.0 — repo release version, applied to every app
├── Makefile                     see Commands section
├── CLAUDE.md  README.md  LICENSE  .gitignore  .pre-commit-config.yaml  .PLAN  .TODO
├── .github/
│   ├── CODEOWNERS               *  @Chromeninja @PenguinzTech
│   └── workflows/               ci.yml security.yml toolchain-image.yml release-android.yml e2e-android.yml
├── apps/
│   ├── README.md                how to add an app (points at templates/ + docs/ADDING_AN_APP.md)
│   ├── penguin_reference/       product key `penguinm`, proves every shell capability end-to-end
│   ├── penguincloud/            product key `penguincloud`
│   └── gazer/                   (incoming) Gazer Mobile v2 — moved in by the waddlebot session
├── shells/
│   └── penguin_app_shell/       runPenguinApp(AppManifest) — bootstrap + router + chrome
├── packages/
│   ├── flutter_libs/            migrated: theme, LoginPageBuilder, OAuth/SAML utils, TokenStorage, forms, sidebar, ConsoleVersion
│   ├── penguin_lints/           shared analysis_options
│   ├── penguin_core/            AppConfig, Result/Failure, PenguinLogger, LogSanitizer, Clock
│   ├── penguin_api/             PenguinApiClient + middleware (auth/trace/retry/log), RetryPolicy
│   ├── penguin_auth/            AuthController, Session, JwtClaims, OIDC + password backends, SessionStore
│   ├── penguin_telemetry/       OTel logs/metrics/traces, OTLP/HTTP exporter
│   ├── penguin_flags/           FeatureFlags: PostHog + license tier, cache, FeatureGate widget
│   ├── penguin_offline/         ConnectivityMonitor, OfflineStore (SQLite), SyncQueue
│   ├── penguin_update/          UpdateChecker, UpdatePrompt
│   ├── penguin_ui/              PenguinTheme, FormFactor, ResponsiveScaffold, AdaptiveLayout, ErrorView
│   └── penguin_testing/         fakes for every interface, pump helpers, golden helper, OTLP sink client
├── platform/
│   ├── android/
│   │   ├── gradle/              libs.versions.toml, penguin-android.gradle.kts, signing.gradle.kts
│   │   ├── plugins/             federated Flutter plugin packages (none yet; policy in README)
│   │   └── README.md            native-module justification policy + how to add a plugin
│   └── ios/README.md            dormant; what activates it
├── templates/
│   └── penguin_app/             mason brick → apps/<name>/lib, test, env, pubspec
├── tooling/
│   ├── docker/Dockerfile.flutter-android
│   ├── otlp_sink/               Dart package: local OTLP/HTTP receiver for smoke tests
│   └── scripts/                 install-pre-commit.sh check-pins.sh coverage-gate.sh etc.
└── docs/
    ├── ARCHITECTURE.md APP_STANDARDS.md ADDING_AN_APP.md AUTH.md NATIVE_MODULES.md OFFLINE.md RELEASE.md TESTING.md
    ├── flutter_libs/            API.md README.md CHANGELOG.md (moved from penguin-libs)
    └── superpowers/
```

---

## App Roster (14 apps)

Fourteen apps are planned. Directory = `apps/<snake_case>`; `applicationId` = `io.penguintech.<snake_case>`; flag keys = `<product>.<app>.<feature>` for multi-app products (still prefixed by the product key, so `FeatureFlags`' prefix check holds). Product keys and prod domains come from the `penguintech-reference` skill (resolved 2026-09-14). The reference marks Current and SkausWatch as deprecated products; they stay on the roster because the user listed them — confirm before scaffolding either.

| App | Dir | Product key | Family / parent (repo) | Prod domain | Purpose | Anticipated native modules |
|---|---|---|---|---|---|---|
| Gazer | `gazer` | `waddlebot` | Waddles (`waddlebot`) | waddles.app | streaming companion (Gazer Mobile v2, incoming) | RTMP encoder, Camera2/UVC, USB audio (already in v2) |
| Waddles | `waddles` | `waddlebot` | Waddles (`waddlebot`) | waddles.app | chat / community management (Discord-class) | push notifications, media capture |
| Ruffled | `ruffled` | `waddlebot` | Waddles (`waddlebot`) | waddles.app | CRM / support / sales companion | — |
| Current | `current` | `current` | Current (`current`), Waddles companion | currenturl.app | marketing / shortlink companion | share-sheet intent |
| SkausWatch | `skauswatch` | `skauswatch` | SkausWatch (`skauswatch`) | skauswatch.app | monitoring companion | — |
| SkausWatch Vault | `skauswatch_vault` | `skauswatch` | SkausWatch (`skauswatch`) | skauswatch.app | passwords, passkeys — security-sensitive | Credential Manager / passkeys, biometric unlock, hardware keystore (Kotlin) |
| Elder | `elder` | `elder` | Elder (`elder`) | elderrms.app | core app | — |
| Elder Support | `elder_support` | `elder` | Elder (`elder`) | elderrms.app | support companion | — |
| Nest Drive | `nest_drive` | `nest` | Nest (`nest`) | nestdata.app | file drive | document provider / background sync |
| Tobogganing | `tobogganing` | `tobogganing` | Tobogganing (`tobogganing`) | tobogganing.app | core app | — |
| Tobogganing Connect | `tobogganing_connect` | `tobogganing` | Tobogganing (`tobogganing`) | tobogganing.app | tunnel client — security-sensitive | `VpnService` (Kotlin); tunnel core possibly shared with `penguind` (Rust via FFI) — later decision |
| Tobogganing Squawk | `tobogganing_squawk` | `squawk` | Squawk (`squawk`), marketed under Tobogganing | squawkmgr.app | secure DNS client — security-sensitive | `VpnService`-based DNS (Kotlin) |
| PenguinCloud | `penguincloud` | `penguincloud` | PenguinCloud (`penguincloud`) | penguincloud.io | infra overview + basic management (Gough etc.); hub that points to the other apps | — |
| WaddleAI Chat | `waddleai_chat` | `waddleai` | WaddleAI (`waddleai`) | waddleai.app | chat client | — |

Every app is a set of **modules** that mirror (much lighter) the product's server and web UI modules, and its feature flags mirror theirs: a module-level flag key is the SAME key the server/web UI use (`<product>.<module>`), so one PostHog toggle governs every surface; only mobile-specific sub-features get `<product>.<app>.<feature>`. `FeatureModule.id` equals the server module name. All fourteen apps share one UX design and style (`PenguinTheme`, `ResponsiveScaffold`, the same components); per-app branding is limited to name, logo, and an optional seed colour — no per-app theme forks.

Design consequences: the shell gains a sibling-app launcher (§4.10) so companions open each other by deep link or fall back to the store; families share `AuthConfig`/tenant so a user signs in once per family (OIDC issuer per product); every companion's `env/*.json` names its family's API base. The security-sensitive three keep secrets only in platform secure storage and are the first candidates for the native-module policy in `docs/NATIVE_MODULES.md`.

---

## Per-App Folder Standard

```
apps/<app_name>/
├── pubspec.yaml               name: <app_name>; resolution: workspace; deps: penguin_app_shell + packages via path; exact versions
├── env/                       PUBLIC build config only (URLs, project keys) — one JSON per flavor, no secrets
│   ├── dev.json  beta.json  prod.json
├── lib/
│   ├── main.dart              runPenguinApp(manifest) — ≤15 lines, no logic, no widgets
│   ├── manifest.dart          AppManifest: productKey, config (AppConfig.fromEnvironment), auth, features, theme overrides
│   └── features/<feature>/    one folder per feature, self-contained, gated by '<productKey>.<feature>'
│       ├── <feature>_module.dart   FeatureModule: routes, destinations, providers, init
│       ├── data/              repositories + DTOs; only place that calls PenguinApiClient / OfflineStore
│       ├── domain/            entities + pure logic; no Flutter imports
│       └── presentation/      screens/ widgets/ providers/ (Riverpod)
├── android/                   flutter-generated; app/build.gradle.kts applies platform/android/gradle conventions; flavors dev/beta/prod
├── ios/                       flutter-generated; dormant until iOS is sequenced (kept compiling, not built in CI)
├── assets/                    images/ icons/ (launcher icons via flutter_launcher_icons config in pubspec)
├── test/                      mirrors lib/: features/<feature>/..._test.dart; goldens/ ; fixtures/ (3–4 mock items per feature)
├── integration_test/          critical flows (login, offline write → sync)
├── README.md                  what works offline, env/flavor table, run/build commands, native modules used
└── CHANGELOG.md
```
Naming: app dir and pubspec `name` are `snake_case`; Android `applicationId` is `io.penguintech.<app_name>` with `.dev`/`.beta` suffixes per flavor; flag keys are `<productKey>.<feature>` for single-app products and `<productKey>.<app>.<feature>` for multi-app families (§1.1); every screen has a widget test; every feature has ≥3 fixture items. The roster in §1.1 is the source of truth for ids, product keys, and applicationIds (`KnownApps` in `penguin_core`).

---

## Commands

Every target propagates exit status. No `|| true` masking. `make pre-commit` runs the full gate and stops on first failure.

```
bootstrap              Resolve workspace dependencies via melos bootstrap
build-android          Build an app inside the toolchain image (Vars: APP= FLAVOR=<dev|beta|prod> FORMAT=<apk|aab>)
clean                  Remove build artifacts and coverage output across the workspace
coverage               test + coverage-gate.sh (≥90% per package, fails on LF=0 or 0 packages)
docker-build           Build the penguinm/flutter-android:local toolchain image
format                 Apply dart format across the workspace
install-hooks          Install pre-commit framework + register pre-commit and pre-push hooks
lint                   dart format check + flutter analyze (zero infos/warnings)
new-app                Scaffold a new app (Vars: NAME= PRODUCT= DISPLAY=)
pre-commit             lint → test-security → smoke-test → test → coverage → check-pins
seed-mock-data         Regenerate test/fixtures from penguin_testing generators (prints counts)
setup                  Verify Flutter 3.44.8, dart pub get, melos bootstrap, install hooks
smoke-test             bootstrap + analyze + penguin_reference tests + telemetry + pins (<2 min)
test                   Run every package's test suite with --coverage (coverage/lcov.info per package)
test-integration       Run integration_test/ suites (requires Android emulator, API 35 x86_64)
test-security          gitleaks, trivy, osv-scanner, semgrep, zizmor, hadolint
test-unit              Run unit tests only (test/, no integration_test/)
verify-hooks           Report whether pre-commit/pre-push hooks are installed and non-empty
version                Apply VERSION (+ epoch build) to every app pubspec
```
