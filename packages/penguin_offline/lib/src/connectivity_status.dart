/// Coarse network reachability as observed by [ConnectivityMonitor].
enum ConnectivityStatus {
  /// At least one network interface (Wi-Fi, mobile, ethernet, VPN, ...) is
  /// active.
  online,

  /// No active network interface was reported.
  offline,

  /// No check has completed yet (before [ConnectivityMonitor.start] runs).
  unknown,
}
