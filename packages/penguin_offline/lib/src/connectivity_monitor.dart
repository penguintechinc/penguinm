import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'connectivity_status.dart';

/// Watches device connectivity via [Connectivity] and exposes a single
/// [ConnectivityStatus]: any reported interface other than
/// [ConnectivityResult.none] counts as online. Call [start] once before
/// reading [status]/[current]; [dispose] tears the subscription down.
class ConnectivityMonitor {
  /// Creates a monitor wrapping [plugin] (defaults to a real [Connectivity]
  /// backed by platform channels).
  ConnectivityMonitor({Connectivity? plugin})
    : _plugin = plugin ?? Connectivity();

  final Connectivity _plugin;
  final StreamController<ConnectivityStatus> _statusController =
      StreamController<ConnectivityStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  ConnectivityStatus _current = ConnectivityStatus.unknown;

  /// Emits a new value each time the derived connectivity status changes.
  Stream<ConnectivityStatus> get status => _statusController.stream;

  /// The most recently observed status; [ConnectivityStatus.unknown] until
  /// [start] completes its first check.
  ConnectivityStatus get current => _current;

  /// Performs an initial connectivity check and begins listening for
  /// changes. Safe to call more than once — a prior subscription is
  /// cancelled first.
  Future<void> start() async {
    await _subscription?.cancel();
    _setStatus(_mapResults(await _plugin.checkConnectivity()));
    _subscription = _plugin.onConnectivityChanged.listen(
      (results) => _setStatus(_mapResults(results)),
    );
  }

  /// Cancels the connectivity subscription and closes [status]. Safe to
  /// call even when [start] was never called.
  Future<void> dispose() async {
    await _subscription?.cancel();
    if (!_statusController.isClosed) {
      await _statusController.close();
    }
  }

  void _setStatus(ConnectivityStatus next) {
    if (next == _current) return;
    _current = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  /// Any interface other than [ConnectivityResult.none] counts as online —
  /// including `bluetooth`/`other`/`satellite`, which don't guarantee a
  /// working route to the API. This is a deliberate fail-open choice: a
  /// false "online" at worst wastes one failed sync attempt (retried with
  /// backoff), while a false "offline" would block queued writes from ever
  /// being attempted.
  ConnectivityStatus _mapResults(List<ConnectivityResult> results) {
    if (results.isEmpty) return ConnectivityStatus.offline;
    final hasActiveInterface = results.any(
      (result) => result != ConnectivityResult.none,
    );
    return hasActiveInterface
        ? ConnectivityStatus.online
        : ConnectivityStatus.offline;
  }
}
