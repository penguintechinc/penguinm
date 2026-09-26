import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:penguin_ui/penguin_ui.dart';

/// One self-contained feature area of a penguinm app — its routes, nav
/// destinations, provider overrides, and any async startup work — gated by
/// a single [flagKey] that mirrors the same-named module flag the
/// product's server and web UI already use (spec §1.1).
abstract class FeatureModule {
  /// Server module identifier, e.g. `'springboard'` — must equal the
  /// product's server module name so `flagKey` stays in sync across
  /// surfaces.
  String get id;

  /// The PostHog flag key gating this module (`'<productKey>.<id>'`), or
  /// null for the one ungated home/login module every app needs (ruling
  /// R35 — gating it could leave an app with no reachable home).
  String? get flagKey;

  /// The go_router routes this module contributes, built with [ref] so
  /// screens can read providers this module (or the shell) registers.
  List<RouteBase> routes(Ref ref);

  /// Navigation entries this module contributes to `ResponsiveScaffold`.
  List<NavigationDestinationSpec> get destinations;

  /// Riverpod overrides this module needs registered before its routes are
  /// built; empty by default.
  List<Override> get providerOverrides => const [];

  /// Optional async startup work for this module; a no-op by default.
  Future<void> init(Ref ref) async {}
}
