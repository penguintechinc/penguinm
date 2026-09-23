# Changelog

All notable changes to PenguinCloud will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-09-22

### Added

- Migrated from `penguincloud/services/mobile` onto the `penguinm` shell (`runPenguinApp`/`AppManifest`), per spec §11.2
- Springboard (home) feature module: role-filtered destination grid, flag `penguincloud.springboard`
- Profile feature module: account details fetched from `GET /api/v1/auth/profile`, sign-out, flag `penguincloud.profile`
- Transitional password-auth login screen with a tablet branding pane (`AppManifest.loginBuilder`)
- `io.penguintech.penguincloud` applicationId, dev/beta/prod Android flavors
- iOS deployment target raised to 15.0 (Podfile + `project.pbxproj`); iOS stays dormant, not built in CI

### Changed

- Auth/API/secure-storage moved to the shared `penguin_auth`/`penguin_api` packages — `AuthProvider`, `AuthService`, `ApiClient`, `SecureStorage` deleted
- Duplicated amber/slate theme constants replaced by `PenguinTheme`'s Material 3 colour scheme
