import 'dart:async';

import 'package:penguin_core/penguin_core.dart';

import 'os_check.dart';
import 'rasp_metrics.dart';

/// Runtime guard that starts a [RaspEngine], turns every detected threat
/// (and every engine/stream failure) into an OTel metric + sanitized log,
/// and terminates the app via [onBlock] when a blocking threat fires while
/// [enforce] is true. Fail-soft throughout: nothing thrown by the engine
/// or its stream ever escapes [start] or [stop].
class RaspGuard {
  /// Creates a guard wiring [engine] to [metrics]/[logger] under [policy].
  /// [config] is passed to [RaspEngine.start]. [enforce] gates whether a
  /// block-type threat invokes [onBlock] (null ⇒ no-op, so this class is
  /// fully testable without terminating anything). [currentAndroidSdk] and
  /// [currentIosVersion] are the caller-injected detected Android SDK
  /// level / iOS system version for the supplementary OS-version gate on
  /// each platform; null skips the corresponding check (device_info
  /// wiring is injected by the caller — see `bootstrap.dart`).
  RaspGuard({
    required this.engine,
    required this.config,
    required this.metrics,
    required this.logger,
    required this.policy,
    required this.enforce,
    this.onBlock,
    this.currentAndroidSdk,
    this.currentIosVersion,
  });

  /// The underlying detection engine.
  final RaspEngine engine;

  /// Config handed to [RaspEngine.start].
  final RaspConfig config;

  /// Where per-threat and per-failure metrics are emitted.
  final MetricsSink metrics;

  /// Where per-threat and per-failure sanitized logs are emitted.
  final PenguinLogger logger;

  /// Resolves the action (alert/block) for each detected threat type.
  final RaspPolicy policy;

  /// Whether a block-type threat should actually terminate (via [onBlock])
  /// rather than only alert/log.
  final bool enforce;

  /// Invoked when a block-type threat fires while enforcing; left null the
  /// guard only alerts/logs and never terminates.
  final void Function()? onBlock;

  /// Detected Android SDK level, injected by the caller; null disables the
  /// Android OS-version gate.
  final int? currentAndroidSdk;

  /// Detected iOS system version (e.g. `'17.4'`), injected by the caller;
  /// null disables the iOS OS-version gate.
  final String? currentIosVersion;

  StreamSubscription<RaspThreat>? _subscription;

  /// Starts [engine], subscribes to its threat stream, and runs the
  /// supplementary Android/iOS OS-version gates. Never throws: any
  /// failure is recorded as a [RaspMetrics.failure] metric + error log
  /// and swallowed; on failure, a partially-started [engine] is
  /// best-effort stopped so it is never left running with no downstream
  /// listener.
  Future<void> start() async {
    try {
      await engine.start(config);
      _subscription = engine.threats.listen(
        _handleThreat,
        onError: _handleStreamError,
      );

      final minSdk = policy.minAndroidSdk;
      final sdk = currentAndroidSdk;
      if (minSdk != null && sdk != null && sdk < minSdk) {
        _handleThreat(RaspThreat(RaspThreatType.unsupportedOs, DateTime.now()));
      }

      final minIos = policy.minIosVersion;
      final iosVersion = currentIosVersion;
      if (minIos != null &&
          iosVersion != null &&
          isIosVersionBelow(iosVersion, minIos)) {
        _handleThreat(RaspThreat(RaspThreatType.unsupportedOs, DateTime.now()));
      }
    } catch (e, st) {
      metrics.counter(RaspMetrics.failure, 1, attributes: {'phase': 'start'});
      logger.error('RASP engine failed to start', error: e, stackTrace: st);
      try {
        await engine.stop();
      } catch (_) {
        // Best-effort teardown of a partially-started engine; never
        // rethrow — this is already inside the fail-soft catch.
      }
    }
  }

  /// Cancels the threat subscription and stops [engine]. Never throws: any
  /// failure is recorded as a [RaspMetrics.failure] metric + error log and
  /// swallowed.
  Future<void> stop() async {
    try {
      await _subscription?.cancel();
      _subscription = null;
      await engine.stop();
    } catch (e, st) {
      metrics.counter(RaspMetrics.failure, 1, attributes: {'phase': 'stop'});
      logger.error('RASP engine failed to stop', error: e, stackTrace: st);
    }
  }

  void _handleThreat(RaspThreat threat) {
    final action = policy.actionFor(threat.type);
    metrics.counter(
      RaspMetrics.threat,
      1,
      attributes: {
        'threat': threat.type.name,
        'action': action.name,
        'enforced': enforce,
      },
    );
    logger.warn(
      'RASP threat detected',
      attributes: {'threat': threat.type.name, 'action': action.name},
    );
    if (action == RaspAction.block && enforce) {
      onBlock?.call();
    }
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    metrics.counter(RaspMetrics.failure, 1, attributes: {'phase': 'stream'});
    logger.error(
      'RASP threat stream error',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
