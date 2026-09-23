import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';

const double _tabletBreakpoint = 600;

/// PenguinCloud's login screen: the shell's default transitional
/// password-login form (`buildLoginScreen`, wrapping flutter_libs'
/// `LoginPageBuilder` — see `docs/AUTH.md`) alone on phone widths, plus a
/// branding pane beside it on tablet/expanded widths. Ported from the
/// legacy mobile app's `login_screen.dart` (`_PhoneLoginLayout` /
/// `_TabletLoginLayout`), wired as [AppManifest.loginBuilder].
///
/// This widget deliberately never imports `flutter_libs` directly (it is
/// not a direct dependency of this app's `pubspec.yaml` — see
/// `docs/MIGRATION.md`): the credential form itself is delegated to the
/// shell's already-exported `buildLoginScreen`, called against a
/// [_delegateManifest] copy with `loginBuilder` cleared (this widget IS
/// [manifest]'s `loginBuilder`, so calling `buildLoginScreen` with the
/// original manifest would recurse into itself).
class PenguinCloudLoginScreen extends StatelessWidget {
  /// Creates the login screen for [manifest].
  const PenguinCloudLoginScreen({required this.manifest, super.key});

  /// The app's manifest (branding, auth config, API base URL).
  final AppManifest manifest;

  AppManifest get _delegateManifest => AppManifest(
    productKey: manifest.productKey,
    appName: manifest.appName,
    appVersion: manifest.appVersion,
    config: manifest.config,
    auth: manifest.auth,
    features: manifest.features,
    brand: manifest.brand,
    homeRoute: manifest.homeRoute,
    loginRoute: manifest.loginRoute,
  );

  @override
  Widget build(BuildContext context) {
    final delegateManifest = _delegateManifest;
    final form = Consumer(
      builder: (context, ref, _) =>
          buildLoginScreen(context, ref, delegateManifest),
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _tabletBreakpoint) {
            return Center(
              child: Padding(padding: const EdgeInsets.all(24), child: form),
            );
          }
          return Row(
            children: [
              Expanded(child: _BrandingPane(manifest: manifest)),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: form,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The tablet/expanded branding pane: app icon, name, and tagline on a
/// tinted background — ported from the legacy app's `_TabletLoginLayout`,
/// using `PenguinTheme`'s Material 3 colour scheme instead of the
/// duplicated amber/slate hex constants the legacy widget hardcoded (spec
/// §11.2: those constants move into `penguin_ui`/`PenguinTheme`, not a
/// second local copy).
class _BrandingPane extends StatelessWidget {
  const _BrandingPane({required this.manifest});

  final AppManifest manifest;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surfaceContainerHigh,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud, size: 80, color: colors.primary),
              const SizedBox(height: 24),
              Text(
                manifest.appName,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enterprise Springboard',
                style: TextStyle(fontSize: 16, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
