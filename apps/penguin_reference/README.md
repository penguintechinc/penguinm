# Penguin Reference

Penguin Reference is a Flutter mobile app for penguinm.

## Offline & Connectivity

| Feature | Status | Notes |
|---------|--------|-------|
| Home greetings | Offline | Static in-app content, no network dependency |
| Offline Demo — notes list | Offline | Cached in `OfflineStore`; each note shows a `StaleDataChip` with its cache age |
| Offline Demo — add note | Offline-first, syncs when online | Written to the cache immediately, then enqueued in `SyncQueue`'s durable write queue; replays automatically once connectivity returns |
| Offline Demo — dead-lettered write | Online required to detect | A write `SyncQueue` cannot deliver (e.g. server rejects it) surfaces as a snackbar ("couldn't be synced and was dropped") instead of failing silently |

## Environments & Build Flavors

| Flavor | Target | Config | API Base |
|--------|--------|--------|----------|
| `dev` | Android emulator | `env/dev.json` | `http://10.0.2.2:5000` |
| `beta` | Internal testing | `env/beta.json` | `https://api.penguinm.penguintech.cloud` |
| `prod` | Production | `env/prod.json` | `https://api.penguinm.app` |

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

Every feature is gated by a PostHog feature flag with the format `penguinm.<feature>`.

## Native Modules

None currently. If native Android or iOS code is needed, see `docs/NATIVE_MODULES.md` for the justification process.
