import 'dart:async';

import 'package:penguin_offline/penguin_offline.dart';

/// Settable [ConnectivityMonitor] fake: [setStatus] drives [current]/
/// [status] directly instead of a real `connectivity_plus` platform
/// channel. Extends the real (concrete) [ConnectivityMonitor] — required
/// since `SyncQueue` and providers are typed to it directly — overriding
/// every member. The inherited constructor still runs (constructing an
/// inert `Connectivity()` plugin singleton), but since every overridden
/// member is self-contained and none call `super`, no platform channel or
/// I/O is ever invoked.
class FakeConnectivityMonitor extends ConnectivityMonitor {
  /// Creates a fake monitor starting at [initial] (defaults to
  /// [ConnectivityStatus.online]).
  FakeConnectivityMonitor([
    ConnectivityStatus initial = ConnectivityStatus.online,
  ]) : _current = initial;

  ConnectivityStatus _current;
  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();

  @override
  ConnectivityStatus get current => _current;

  @override
  Stream<ConnectivityStatus> get status => _controller.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) await _controller.close();
  }

  /// Sets the current status, emitting on [status] only when it changes
  /// (matching the real monitor's de-duplication behaviour).
  void setStatus(ConnectivityStatus next) {
    if (next == _current) return;
    _current = next;
    if (!_controller.isClosed) _controller.add(next);
  }
}
