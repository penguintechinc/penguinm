import 'package:penguin_core/penguin_core.dart';

/// Deterministic [Clock] fake: [now] returns a settable/advanceable value
/// instead of the real wall clock, so time-dependent behaviour (token
/// expiry, cache staleness, log timestamps) is reproducible in tests.
class FakeClock implements Clock {
  /// Creates a fake clock starting at [initial] (defaults to a fixed
  /// deterministic instant rather than [DateTime.now] so tests never
  /// depend on when they happen to run).
  FakeClock([DateTime? initial]) : _now = initial ?? DateTime.utc(2026);

  DateTime _now;

  @override
  DateTime now() => _now;

  /// Sets the current time to exactly [time].
  void set(DateTime time) {
    _now = time;
  }

  /// Moves the current time forward by [duration] (negative durations move
  /// it backward).
  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}
