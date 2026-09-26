import 'dart:async';

/// A [Timer] that never really fires — [FakeTimerFactory] hands these back
/// so [AuthController] can `cancel()`/check `isActive` without a real
/// event-loop timer ever being scheduled.
class FakeTimer implements Timer {
  bool _active = true;

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

/// One call captured by [FakeTimerFactory]: the requested [duration], the
/// [callback] to invoke, and the [timer] handed back to the caller.
class ScheduledCall {
  /// Creates a captured scheduling call.
  ScheduledCall(this.duration, this.callback, this.timer);

  /// The delay the caller requested.
  final Duration duration;

  /// The callback the caller wants invoked when the delay elapses.
  final void Function() callback;

  /// The [FakeTimer] returned to the caller for this call.
  final FakeTimer timer;
}

/// Deterministic stand-in for a `TimerFactory` — records every scheduling
/// call instead of starting a real [Timer], so tests can advance a
/// [FakeClock] and fire the captured callback manually with no real
/// waiting.
class FakeTimerFactory {
  /// Every scheduling call made so far, oldest first.
  final List<ScheduledCall> calls = [];

  /// The `TimerFactory`-shaped callable passed to `timerFactoryProvider`.
  Timer call(Duration duration, void Function() callback) {
    final timer = FakeTimer();
    calls.add(ScheduledCall(duration, callback, timer));
    return timer;
  }

  /// The most recently scheduled call, or null if none were made.
  ScheduledCall? get last => calls.isEmpty ? null : calls.last;

  /// Invokes the most recently scheduled still-active callback, as if its
  /// delay had elapsed — matching a real one-shot [Timer], whose
  /// `isActive` turns false once it fires.
  Future<void> fireLast() async {
    final call = last;
    if (call == null || !call.timer.isActive) return;
    call.timer._active = false;
    call.callback();
  }
}
