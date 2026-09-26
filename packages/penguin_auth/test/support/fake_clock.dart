import 'package:penguin_core/penguin_core.dart';

/// A controllable [Clock] for testing. Allows advancing time deterministically.
class FakeClock implements Clock {
  /// Creates a fake clock starting at the given [startTime].
  FakeClock({DateTime? startTime}) : _now = startTime ?? DateTime(2024, 1, 1);

  DateTime _now;

  @override
  DateTime now() => _now;

  /// Advances time by the given [duration].
  void advance(Duration duration) {
    _now = _now.add(duration);
  }

  /// Sets the clock to an absolute time.
  void setTime(DateTime time) {
    _now = time;
  }
}
