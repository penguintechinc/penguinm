import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';

import 'features/profile/profile_module.dart';
import 'features/springboard/springboard_module.dart';
import 'login_screen.dart';

/// PenguinCloud's own semantic version, reported to the client-version
/// endpoint and shown in the console version overlay.
///
/// Sourced from a literal constant (kept in sync with `pubspec.yaml`'s
/// `version:` field) rather than `package_info_plus`: spec §11.2 calls for
/// reading it from that package, but `package_info_plus` is not a direct
/// dependency of this app's `pubspec.yaml` — Appendix A scopes it to
/// `shell`/`gazer` only (T1a's pubspec-ownership decision). Adding it here
/// is pubspec-owner work, out of this task's file scope; see
/// `docs/MIGRATION.md` for the full note.
const String appVersion = '0.1.0';

/// Builds the [AppManifest] for PenguinCloud by resolving [AppConfig] from
/// build-time `--dart-define` values (`AppConfig.fromEnvironment`) — the
/// entry point `main.dart` calls this. Delegates the actual manifest
/// construction to [buildManifestFor], which takes an [AppConfig] directly
/// so it can be exercised in tests without dart-defines (`flutter test`
/// passes none — see `docs/MIGRATION.md`).
AppManifest buildManifest() {
  return buildManifestFor(
    config: AppConfig.fromEnvironment(
      productKey: 'penguincloud',
      appVersion: appVersion,
    ),
  );
}

/// Builds PenguinCloud's [AppManifest] from an explicit [config]: the
/// transitional password-auth path (`docs/AUTH.md` — tracked there until
/// PenguinCloud's backend gets hosted login), its two feature modules, and
/// the tablet-branding-pane login screen.
AppManifest buildManifestFor({required AppConfig config}) {
  const appName = 'PenguinCloud';
  const auth = AuthConfig.password(
    loginPath: '/api/v1/auth/login',
    refreshPath: '/api/v1/auth/refresh',
    logoutPath: '/api/v1/auth/logout',
    profilePath: '/api/v1/auth/profile',
    mfa: true,
  );

  // `late final` so the `loginBuilder` closure below can reference the
  // manifest being built without calling `buildManifest()` again —
  // `PenguinCloudLoginScreen` strips `loginBuilder` itself before
  // delegating to the shell's default form, so this is not
  // self-recursive; the closure only runs once the login route is first
  // built, by which point `manifest` is already assigned.
  late final AppManifest manifest;
  manifest = AppManifest(
    productKey: config.productKey,
    appName: appName,
    appVersion: appVersion,
    config: config,
    auth: auth,
    features: [SpringboardModule(), ProfileModule()],
    applicationId: 'io.penguintech.penguincloud',
    loginBuilder: (context, ref) => PenguinCloudLoginScreen(manifest: manifest),
  );
  return manifest;
}
