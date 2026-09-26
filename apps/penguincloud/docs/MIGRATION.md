# Migration from `penguincloud/services/mobile`

Source: `penguincloud/services/mobile` (green baseline: `flutter analyze` clean, 18/18 tests). Destination mapping follows `docs/superpowers/specs/2026-09-14-penguinm-monorepo-design.md` §11.2 exactly; this file records the mapping decisions and the two dependency gaps the migration hit.

## Mapping table (source → destination)

| Source | Destination |
|---|---|
| `lib/providers/auth_provider.dart`, `services/{api_client,auth_service,secure_storage}.dart` | Deleted; replaced by `penguin_auth` (`AuthConfig.password(...)` against the existing `/api/v1/auth/{login,refresh,logout,profile}` paths) + `penguin_api` |
| `lib/config/environment.dart` | `env/{dev,beta,prod}.json` + `AppConfig.fromEnvironment`; hardcoded `appVersion` kept as a literal constant instead of `package_info_plus` — see Deviation 1 below |
| `lib/app.dart`, `main.dart` | `lib/main.dart` (7 lines) + `lib/manifest.dart` |
| `screens/login_screen.dart` | `lib/login_screen.dart` (`PenguinCloudLoginScreen`, wired as `AppManifest.loginBuilder`) — the shell's default password-login form via `buildLoginScreen`, plus the ported tablet branding pane; see Deviation 2 below |
| `screens/springboard_screen.dart`, `widgets/springboard_tile.dart`, `models/springboard_item.dart`, `utils/constants.dart` | `lib/features/springboard/` (`springboard_module.dart`, `domain/springboard_item.dart`, `presentation/{springboard_screen,springboard_grid,springboard_tile}.dart`), flag `penguincloud.springboard` |
| `screens/profile_screen.dart`, `models/user.dart` | `lib/features/profile/` (`profile_module.dart`, `domain/user.dart`, `data/profile_repository.dart`, `presentation/{profile_screen,profile_providers}.dart`), flag `penguincloud.profile` |
| `widgets/adaptive_layout.dart`, duplicated amber/slate colour constants | `penguin_ui` (`AdaptiveLayout`, `PenguinTheme`'s Material 3 colour scheme — `Theme.of(context).colorScheme` throughout, no local hex constants) |
| `local_auth`, `provider` deps | Dropped (unused / replaced by Riverpod) |
| Android `com.penguintech.mobile`, no permissions, debug-key release signing, no flavors | `io.penguintech.penguincloud` (already scaffolded by T1a: `INTERNET` permission, dev/beta/prod flavors, debug-key release signing — verified, not modified) |
| iOS deployment target 13.0 vs Podfile 15.0 | Both set to 15.0: `ios/Podfile` created (platform :ios, '15.0'), `project.pbxproj`'s three `IPHONEOS_DEPLOYMENT_TARGET` entries bumped 13.0 → 15.0 |
| Tests (18) | Ported to Riverpod overrides via `penguin_testing`; see "Test porting" below |

## Deviations from the spec's literal wording (both dependency-driven, both documented, neither requires a pubspec edit)

### 1. `appVersion` is a literal constant, not `package_info_plus`

Spec §11.2 says "the hardcoded `appVersion` is removed (read from `package_info_plus`)". `package_info_plus` is in the workspace's `pubspec.lock` (10.2.1) but **only as a transitive dependency** — Appendix A scopes its "used by" column to `shell, gazer`, and T1a's own report (`task-T1a-report.md:78`) confirms `penguincloud`'s direct `pubspec.yaml` dependencies are `penguin_app_shell + all 8 packages, flutter_riverpod, go_router` only. Importing it directly here would fail `flutter analyze`'s `depend_on_referenced_packages` lint (enabled transitively via `penguin_lints` → `flutter_lints` → `lints/core.yaml`) under `--fatal-infos`, and this task may not edit `pubspec.yaml` (T1a owns it).

`lib/manifest.dart` instead defines `const String appVersion = '0.1.0'`, kept in sync with `pubspec.yaml`'s `version:` field by hand. **Follow-up for T1a (or whoever next owns this pubspec):** add `package_info_plus: 10.2.1` as a direct dependency, then swap `manifest.dart`'s constant for `(await PackageInfo.fromPlatform()).version` in `main.dart`, threading it into `buildManifestFor`.

### 2. The login screen never imports `flutter_libs` directly

Same root cause: `flutter_libs` is not a direct dependency of `apps/penguincloud/pubspec.yaml` either (only via `penguin_app_shell`, `penguin_ui`, `penguin_api`, etc., all of which declare it themselves). `lib/login_screen.dart` therefore never imports `package:flutter_libs/...` — it reuses `penguin_app_shell`'s already-exported `buildLoginScreen(context, ref, manifest)`, which internally wraps flutter_libs' `LoginPageBuilder` for `AuthConfig.password` per the shell's own `default_login.dart`. `PenguinCloudLoginScreen` calls it against a copy of the real manifest with `loginBuilder` cleared (avoiding self-recursion — see the doc comment on `PenguinCloudLoginScreen._delegateManifest`), and adds its own tablet branding pane using plain Material widgets + `PenguinTheme`'s colour scheme (no flutter_libs `ElderThemeData` needed).

One practical consequence: the branding customization available through the shell's default (`BrandingConfig(appName: ...)` only — no logo/tagline) is what the credential form itself renders; the richer branding (icon, tagline "Enterprise Springboard") lives in the separate pane beside it, not inside the form. If a future task adds `flutter_libs` as a direct dependency here, the form itself could carry the full `BrandingConfig` (logo + tagline) instead.

## Test porting

The legacy suite's 18 tests split cleanly by whether the class under test survived the migration:

- **Deleted along with their class** (`auth_provider_test.dart` — 4 tests, `auth_service_test.dart` — 8 tests): `AuthProvider`/`AuthService`/`SecureStorage`/`ApiClient` no longer exist in this app; their behaviour is now `penguin_auth`/`penguin_api`'s responsibility, covered by those packages' own test suites (out of this app's scope).
- **Ported 1:1** (`login_screen_test.dart` — 2 tests → `test/login_screen_test.dart`; `springboard_tile_test.dart` — 4 tests → `test/features/springboard/presentation/springboard_tile_test.dart`): same assertions, same widget structure, updated only for the Riverpod/Material-3-only rendering path.

New tests added per spec §11.2's explicit list: a 401 → refresh → replay test (`test/features/profile/data/profile_repository_test.dart`), springboard role-filtering tests (`test/features/springboard/presentation/springboard_grid_test.dart`), an auth-redirect end-to-end test (`test/app_test.dart`), and springboard-home goldens at phone/tablet (`test/goldens/springboard_golden_test.dart`) plus a tablet login-pane golden (`test/goldens/login_golden_test.dart`).
