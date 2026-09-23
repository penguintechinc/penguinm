# Mason Bricks for penguinm

This directory contains Mason bricks for scaffolding Flutter apps and components in the penguinm monorepo.

## Available Bricks

### penguin_app

Generates a new Flutter app under `apps/<name>/` with all boilerplate including pubspec.yaml, manifests, env files, a home feature module, tests, and documentation.

**Usage:**

```bash
dart pub global activate mason_cli 0.1.3
mason make penguin_app \
  --name my_app \
  --product_key penguinm \
  --display_name "My App"
```

**Variables:**
- `name` (required): App name in snake_case
- `product_key` (required): Product key (e.g., `penguinm`, `waddlebot`)
- `display_name` (required): Display name for the app
- `org` (optional): Organization prefix (default: `io.penguintech`)
- `api_base_url_dev` (optional): Dev API base URL (default: `http://10.0.2.2:5000`)

See `penguin_app/README.md` for full details.
