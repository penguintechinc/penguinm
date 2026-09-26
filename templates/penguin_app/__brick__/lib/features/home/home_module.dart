import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_ui/penguin_ui.dart';
import 'presentation/home_screen.dart';

/// Home feature module for {{display_name}}.
///
/// Provides the home screen as the default landing page. Unlike other modules,
/// this is ungated (flagKey is null) to ensure every app always has a home
/// screen available, preventing lock-out if all features are disabled.
class HomeModule implements FeatureModule {
  /// Creates a home module.
  const HomeModule();

  /// Module identifier. Used for logging and debugging.
  @override
  String get id => 'home';

  /// Feature flag key for this module. Null because the home module is
  /// ungated by design (spec §4.10, ruling R35): gating this module could
  /// render an app unusable if all features are feature-flagged off.
  @override
  String? get flagKey => null;

  /// Provides the home route (/home) served by HomeScreen.
  @override
  List<RouteBase> routes(Ref ref) => [
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
  ];

  /// Navigation destination for the home tab in the bottom navigation bar or sidebar.
  @override
  List<NavigationDestinationSpec> get destinations => [
    const NavigationDestinationSpec(
      route: '/home',
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
  ];

  /// No provider overrides needed for the home module.
  @override
  List<Override> get providerOverrides => const [];

  /// No async startup work needed for the home module.
  @override
  Future<void> init(Ref ref) async {}
}
