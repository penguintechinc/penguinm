import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_offline/penguin_offline.dart';
import 'package:penguin_ui/penguin_ui.dart';

import 'app_manifest.dart';
import 'chrome.dart';
import 'providers.dart';
import 'router.dart';

/// Renders one penguinm app: `PenguinTheme` (unmodified except for
/// `manifest.brand.seed`), a manifest-bound `GoRouter` (built lazily in a
/// nested `ProviderScope` so it can `ref.watch` flag/auth state and rebuild
/// on change), and `AppChrome` wrapped around the routed content. Also
/// kicks off `AuthController.initialize()` and eagerly instantiates the
/// offline `SyncQueue` on first mount — deferred to widget lifecycle
/// (rather than `Bootstrap.run`) so the exact same provider container the
/// rest of the widget tree reads from is the one these calls run against,
/// whether the app was started via `runPenguinApp` or `pumpPenguinApp`.
class PenguinApp extends ConsumerStatefulWidget {
  /// Creates the app widget for [manifest].
  const PenguinApp({required this.manifest, super.key});

  /// The app's manifest — product identity, config, auth, modules,
  /// branding.
  final AppManifest manifest;

  @override
  ConsumerState<PenguinApp> createState() => _PenguinAppState();
}

class _PenguinAppState extends ConsumerState<PenguinApp> {
  @override
  void initState() {
    super.initState();
    // AuthController.initialize() has its own internal try/catch (never
    // throws) and must not block the first frame.
    unawaited(ref.read(authControllerProvider.notifier).initialize());
    // Eagerly instantiate the sync queue so its connectivity-triggered
    // drain is wired from the first frame, not lazily on first read.
    ref.read(syncQueueProvider);
  }

  @override
  Widget build(BuildContext context) {
    final manifest = widget.manifest;
    return ProviderScope(
      overrides: [
        goRouterProvider.overrideWith((ref) => buildGoRouter(ref, manifest)),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          final router = ref.watch(goRouterProvider);
          return MaterialApp.router(
            title: manifest.appName,
            theme: PenguinTheme.dark(seed: manifest.brand.seed),
            themeMode: ThemeMode.dark,
            routerConfig: router,
            builder: (context, child) => AppChrome(
              manifest: manifest,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}
