# PenguinTech Mobile Apps

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

## How to Add an App

Use `make new-app NAME=<name> PRODUCT=<product> DISPLAY=<displayname>` to scaffold a new app directory, or follow these steps:

1. **Scaffold the directory**
   ```bash
   make new-app NAME=myapp PRODUCT=myproduct DISPLAY="My App"
   ```

   This creates:
   - `apps/myapp/pubspec.yaml` (name: `myapp`, workspace member)
   - `apps/myapp/lib/main.dart` (entry point, ≤15 lines)
   - `apps/myapp/lib/manifest.dart` (AppManifest with productKey, config, auth, features)
   - `apps/myapp/env/{dev,beta,prod}.json` (config per flavor)
   - `apps/myapp/android/` (flutter-generated, inherits gradle conventions)
   - `apps/myapp/test/` (empty, mirrors lib/)
   - `apps/myapp/README.md` (offline, env, build commands, native modules)
   - `apps/myapp/CHANGELOG.md` (empty, starts at v0.1.0)

2. **Define your features** — add directories under `lib/features/<feature>/`
   ```
   lib/features/myfeature/
   ├── myfeature_module.dart       # FeatureModule: id, flagKey, routes, destinations
   ├── data/                       # repositories, DTOs
   ├── domain/                     # entities, pure logic
   └── presentation/               # screens, widgets, providers
   ```

   Example `myfeature_module.dart`:
   ```dart
   class MyFeatureModule extends FeatureModule {
     @override
     String get id => 'myfeature';

     @override
     String? get flagKey => 'myproduct.myfeature';

     @override
     List<RouteBase> routes(Ref ref) => [
       GoRoute(path: '/myfeature', builder: (c, s) => const MyFeatureScreen()),
     ];

     @override
     List<NavigationDestinationSpec> get destinations => [
       NavigationDestinationSpec(
         route: '/myfeature',
         label: 'My Feature',
         icon: Icons.star,
         selectedIcon: Icons.star_filled,
       ),
     ];
   }
   ```

3. **Configure your auth** — in `manifest.dart`, choose between hosted or password login:
   ```dart
   // Hosted (recommended): user goes to system browser
   auth: AuthConfig.hosted(
     issuer: Uri.parse(config.apiBaseUrl),
     clientId: 'io.penguintech.myapp',
     redirectUri: 'io.penguintech.myapp://oauth/callback',
   ),

   // Password (transitional, for backends without hosted login):
   auth: AuthConfig.password(),
   ```

4. **Add feature flags** — every feature gated by a flag key
   ```dart
   // In your module's router/widget:
   final isEnabled = ref.watch(flagProvider('myproduct.myfeature'));
   if (!isEnabled) return const EmptyView(message: 'Feature not available');
   ```

5. **Test and build**
   ```bash
   flutter test                          # Unit + widget tests (must pass)
   flutter test --coverage               # Coverage report
   make lint                             # Analyze + format check
   make build-android APP=myapp FLAVOR=dev FORMAT=apk
   ```

## Folder Structure

Each app follows the same layout:

| Path | Purpose |
|---|---|
| `lib/main.dart` | Entry point, calls `runPenguinApp(manifest)` |
| `lib/manifest.dart` | AppManifest: productKey, config, auth, brand, features list |
| `lib/features/<feature>/` | One module per feature (self-contained, gated by flag) |
| `env/{dev,beta,prod}.json` | PUBLIC config (URLs, keys) — no secrets |
| `android/` | Flutter-generated; applies `platform/android/gradle` conventions |
| `test/` | Mirrors `lib/`, ≥90% coverage required |
| `README.md` | What works offline, how to build, native modules |

## Dependency Direction

```
apps/* → shells/penguin_app_shell → every package below
penguin_core → (nothing; hosts cross-cutting interfaces)
penguin_telemetry → penguin_core
penguin_api → penguin_core
penguin_auth → penguin_core, flutter_libs
penguin_flags → penguin_core
penguin_ui → penguin_core, flutter_libs
penguin_offline, penguin_update → penguin_core, penguin_api
penguin_testing → every package (dev-dependency only)
```

## Naming Conventions

| Item | Convention | Example |
|---|---|---|
| App directory | snake_case | `skauswatch_vault` |
| `pubspec.yaml` name | snake_case | `skauswatch_vault` |
| Android applicationId | io.penguintech.<app> | `io.penguintech.skauswatch_vault` |
| Feature flag key | `<product>.<feature>` or `<product>.<app>.<feature>` | `skauswatch.vault` or `waddlebot.waddles.chat` |
| Module id | matches server module name | `vault`, `chat`, `billing` |

## Key Rules

- Every app uses `PenguinTheme` (no theme forks); branding via `AppBrand` only (name, logo, seed colour)
- Tokens live only in `flutter_secure_storage`; cleared on logout
- No hardcoded URLs or API keys — all from `env/*.json` and `AppConfig.fromEnvironment`
- Feature flags: every module gated; unseen → OFF; license tier checked, never boolean
- Offline: ConnectivityMonitor + SyncQueue + OfflineStore for read/write caching
- OTel: logs + metrics + traces emitted from the shell; endpoint configurable via OTLP env vars
- Coverage: ≥90% per package, enforced by `make coverage`
- Security: tokens in platform secure storage only; no secrets in config files; release never signed with debug key

See `docs/ADDING_AN_APP.md` for full scaffolding procedure and `docs/ARCHITECTURE.md` for dependency graph and workspace mechanics.
