# penguinm — PenguinTech Mobile Monorepo

A unified Flutter/Dart repository hosting all PenguinTech mobile apps for iOS and Android. Single Dart codebase, shared design system, feature modules gated by PostHog flags and license tier.

## Quick Start

```bash
make setup                  # Verify Flutter 3.44.8, bootstrap workspace, install hooks
make smoke-test             # Lint + analyze + reference app smoke test (~2 min)
make test                   # Unit + widget tests, coverage per package (≥90% required)
make pre-commit             # Full gate: lint → security → smoke → test → coverage → pins
```

## Repository Layout

See `docs/ARCHITECTURE.md` for the full tree and dependency graph.

```
apps/                    14 apps (penguin_reference, penguincloud, + 12 others)
packages/                Shared Dart packages (auth, telemetry, UI, offline, flags, etc.)
shells/penguin_app_shell Bootstrap + router + chrome (runPenguinApp entry point)
platform/android         Android Gradle conventions, native plugin templates
platform/ios             iOS (dormant until iOS is sequenced)
templates/penguin_app    Mason brick for new apps
tooling/                 Dockerfile, OTLP test sink, build scripts
docs/                    Guides (architecture, testing, auth, offline, release)
```

## App Roster

| App | Product | Purpose |
|---|---|---|
| Gazer | waddlebot | Streaming companion (Gazer Mobile v2, incoming) |
| Waddles | waddlebot | Chat / community management |
| Ruffled | waddlebot | CRM / support / sales companion |
| Current | current | Marketing / shortlink companion |
| SkausWatch | skauswatch | Monitoring companion |
| SkausWatch Vault | skauswatch | Passwords, passkeys (security-sensitive) |
| Elder | elder | Core app |
| Elder Support | elder | Support companion |
| Nest Drive | nest | File drive |
| Tobogganing | tobogganing | Core app |
| Tobogganing Connect | tobogganing | Tunnel client (security-sensitive) |
| Tobogganing Squawk | squawk | Secure DNS client (security-sensitive) |
| PenguinCloud | penguincloud | Infra overview + hub |
| WaddleAI Chat | waddleai | Chat client |

See `apps/README.md` for full descriptions and native module requirements.

## Standards

- **Flutter 3.44.8** (Dart 3.12.2), exact version pinned in `.fvmrc`, `.flutter-version`, workflows, Dockerfile
- **No codegen**: hand-written providers (Riverpod 3), SQL, JWT decoding
- **No `dio`**: HTTP via `package:http` (dart.dev); `dio` publisher `flutter.cn` is PRC-based
- **90%+ coverage**: per-package, enforced by CI
- **Offline-first patterns**: ConnectivityMonitor, SyncQueue, OfflineStore (SQLite)
- **OTel mandatory**: logs + metrics + traces, vendor-neutral OTLP/HTTP endpoint
- **Feature flags**: PostHog + license tier, every feature behind a gate
- **Responsive design**: phone/tablet, portrait/landscape, Material 3
- **Secure storage**: tokens in `flutter_secure_storage` only, never SharedPreferences
- **One design system**: `PenguinTheme` shared across every app, per-app branding via `AppBrand` only

## Key Decisions

- **Monorepo with Dart pub workspace** (one `pubspec.lock`) + Melos 7 for cross-package scripts
- **`flutter_libs` imported** from `penguin-libs` (timestamp `120fb97`), now server-side only
- **Android first-class, iOS second-class**: CI builds Android only; iOS dirs generated but not signed/published until iOS is sequenced
- **Gazer v2 reserved**: `waddlebot/mobile/gazer` (M1 complete, own Flutter 3.47.2 toolchain) moves here with handoff document; `apps/gazer` is free until then
- **Security-sensitive apps** (SkausWatch Vault, Tobogganing Connect, Tobogganing Squawk) use native modules for credentials, VPN, biometrics, key storage

## Documentation

- `docs/ARCHITECTURE.md` — repository layout, dependency graph, per-app folder standard, Melos/workspace mechanics
- `docs/APP_STANDARDS.md` — form factors, native-module policy, testing matrix, testing tooling (Flutter 3.44.8 pins)
- `docs/ADDING_AN_APP.md` — step-by-step scaffolding and integration
- `docs/AUTH.md` — hosted login model, OAuth2 + PKCE + system browser, backend contract for every product
- `docs/NATIVE_MODULES.md` — justification policy, template, platform-channel example
- `docs/OFFLINE.md` — what works offline per app, sync patterns, caching strategy
- `docs/RELEASE.md` — versioning, Play Store releases, CI/CD workflows
- `docs/TESTING.md` — unit/widget/integration/golden/telemetry testing, mock data, per-layer gates

See `.claude/CLAUDE.md` for per-repo rules and MCP configuration.

## Commands

Every target propagates exit status and never masks with `|| true`. `make pre-commit` runs the full gate and stops on first failure.

```
bootstrap              Resolve workspace dependencies
build-android          Build an app (Vars: APP= FLAVOR=<dev|beta|prod> FORMAT=<apk|aab>)
clean                  Remove artifacts and coverage
coverage               test + coverage-gate (≥90% per package)
docker-build           Build flutter-android:local toolchain image
format                 Apply dart format
install-hooks          Install pre-commit + pre-push hooks
lint                   Format check + analyze (zero infos)
new-app                Scaffold a new app (Vars: NAME= PRODUCT= DISPLAY=)
pre-commit             lint → test-security → smoke-test → test → coverage → check-pins
seed-mock-data         Regenerate test/fixtures (prints counts)
setup                  Verify Flutter 3.44.8, bootstrap, install hooks
smoke-test             Bootstrap + analyze + reference tests + telemetry + pins (<2 min)
test                   Run every package with --coverage
test-integration       Run integration_test/ (requires emulator)
test-security          gitleaks + trivy + osv + semgrep + zizmor + hadolint
test-unit              Unit tests only (test/, no integration_test/)
verify-hooks           Report hook installation status
version                Apply VERSION (+ epoch) to every app pubspec
```

## Related Repos

- `penguin-libs` — Server-side only (Flutter libs moved here)
- `waddlebot/mobile/gazer` — Gazer Mobile v2 (converges into `apps/gazer` after handoff)
- `penguincloud/services/mobile` → migrated to `apps/penguincloud`
- `admin/.claude/rules/` — Canonical rules (`client.md`, `client-flutter.md`, etc.); symlinked here via `make sync-standards`

## Support

- Architecture & design: see `docs/ARCHITECTURE.md` and `.claude/CLAUDE.md`
- App scaffolding: `make new-app NAME=... PRODUCT=... DISPLAY=...` or read `docs/ADDING_AN_APP.md`
- Testing & coverage: `docs/TESTING.md`
- Offline sync: `docs/OFFLINE.md`
- Native modules: `docs/NATIVE_MODULES.md`
