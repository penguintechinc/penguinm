import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_ui/penguin_ui.dart';

import 'presentation/offline_demo_screen.dart';

/// Offline-capability demo feature module for Penguin Reference: a cached
/// notes list, an "add note" form that writes through `SyncQueue`, and a
/// dead-letter snackbar — gated by `penguinm.offline_demo` so the shell's
/// flag-gating (spec §4.10) is exercised end-to-end alongside the ungated
/// home module.
class OfflineDemoModule implements FeatureModule {
  /// Creates the offline demo module.
  const OfflineDemoModule();

  /// Module identifier, mirrored by [flagKey].
  @override
  String get id => 'offline_demo';

  /// Flag key gating this module: `penguinm.offline_demo`.
  @override
  String? get flagKey => 'penguinm.offline_demo';

  /// Provides the `/offline-demo` route served by [OfflineDemoScreen].
  @override
  List<RouteBase> routes(Ref ref) => [
    GoRoute(
      path: '/offline-demo',
      builder: (context, state) => const OfflineDemoScreen(),
    ),
  ];

  /// Navigation destination for the offline demo tab.
  @override
  List<NavigationDestinationSpec> get destinations => [
    const NavigationDestinationSpec(
      route: '/offline-demo',
      label: 'Offline Demo',
      icon: Icons.cloud_off_outlined,
      selectedIcon: Icons.cloud_off,
    ),
  ];

  /// No provider overrides needed — this feature reads the shell's shared
  /// offline/sync providers directly.
  @override
  List<Override> get providerOverrides => const [];

  /// No async startup work needed for this module.
  @override
  Future<void> init(Ref ref) async {}
}
