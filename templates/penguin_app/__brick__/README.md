# {{display_name}}

{{display_name}} is a Flutter mobile app for {{product_key}}.

## Offline & Connectivity

| Feature | Status | Notes |
|---------|--------|-------|
| Read home content | Offline | Cached on first load |
| Load new content | Online | Real-time sync on reconnect |
| Write/compose | Offline | Queued; synced when online |
| Share | Online | Requires connectivity |

## Environments & Build Flavors

| Flavor | Target | Config | API Base |
|--------|--------|--------|----------|
| `dev` | Android emulator | `env/dev.json` | `http://10.0.2.2:5000` |
| `beta` | Internal testing | `env/beta.json` | `https://api.{{product_key}}.penguintech.cloud` |
| `prod` | Production | `env/prod.json` | `https://api.{{product_key}}.app` |

## Build & Run

### Development

```bash
# Install dependencies
flutter pub get

# Run on Android emulator (dev flavor)
flutter run --flavor dev --dart-define-from-file=env/dev.json

# Run on device (dev flavor)
flutter run --flavor dev --dart-define-from-file=env/dev.json -d <device>
```

### Beta

```bash
# Build APK
flutter build apk --flavor beta --dart-define-from-file=env/beta.json

# Build AAB
flutter build appbundle --flavor beta --dart-define-from-file=env/beta.json
```

### Production

```bash
# Build APK
flutter build apk --flavor prod --dart-define-from-file=env/prod.json --release

# Build AAB
flutter build appbundle --flavor prod --dart-define-from-file=env/prod.json --release
```

## Testing

```bash
# Run all tests with coverage
flutter test --coverage

# Run widget tests
flutter test

# Run specific test file
flutter test test/features/home/home_screen_test.dart

# Integration tests (requires Android emulator)
flutter drive --target integration_test/app_test.dart
```

## Linting & Formatting

```bash
# Analyze code
flutter analyze

# Format code
dart format .
```

## Architecture

This app follows the clean architecture pattern:

- **lib/features/** — Feature modules (domain, data, presentation)
- **lib/manifest.dart** — App configuration and bootstrap
- **test/** — Unit and widget tests
- **integration_test/** — E2E tests
- **env/** — Build configuration per flavor

Every feature is gated by a PostHog feature flag with the format `{{product_key}}.<feature>`.

## Native Modules

None currently. If native Android or iOS code is needed, see `docs/NATIVE_MODULES.md` for the justification process.
