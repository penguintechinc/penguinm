import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:{{name}}/features/home/home_module.dart';

void main() {
  group('HomeModule', () {
    test('id returns home', () {
      const module = HomeModule();
      expect(module.id, 'home');
    });

    test('flagKey returns null', () {
      const module = HomeModule();
      expect(module.flagKey, isNull);
    });

    test('routes returns one route', () {
      const module = HomeModule();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final probe = Provider<List<RouteBase>>((ref) => module.routes(ref));
      final routes = container.read(probe);
      expect(routes, isNotEmpty);
    });

    test('destinations contains home destination', () {
      const module = HomeModule();
      expect(module.destinations, isNotEmpty);
      expect(module.destinations.first.label, 'Home');
    });

    test('providerOverrides is empty', () {
      const module = HomeModule();
      expect(module.providerOverrides, isEmpty);
    });

    test('init completes without error', () async {
      const module = HomeModule();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final probe = Provider<Ref>((ref) => ref);
      final ref = container.read(probe);
      await expectLater(module.init(ref), completes);
    });
  });
}
