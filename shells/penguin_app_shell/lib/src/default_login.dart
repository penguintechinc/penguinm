import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_libs/flutter_libs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_ui/penguin_ui.dart';

import 'app_manifest.dart';

/// The default login screen for every penguinm app: brand name/logo and a
/// single "Continue to sign in" button that opens the hosted OIDC/SAML
/// browser flow (`LoginRequest.interactive()`) — no credential fields are
/// ever rendered here, matching the server-hosted-login ruling in spec
/// §4.5. An inline error with a retry action replaces the button when the
/// hosted flow fails or is cancelled.
class HostedLoginScreen extends ConsumerStatefulWidget {
  /// Creates the hosted login screen for [appName]/[brand].
  const HostedLoginScreen({
    required this.appName,
    required this.brand,
    super.key,
  });

  /// The app's display name, shown above the sign-in button.
  final String appName;

  /// Branding (logo/seed colour) applied to this screen.
  final AppBrand brand;

  @override
  ConsumerState<HostedLoginScreen> createState() => _HostedLoginScreenState();
}

class _HostedLoginScreenState extends ConsumerState<HostedLoginScreen> {
  bool _loading = false;
  Failure? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(authControllerProvider.notifier)
        .login(const LoginRequest.interactive());
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result.fold((_) => null, (failure) => failure);
    });
  }

  @override
  Widget build(BuildContext context) {
    final logoAsset = widget.brand.logoAsset;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (logoAsset != null) Image.asset(logoAsset, height: 96),
              const SizedBox(height: 16),
              Text(
                widget.appName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32),
              if (_error != null) ...[
                Text(
                  ErrorView.messageForFailure(_error!),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _error == null
                            ? 'Continue to sign in'
                            : 'Retry sign in',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Builds the login screen for [manifest]: `HostedLoginScreen` by default,
/// or the transitional flutter_libs `LoginPageBuilder` when `manifest.auth`
/// is `AuthConfig.password` — wired so a successful in-app login completes
/// the same `AuthController.login` flow as the hosted path. Honours a
/// caller-supplied `manifest.loginBuilder` above either default.
Widget buildLoginScreen(
  BuildContext context,
  WidgetRef ref,
  AppManifest manifest,
) {
  final override = manifest.loginBuilder;
  if (override != null) return override(context, ref);

  final auth = manifest.auth;
  if (auth is PasswordAuthConfig) {
    return _PasswordLoginScreen(manifest: manifest, auth: auth);
  }
  return HostedLoginScreen(appName: manifest.appName, brand: manifest.brand);
}

/// Transitional in-app password login, wrapping flutter_libs
/// `LoginPageBuilder` — used only while `manifest.auth` is
/// `AuthConfig.password` (see `docs/AUTH.md`).
class _PasswordLoginScreen extends ConsumerWidget {
  const _PasswordLoginScreen({required this.manifest, required this.auth});

  final AppManifest manifest;
  final PasswordAuthConfig auth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loginUrl = manifest.config.apiBaseUrl
        .replace(path: auth.loginPath)
        .toString();
    return LoginPageBuilder(
      apiConfig: LoginApiConfig(loginUrl: loginUrl),
      branding: BrandingConfig(appName: manifest.appName),
      mfaConfig: MFAConfig(enabled: auth.mfa),
      onLoginSuccess: (response) {
        unawaited(
          ref
              .read(authControllerProvider.notifier)
              .login(LoginRequest.fromLoginResponse(response))
              .then((_) {}),
        );
      },
    );
  }
}
