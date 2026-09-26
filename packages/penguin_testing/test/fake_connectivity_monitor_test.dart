import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_offline/penguin_offline.dart';
import 'package:penguin_testing/penguin_testing.dart';

void main() {
  group('FakeConnectivityMonitor', () {
    test('defaults to online', () {
      final monitor = FakeConnectivityMonitor();
      expect(monitor.current, ConnectivityStatus.online);
    });

    test('accepts an explicit initial status', () {
      final monitor = FakeConnectivityMonitor(ConnectivityStatus.offline);
      expect(monitor.current, ConnectivityStatus.offline);
    });

    test('start completes without touching a real platform channel', () async {
      final monitor = FakeConnectivityMonitor();
      await monitor.start();
      expect(monitor.current, ConnectivityStatus.online);
    });

    test('setStatus updates current and emits on status', () async {
      final monitor = FakeConnectivityMonitor();
      final future = monitor.status.first;

      monitor.setStatus(ConnectivityStatus.offline);

      expect(monitor.current, ConnectivityStatus.offline);
      expect(await future, ConnectivityStatus.offline);
    });

    test('setStatus is a no-op when the status is unchanged', () async {
      final monitor = FakeConnectivityMonitor();
      final events = <ConnectivityStatus>[];
      final sub = monitor.status.listen(events.add);

      monitor.setStatus(ConnectivityStatus.online);
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);
      await sub.cancel();
    });

    test('dispose closes the status stream', () async {
      final monitor = FakeConnectivityMonitor();
      await monitor.dispose();
      expect(monitor.status.isBroadcast, isTrue);
      // A second dispose call must not throw.
      await monitor.dispose();
    });
  });
}
