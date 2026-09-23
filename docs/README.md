# Documentation

Guides for the penguinm mobile monorepo.

## Guides

| Document | Topic |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Repository layout, dependency graph, workspace mechanics, shared packages, per-app folder standard |
| [APP_STANDARDS.md](APP_STANDARDS.md) | Form factors, platform targets, native-module policy, testing matrix, Flutter 3.44.8 pins |
| [ADDING_AN_APP.md](ADDING_AN_APP.md) | Step-by-step app scaffolding, feature modules, manifest configuration |
| [AUTH.md](AUTH.md) | Hosted login model, OAuth2 + PKCE flow, system browser, backend contract for products |
| [NATIVE_MODULES.md](NATIVE_MODULES.md) | When to write native code, justification policy, Kotlin/Swift template, platform-channel example |
| [OFFLINE.md](OFFLINE.md) | What works offline per app, sync patterns, caching, dead-letter surfaces |
| [RELEASE.md](RELEASE.md) | Versioning, Play Store releases, CI/CD workflows, beta/gamma/prod tiers |
| [TESTING.md](TESTING.md) | Unit/widget/integration/golden/telemetry testing, mock data, per-layer gates, coverage |

## Quick Start

```bash
make setup          # Verify Flutter 3.44.8, bootstrap, install hooks
make smoke-test     # Lint + analyze + reference smoke test (~2 min)
make test           # Full test suite with coverage
make pre-commit     # Complete gate (lint → security → smoke → test → coverage → pins)
```

## How to Add an App

```bash
make new-app NAME=myapp PRODUCT=myproduct DISPLAY="My App"
```

Then read [ADDING_AN_APP.md](ADDING_AN_APP.md) for the full procedure.

## Reference

- `flutter_libs/` — Shared Flutter widgets and utilities (migrated from `penguin-libs`)
- `superpowers/` — Specification and design documents
- Root `CLAUDE.md` — Repository context, MCP servers, per-repo folder standard
