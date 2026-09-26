import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:penguin_reference/features/offline_demo/offline_demo_module.dart';

void main() {
  group('OfflineDemoModule', () {
    test('id returns offline_demo', () {
      const module = OfflineDemoModule();
      expect(module.id, 'offline_demo');
    });

    test('flagKey returns penguinm.offline_demo', () {
      const module = OfflineDemoModule();
      expect(module.flagKey, 'penguinm.offline_demo');
    });

    test('routes returns one route', () {
      const module = OfflineDemoModule();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final probe = Provider<List<RouteBase>>((ref) => module.routes(ref));
      final routes = container.read(probe);
      expect(routes, isNotEmpty);
    });

    test('destinations contains the offline demo destination', () {
      const module = OfflineDemoModule();
      expect(module.destinations, isNotEmpty);
      expect(module.destinations.first.label, 'Offline Demo');
      expect(module.destinations.first.route, '/offline-demo');
    });

    test('providerOverrides is empty', () {
      const module = OfflineDemoModule();
      expect(module.providerOverrides, isEmpty);
    });

    test('init completes without error', () async {
      const module = OfflineDemoModule();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final probe = Provider<Ref>((ref) => ref);
      final ref = container.read(probe);
      await expectLater(module.init(ref), completes);
    });
  });
}
