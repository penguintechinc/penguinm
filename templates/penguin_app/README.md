# penguin_app

Mason brick that generates a new Flutter app under `apps/<name>/` in the penguinm monorepo.

Generates:
- `pubspec.yaml` with workspace resolution and exact-pinned dependencies
- `env/{dev,beta,prod}.json` with public build config
- `lib/main.dart` entry point (≤15 lines)
- `lib/manifest.dart` with `AppManifest` definition
- `lib/features/home/` example feature module (gated by `<product_key>.home`)
- `test/` with unit tests, fixtures, and telemetry smoke test
- `integration_test/app_test.dart` for critical flows
- `README.md` and `CHANGELOG.md`

Usage:

```bash
dart pub global activate mason_cli 0.1.3
mason make penguin_app \
  --name sample_app \
  --product_key penguinm \
  --display_name "Sample App"
```

Variables:
- `name` (required): App name in snake_case
- `product_key` (required): Product key
- `display_name` (required): Display name for the app
- `org` (default: `io.penguintech`): Organization for Android applicationId
- `api_base_url_dev` (default: `http://10.0.2.2:5000`): API base URL for dev environment
