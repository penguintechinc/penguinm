import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The app's `GoRouter` instance, built from the enabled feature modules.
/// `PenguinApp` overrides this in a nested `ProviderScope` bound to its own
/// `AppManifest` — reading it before that override is a programming error.
final goRouterProvider = Provider<GoRouter>(
  (ref) => throw UnimplementedError(
    'goRouterProvider must be overridden by PenguinApp with a manifest-bound router',
  ),
);
