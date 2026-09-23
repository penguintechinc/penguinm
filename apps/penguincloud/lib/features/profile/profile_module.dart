import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_ui/penguin_ui.dart';

import 'presentation/profile_screen.dart';

/// The PenguinCloud profile module: account details and sign-out at
/// `/profile`, gated by the `penguincloud.profile` flag per spec §11.2's
/// migration mapping.
class ProfileModule extends FeatureModule {
  @override
  String get id => 'profile';

  @override
  String? get flagKey => 'penguincloud.profile';

  @override
  List<RouteBase> routes(Ref ref) => [
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
  ];

  @override
  List<NavigationDestinationSpec> get destinations => const [
    NavigationDestinationSpec(
      route: '/profile',
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];
}
