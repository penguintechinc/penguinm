import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_ui/penguin_ui.dart';

import 'feature_module.dart';
import 'sibling_apps.dart';

/// Declarative description of one penguinm app: product identity,
/// build-time config, auth mode, feature modules, and branding — the
/// single input `runPenguinApp` needs to bootstrap and render the app.
class AppManifest {
  /// Creates an app manifest. [applicationId] is optional (falls back to
  /// [productKey] wherever an Android application id is needed, e.g. the
  /// store-URL fallback in `UpdatePrompt`) — set it explicitly whenever an
  /// app's applicationId differs from its product key (see
  /// `penguin_core`'s `KnownApps` for the canonical id per app).
  const AppManifest({
    required this.productKey,
    required this.appName,
    required this.appVersion,
    required this.config,
    required this.auth,
    required this.features,
    this.brand = const AppBrand(),
    this.homeRoute = '/home',
    this.loginRoute = '/login',
    this.loginBuilder,
    this.extraRoutes = const [],
    this.siblings = const [],
    this.applicationId,
  });

  /// Backend product this app talks to; scopes feature-flag keys.
  final String productKey;

  /// Human-readable app name, shown on the login screen and console
  /// version overlay.
  final String appName;

  /// The app's own semantic version.
  final String appVersion;

  /// Build-time configuration (API base URL, telemetry/flag endpoints,
  /// deployment environment) — typically `AppConfig.fromEnvironment(...)`.
  final AppConfig config;

  /// How this app authenticates — hosted browser login (default) or the
  /// transitional in-app password form.
  final AuthConfig auth;

  /// The feature modules this app is composed of.
  final List<FeatureModule> features;

  /// Name/logo/optional seed colour only — every app uses `PenguinTheme`
  /// unchanged (one UX across the roster).
  final AppBrand brand;

  /// Route path the router lands authenticated users on.
  final String homeRoute;

  /// Route path the router lands unauthenticated users on.
  final String loginRoute;

  /// Overrides the login screen; defaults to `HostedLoginScreen` unless
  /// [auth] is `AuthConfig.password`, in which case the default wraps
  /// flutter_libs `LoginPageBuilder` instead.
  final Widget Function(BuildContext, WidgetRef)? loginBuilder;

  /// Additional top-level routes outside the authenticated shell (e.g. a
  /// public page that needs neither auth nor chrome).
  final List<RouteBase> extraRoutes;

  /// Sibling apps this app can hand off to via `SiblingAppLauncher`.
  final List<SiblingApp> siblings;

  /// Android application id (`io.penguintech.<app>`); falls back to
  /// [productKey] when omitted.
  final String? applicationId;
}
