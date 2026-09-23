import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_ui/penguin_ui.dart';

/// Minimal concrete [FeatureModule] exercising the default members
/// (`providerOverrides`, `init`) so their fallback behaviour is covered.
class _MinimalModule extends FeatureModule {
  @override
  String get id => 'minimal';

  @override
  String? get flagKey => 'product.minimal';

  @override
  List<RouteBase> routes(Ref ref) => [
    GoRoute(path: '/minimal', builder: (context, state) => const SizedBox()),
  ];

  @override
  List<NavigationDestinationSpec> get destinations => const [];
}

/// A module overriding every member, including the ungated (`flagKey ==
/// null`) home case (ruling R35).
class _HomeModule extends FeatureModule {
  bool initCalled = false;

  @override
  String get id => 'home';

  @override
  String? get flagKey => null;

  @override
  List<RouteBase> routes(Ref ref) => [
    GoRoute(path: '/home', builder: (context, state) => const SizedBox()),
  ];

  @override
  List<NavigationDestinationSpec> get destinations => const [
    NavigationDestinationSpec(
      route: '/home',
      label: 'Home',
      icon: Icons.home,
      selectedIcon: Icons.home,
    ),
  ];

  @override
  List<Override> get providerOverrides => [_marker.overrideWithValue(true)];

  @override
  Future<void> init(Ref ref) async {
    initCalled = true;
  }
}

final _marker = Provider<bool>((ref) => false);

/// Exposes a real [Ref] (via a throwaway provider read) for exercising
/// [FeatureModule] methods that require one, without needing a widget tree.
final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  test('flagKey null marks the ungated home/login module (R35)', () {
    final module = _HomeModule();
    expect(module.flagKey, isNull);
  });

  test('flagKey non-null gates a module by the product flag key', () {
    final module = _MinimalModule();
    expect(module.flagKey, 'product.minimal');
  });

  test('default providerOverrides is empty', () {
    final module = _MinimalModule();
    expect(module.providerOverrides, isEmpty);
  });

  test('default init is a no-op that completes', () async {
    final module = _MinimalModule();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ref = container.read(_refProvider);
    await expectLater(module.init(ref), completes);
  });

  test('overridden providerOverrides and init are used as given', () async {
    final module = _HomeModule();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ref = container.read(_refProvider);
    expect(module.providerOverrides, hasLength(1));
    await module.init(ref);
    expect(module.initCalled, isTrue);
  });

  test('routes and destinations reflect the module contents', () {
    final module = _HomeModule();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ref = container.read(_refProvider);
    expect(module.routes(ref), hasLength(1));
    expect(module.destinations, hasLength(1));
    expect(module.destinations.single.route, '/home');
  });
}
