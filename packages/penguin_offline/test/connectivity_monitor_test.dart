import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:penguin_offline/src/connectivity_monitor.dart';
import 'package:penguin_offline/src/connectivity_status.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  group('ConnectivityMonitor', () {
    late _MockConnectivity plugin;
    late StreamController<List<ConnectivityResult>> changes;

    setUp(() {
      plugin = _MockConnectivity();
      changes = StreamController<List<ConnectivityResult>>.broadcast();
      when(
        () => plugin.onConnectivityChanged,
      ).thenAnswer((_) => changes.stream);
    });

    tearDown(() async {
      await changes.close();
    });

    test('current is unknown before start', () {
      final monitor = ConnectivityMonitor(plugin: plugin);
      expect(monitor.current, ConnectivityStatus.unknown);
    });

    test('start maps an active interface to online', () async {
      when(
        () => plugin.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.wifi]);
      final monitor = ConnectivityMonitor(plugin: plugin);

      await monitor.start();

      expect(monitor.current, ConnectivityStatus.online);
      await monitor.dispose();
    });

    test('start maps [none] to offline', () async {
      when(
        () => plugin.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.none]);
      final monitor = ConnectivityMonitor(plugin: plugin);

      await monitor.start();

      expect(monitor.current, ConnectivityStatus.offline);
      await monitor.dispose();
    });

    test('start maps an empty result list to offline', () async {
      when(
        () => plugin.checkConnectivity(),
      ).thenAnswer((_) async => <ConnectivityResult>[]);
      final monitor = ConnectivityMonitor(plugin: plugin);

      await monitor.start();

      expect(monitor.current, ConnectivityStatus.offline);
      await monitor.dispose();
    });

    test(
      'a multi-interface result counts as online if any entry is active',
      () async {
        when(() => plugin.checkConnectivity()).thenAnswer(
          (_) async => [ConnectivityResult.none, ConnectivityResult.mobile],
        );
        final monitor = ConnectivityMonitor(plugin: plugin);

        await monitor.start();

        expect(monitor.current, ConnectivityStatus.online);
        await monitor.dispose();
      },
    );

    test('status stream emits when connectivity changes after start', () async {
      when(
        () => plugin.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.none]);
      final monitor = ConnectivityMonitor(plugin: plugin);
      await monitor.start();

      final emitted = <ConnectivityStatus>[];
      final sub = monitor.status.listen(emitted.add);

      changes.add([ConnectivityResult.wifi]);
      await pumpEventQueue();

      expect(emitted, [ConnectivityStatus.online]);
      expect(monitor.current, ConnectivityStatus.online);

      await sub.cancel();
      await monitor.dispose();
    });

    test('does not emit a duplicate event for an unchanged status', () async {
      when(
        () => plugin.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.wifi]);
      final monitor = ConnectivityMonitor(plugin: plugin);
      await monitor.start();

      final emitted = <ConnectivityStatus>[];
      final sub = monitor.status.listen(emitted.add);

      changes.add([ConnectivityResult.mobile]); // still "online" overall
      await pumpEventQueue();

      expect(emitted, isEmpty);

      await sub.cancel();
      await monitor.dispose();
    });

    test(
      'start can be called again and replaces the previous subscription',
      () async {
        when(
          () => plugin.checkConnectivity(),
        ).thenAnswer((_) async => [ConnectivityResult.none]);
        final monitor = ConnectivityMonitor(plugin: plugin);

        await monitor.start();
        await monitor.start();

        verify(() => plugin.checkConnectivity()).called(2);
        await monitor.dispose();
      },
    );

    test('dispose is safe even when start was never called', () async {
      final monitor = ConnectivityMonitor(plugin: plugin);
      await monitor.dispose();
    });

    test('dispose closes the status stream', () async {
      when(
        () => plugin.checkConnectivity(),
      ).thenAnswer((_) async => [ConnectivityResult.none]);
      final monitor = ConnectivityMonitor(plugin: plugin);
      await monitor.start();
      await monitor.dispose();

      expect(monitor.status.isBroadcast, isTrue);
      await expectLater(monitor.status.isEmpty, completion(isTrue));
    });
  });
}
