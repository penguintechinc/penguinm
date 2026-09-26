import 'dart:async';

import 'package:penguin_core/penguin_core.dart';

/// Scripted [RaspEngine] fake: [emit] pushes threats to [threats] on demand,
/// [start]/[stop] record calls so tests can assert lifecycle without a real
/// device-integrity backend, and [throwOnStart]/[emitError] exercise the
/// fail-soft paths in RASP consumers (`RaspGuard`, Bootstrap).
class FakeRaspEngine implements RaspEngine {
  /// Creates a fake RASP engine; [throwOnStart] defaults to false so [start]
  /// succeeds unless a test opts into simulating an init failure.
  FakeRaspEngine({this.throwOnStart = false});

  final StreamController<RaspThreat> _controller =
      StreamController<RaspThreat>.broadcast();

  /// Whether [start] should throw instead of completing normally, to
  /// exercise fail-soft handling in consumers.
  bool throwOnStart;

  /// Whether [start] has been called.
  bool started = false;

  /// Whether [stop] has been called.
  bool stopped = false;

  /// The [RaspConfig] passed to the most recent [start] call, if any.
  RaspConfig? startedWith;

  @override
  Future<void> start(RaspConfig config) async {
    started = true;
    startedWith = config;
    if (throwOnStart) {
      throw StateError('FakeRaspEngine.start configured to throw');
    }
  }

  @override
  Stream<RaspThreat> get threats => _controller.stream;

  @override
  Future<void> stop() async {
    stopped = true;
    if (!_controller.isClosed) await _controller.close();
  }

  /// Pushes a [RaspThreat] of [type] (detected at [at], default now) to
  /// [threats] listeners — the primary test hook for simulating detections.
  void emit(RaspThreatType type, {DateTime? at}) {
    if (!_controller.isClosed) {
      _controller.add(RaspThreat(type, at ?? DateTime.now()));
    }
  }

  /// Adds [error] to [threats] as a stream error, for tests exercising
  /// fail-soft handling of engine telemetry failures.
  void emitError(Object error) {
    if (!_controller.isClosed) _controller.addError(error);
  }
}
