/// Abstraction over wall-clock time so tests can inject deterministic time
/// instead of depending on [DateTime.now] directly.
abstract interface class Clock {
  /// Returns the current time.
  DateTime now();
}

/// Production [Clock] backed by the real system clock.
class SystemClock implements Clock {
  /// Creates a system clock.
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
