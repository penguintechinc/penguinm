import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:penguincloud/features/profile/profile_module.dart';

/// Exposes a real [Ref] (via a throwaway provider read) for exercising
/// [FeatureModule] methods that require one, without needing a widget
/// tree — mirrors `shells/penguin_app_shell/test/feature_module_test.dart`.
final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  group('ProfileModule', () {
    test('id and flagKey match spec §11.2', () {
      final module = ProfileModule();
      expect(module.id, 'profile');
      expect(module.flagKey, 'penguincloud.profile');
    });

    test('contributes a single /profile route', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ref = container.read(_refProvider);
      final module = ProfileModule();

      final routes = module.routes(ref);

      expect(routes, hasLength(1));
      expect((routes.single as GoRoute).path, '/profile');
    });

    test('contributes exactly one Profile navigation destination', () {
      final module = ProfileModule();
      expect(module.destinations, hasLength(1));
      expect(module.destinations.single.route, '/profile');
      expect(module.destinations.single.label, 'Profile');
    });

    test('has no provider overrides and a no-op init', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ref = container.read(_refProvider);
      final module = ProfileModule();

      expect(module.providerOverrides, isEmpty);
      await expectLater(module.init(ref), completes);
    });
  });
}
