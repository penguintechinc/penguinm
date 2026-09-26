# Adding a New App

Step-by-step guide to scaffold and integrate a new app into the penguinm monorepo.

## Quickstart

```bash
make new-app NAME=myapp PRODUCT=myproduct DISPLAY="My App"
cd apps/myapp
flutter test            # Verify tests pass
make lint               # Verify lint/analyze are clean
```

Then proceed to feature development.

## Manual Scaffolding (if not using `make new-app`)

### 1. Create the app directory and `pubspec.yaml`

```bash
flutter create --org io.penguintech --platforms android,ios --empty apps/myapp
cd apps/myapp
```

Edit `pubspec.yaml`:
```yaml
name: myapp
description: My App description.
publish_to: none
version: 0.1.0+1

environment:
  sdk: '>=3.12.2 <4.0.0'
  flutter: '>=3.44.8'

resolution: workspace

dependencies:
  flutter:
    sdk: flutter
  penguin_app_shell:
    path: ../../shells/penguin_app_shell
  penguin_core:
    path: ../../packages/penguin_core
  penguin_ui:
    path: ../../packages/penguin_ui
  penguin_auth:
    path: ../../packages/penguin_auth
  # ... other packages from Appendix A

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: 6.0.0
  penguin_testing:
    path: ../../packages/penguin_testing
```

### 2. Create `lib/main.dart`

Keep it ≤15 lines. No widgets, no logic — just call `runPenguinApp`:

```dart
import 'package:flutter/material.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'manifest.dart';

void main() {
  runPenguinApp(manifest);
}
```

### 3. Create `lib/manifest.dart`

```dart
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_ui/penguin_ui.dart';
import 'features/springboard/springboard_module.dart';
import 'features/profile/profile_module.dart';

final manifest = AppManifest(
  productKey: 'myproduct',
  appName: 'My App',
  appVersion: '0.1.0',
  config: AppConfig.fromEnvironment(
    productKey: 'myproduct',
    appVersion: '0.1.0',
  ),
  auth: AuthConfig.hosted(
    issuer: Uri.parse('https://auth.myproduct.app'), // e.g., from env/prod.json
    clientId: 'io.penguintech.myapp',
    redirectUri: 'io.penguintech.myapp://oauth/callback',
  ),
  features: [
    SpringboardModule(),
    ProfileModule(),
    // ... other modules
  ],
  brand: const AppBrand(
    displayName: 'My App',
    logoAsset: 'assets/logo.png',
  ),
);
```

For products without hosted login yet (transitional):
```dart
auth: AuthConfig.password(
  loginPath: '/api/v1/auth/login',
  refreshPath: '/api/v1/auth/refresh',
  logoutPath: '/api/v1/auth/logout',
  profilePath: '/api/v1/auth/profile',
  mfa: true,
),
```

### 4. Create environment config files

`env/dev.json`:
```json
{
  "api_base_url": "http://127.0.0.1:8000",
  "otel_exporter_otlp_endpoint": "http://127.0.0.1:4318",
  "posthog_host": "http://127.0.0.1:8000",
  "posthog_project_key": "phc_test",
  "license_server_url": "https://license.penguintech.io"
}
```

`env/beta.json`:
```json
{
  "api_base_url": "https://myproduct.penguintech.cloud",
  "otel_exporter_otlp_endpoint": "http://otlp.internal:4318",
  "posthog_host": "https://posthog.penguintech.cloud",
  "posthog_project_key": "phc_...",
  "license_server_url": "https://license.penguintech.io"
}
```

`env/prod.json`:
```json
{
  "api_base_url": "https://myproduct.app",
  "otel_exporter_otlp_endpoint": "https://otlp.penguintech.cloud",
  "posthog_host": "https://posthog.penguintech.cloud",
  "posthog_project_key": "phc_...",
  "license_server_url": "https://license.penguintech.io"
}
```

### 5. Create features

Example: `lib/features/springboard/springboard_module.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_ui/penguin_ui.dart';

class SpringboardModule extends FeatureModule {
  @override
  String get id => 'springboard';

  @override
  String? get flagKey => 'myproduct.springboard';

  @override
  List<RouteBase> routes(Ref ref) => [
    GoRoute(
      path: '/springboard',
      builder: (context, state) => const SpringboardScreen(),
    ),
  ];

  @override
  List<NavigationDestinationSpec> get destinations => [
    NavigationDestinationSpec(
      route: '/springboard',
      label: 'Springboard',
      icon: Icons.dashboard,
      selectedIcon: Icons.dashboard_filled,
    ),
  ];
}

class SpringboardScreen extends ConsumerWidget {
  const SpringboardScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Springboard')),
      body: const Center(child: Text('Welcome')),
    );
  }
}
```

### 6. Add tests

`test/features/springboard/springboard_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_testing/penguin_testing.dart';
import 'package:myapp/manifest.dart';

void main() {
  group('SpringboardScreen', () {
    testWidgets('renders title', (tester) async {
      await pumpPenguinApp(tester, manifest);
      expect(find.text('Springboard'), findsWidgets);
    });
  });
}
```

### 7. Create `README.md`

```markdown
# My App

[Description]

## Offline Capabilities

See [docs/OFFLINE.md](../../docs/OFFLINE.md) for details.

- Springboard: read-only (cached list items)
- Profile: read/write (profile changes queued for sync)

## Environment & Build

| Flavor | API Base | Use Case |
|---|---|---|
| dev | http://127.0.0.1:8000 | Local development |
| beta | https://myproduct.penguintech.cloud | Testing |
| prod | https://myproduct.app | Production |

## Build

```bash
# Debug
flutter run --flavor dev

# Release APK
flutter build apk --release --flavor prod --dart-define-from-file=env/prod.json

# Release AAB (Play Store)
flutter build appbundle --release --flavor prod --dart-define-from-file=env/prod.json
```

## Testing

```bash
flutter test
flutter test --coverage
```

## Native Modules

None (or list any used: e.g., "Credential Manager for passkey support").
```

### 8. Register the app in the workspace

Edit root `pubspec.yaml`, add to `workspace:` list:

```yaml
workspace:
  - apps/penguin_reference
  - apps/penguincloud
  - apps/myapp        # <-- add here, alphabetically
  - packages/...
```

### 9. Update CI/CD

Edit `.github/workflows/ci.yml`, add `myapp` to the Android build matrix if it should be built in CI.

## Feature Modules

Each feature module is a self-contained tree under `lib/features/<feature>/`:

```
lib/features/springboard/
├── springboard_module.dart      # FeatureModule implementation
├── data/
│   ├── springboard_repository.dart
│   └── springboard_dto.dart
├── domain/
│   └── springboard_item.dart
└── presentation/
    ├── screens/
    │   └── springboard_screen.dart
    ├── widgets/
    │   └── springboard_tile.dart
    └── providers/
        └── springboard_provider.dart
```

**Rules:**
- Module id (`springboard`) matches the server module name
- Flag key is `<productKey>.<id>` (e.g., `myproduct.springboard`)
- Routes are gated by the flag; unseen flags default OFF
- Only `data/` layer calls `PenguinApiClient` or `OfflineStore`
- `domain/` layer is pure logic, no Flutter imports

## Naming Conventions

| Item | Format | Example |
|---|---|---|
| App directory | snake_case | `myapp` |
| Feature directory | snake_case | `springboard`, `profile` |
| Module class | PascalCase + "Module" | `SpringboardModule` |
| Screen class | PascalCase + "Screen" | `SpringboardScreen` |
| Widget class | PascalCase | `SpringboardTile` |
| Flag key | `<product>.<feature>` | `myproduct.springboard` |
| Android applicationId | `io.penguintech.<app>` | `io.penguintech.myapp` |

## Next Steps

1. Implement your features
2. Write tests (unit, widget, integration)
3. Run `make lint`, `make test`, `make coverage`
4. Create a PR with your changes
5. After merge, the app is built and tested by CI

See `APP_STANDARDS.md` for form factors, offline sync, native modules, and testing requirements.
