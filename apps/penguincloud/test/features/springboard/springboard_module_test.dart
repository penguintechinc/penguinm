import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:penguincloud/features/springboard/springboard_module.dart';

/// Exposes a real [Ref] (via a throwaway provider read) for exercising
/// [FeatureModule] methods that require one, without needing a widget
/// tree — mirrors `shells/penguin_app_shell/test/feature_module_test.dart`.
final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  group('SpringboardModule', () {
    test('id and flagKey match spec §11.2', () {
      final module = SpringboardModule();
      expect(module.id, 'springboard');
      expect(module.flagKey, 'penguincloud.springboard');
    });

    test('contributes a single /home route', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ref = container.read(_refProvider);
      final module = SpringboardModule();

      final routes = module.routes(ref);

      expect(routes, hasLength(1));
      expect((routes.single as GoRoute).path, '/home');
    });

    test('contributes exactly one Home navigation destination', () {
      final module = SpringboardModule();
      expect(module.destinations, hasLength(1));
      expect(module.destinations.single.route, '/home');
      expect(module.destinations.single.label, 'Home');
    });

    test('has no provider overrides and a no-op init', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ref = container.read(_refProvider);
      final module = SpringboardModule();

      expect(module.providerOverrides, isEmpty);
      await expectLater(module.init(ref), completes);
    });
  });
}
