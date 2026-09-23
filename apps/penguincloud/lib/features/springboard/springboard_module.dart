import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_ui/penguin_ui.dart';

import 'presentation/springboard_screen.dart';

/// The PenguinCloud home ("springboard") module: a role-filtered grid of
/// destination tiles at [AppManifest.homeRoute] (`/home`), gated by the
/// `penguincloud.springboard` flag per spec §11.2's migration mapping.
class SpringboardModule extends FeatureModule {
  @override
  String get id => 'springboard';

  @override
  String? get flagKey => 'penguincloud.springboard';

  @override
  List<RouteBase> routes(Ref ref) => [
    GoRoute(
      path: '/home',
      builder: (context, state) => const SpringboardScreen(),
    ),
  ];

  @override
  List<NavigationDestinationSpec> get destinations => const [
    NavigationDestinationSpec(
      route: '/home',
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
  ];
}
