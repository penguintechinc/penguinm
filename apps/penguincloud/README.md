# PenguinCloud

PenguinCloud is a Flutter mobile client for the PenguinCloud product — a springboard (home) screen of role-filtered destinations plus a profile screen, migrated onto the `penguinm` shell from `penguincloud/services/mobile` (spec `docs/superpowers/specs/2026-09-14-penguinm-monorepo-design.md` §11.2). See `docs/MIGRATION.md` for the full source→destination mapping and the deviations this migration had to make.

## Offline & Connectivity

| Feature | Status | Notes |
|---------|--------|-------|
| Springboard (home) | Offline | Static, bundled destination list — no backend call, always renders |
| Profile | Online only | Always fetched fresh via `GET /api/v1/auth/profile`; no offline cache — a network error shows a retry, never stale data |
| Sign in / sign out | Online only | The transitional password-login form (see Authentication below) and logout both require connectivity |

## Authentication

PenguinCloud uses the shell's **transitional password-auth path** (`AuthConfig.password`, spec §4.5) rather than hosted OIDC/SAML login: this backend does not expose a hosted mobile login endpoint yet. The login screen renders the shell's default password form (flutter_libs `LoginPageBuilder`, wrapped via `penguin_app_shell`'s `buildLoginScreen`) with a PenguinCloud branding pane added alongside it on tablet/expanded widths (`lib/login_screen.dart`, wired as `AppManifest.loginBuilder`). Tracked per `docs/AUTH.md`'s "Transitional Password-Based Login" section until PenguinCloud's backend adds hosted login.

## Environments & Build Flavors

| Flavor | Target | Config | API Base |
|--------|--------|--------|----------|
| `dev` | Android emulator | `env/dev.json` | `http://10.0.2.2:5000` |
| `beta` | Internal testing | `env/beta.json` | `https://penguincloud.penguintech.cloud` |
| `prod` | Production | `env/prod.json` | `https://api.penguincloud.io` |

## Build & Run

### Development

```bash
# Run on Android emulator (dev flavor)
flutter run --flavor dev --dart-define-from-file=env/dev.json

# Run on device (dev flavor)
flutter run --flavor dev --dart-define-from-file=env/dev.json -d <device>
```

### Beta

```bash
flutter build apk --flavor beta --dart-define-from-file=env/beta.json
flutter build appbundle --flavor beta --dart-define-from-file=env/beta.json
```

### Production

```bash
flutter build apk --flavor prod --dart-define-from-file=env/prod.json --release
flutter build appbundle --flavor prod --dart-define-from-file=env/prod.json --release
```

## Testing

```bash
# Run all tests with coverage
flutter test --coverage

# Run a specific test file
flutter test test/features/springboard/presentation/springboard_grid_test.dart

# Update goldens after an intentional visual change
flutter test --update-goldens test/goldens/

# Integration tests (requires an Android emulator, API 35 x86_64)
flutter test integration_test/login_flow_test.dart
```

## Linting & Formatting

```bash
flutter analyze --fatal-infos
dart format --set-exit-if-changed .
```

## Architecture

```
lib/
├── main.dart              runPenguinApp(buildManifest()) — ≤15 lines
├── manifest.dart           AppManifest wiring: config, auth, feature modules, login builder
├── login_screen.dart       Tablet-branding-pane login screen (AppManifest.loginBuilder)
└── features/
    ├── springboard/
    │   ├── springboard_module.dart          FeatureModule — flag `penguincloud.springboard`
    │   ├── domain/springboard_item.dart     SpringboardItem, role-visibility logic
    │   └── presentation/                    springboard_screen, springboard_grid, springboard_tile
    └── profile/
        ├── profile_module.dart              FeatureModule — flag `penguincloud.profile`
        ├── domain/user.dart                 User model
        ├── data/profile_repository.dart     the only caller of PenguinApiClient in this feature
        └── presentation/                    profile_screen, profile_providers
```

Every feature module is gated by a PostHog flag of the form `penguincloud.<feature>` (spec §1.1).

## Native Modules

None. Springboard and profile are plain Dart/Flutter; no platform channels.
