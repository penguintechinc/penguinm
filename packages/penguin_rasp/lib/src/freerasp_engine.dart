import 'dart:async';

import 'package:freerasp/freerasp.dart' as freerasp;
import 'package:penguin_core/penguin_core.dart';

import 'threat_mapping.dart';

/// Builds freerasp's `TalsecConfig` from [config]. `androidConfig` is
/// populated only when [RaspConfig.packageName] is set (non-empty);
/// `iosConfig` only when [RaspConfig.bundleIds] is non-empty — a caller
/// targeting a single platform simply leaves the other side's fields at
/// their [RaspConfig] defaults.
///
/// Pure config-building — no platform channel involved — kept as a
/// top-level function (rather than inline in [FreeraspEngine.start]) so it
/// is directly unit-testable without native code, per the design spec's
/// direction to keep all non-trivial logic in tested, pure helpers.
///
/// KNOWN GAP: freerasp requires a `watcherMail` (security-report contact)
/// and, for iOS, a `teamId` — neither is yet plumbed through [RaspConfig]
/// (v1 scope is Android-first per `client-flutter.md`). Both are left
/// blank here; freerasp's own native-side validation (not exercised by
/// this repo's host-platform tests) governs whether that is accepted
/// on-device. A blank `teamId` fails freerasp's iOS config check closed —
/// caught by `RaspGuard.start()`'s fail-soft try/catch, never a crash —
/// until a follow-up task extends [RaspConfig].
freerasp.TalsecConfig buildTalsecConfig(RaspConfig config) {
  final packageName = config.packageName;
  return freerasp.TalsecConfig(
    watcherMail: '',
    isProd: config.isProd,
    androidConfig: (packageName == null || packageName.isEmpty)
        ? null
        : freerasp.AndroidConfig(
            packageName: packageName,
            signingCertHashes: config.signingCertHashes,
          ),
    iosConfig: config.bundleIds.isEmpty
        ? null
        : freerasp.IOSConfig(bundleIds: config.bundleIds, teamId: ''),
  );
}

/// [RaspEngine] adapter over the freerasp (Talsec) SDK. Starts freeRASP
/// with the [freerasp.TalsecConfig] built by [buildTalsecConfig], and
/// republishes every detection on this engine's own broadcast [threats]
/// stream, each mapped via the pure [mapFreeraspThreat] (malware
/// detections — a distinct freerasp callback with no [freerasp.Threat]
/// value of their own — map straight to [RaspThreatType.other]).
///
/// All branching/category logic lives in [buildTalsecConfig] and
/// [mapFreeraspThreat]; this class is deliberately just platform-channel
/// plumbing, so most of its body is exempt from Dart unit coverage (native
/// glue, exercised by the Android CI build instead — see the design
/// spec's Testing section). [RaspGuard] (not this class) owns telemetry:
/// any error here is forwarded onto [threats] as a stream error for
/// `RaspGuard` to record as a `rasp.failure`, never swallowed here.
class FreeraspEngine implements RaspEngine {
  /// Creates the adapter. Construction never touches the platform channel
  /// (that happens in [start]), so it never throws.
  FreeraspEngine();

  final StreamController<RaspThreat> _controller =
      StreamController<RaspThreat>.broadcast();

  StreamSubscription<freerasp.Threat>? _threatSubscription;
  bool _listenerAttached = false;

  @override
  Future<void> start(RaspConfig config) async {
    await freerasp.Talsec.instance.start(buildTalsecConfig(config));

    _threatSubscription = freerasp.Talsec.instance.onThreatDetected.listen(
      (threat) => _emit(mapFreeraspThreat(threat)),
      onError: _forwardError,
    );

    // Malware detection is delivered only via the pigeon-based
    // ThreatCallback (not the `onThreatDetected` event stream above), so a
    // second, malware-only listener is attached alongside the stream
    // subscription — every other callback field is left null.
    await freerasp.Talsec.instance.attachListener(
      freerasp.ThreatCallback(onMalware: (_) => _emit(RaspThreatType.other)),
    );
    _listenerAttached = true;
  }

  @override
  Stream<RaspThreat> get threats => _controller.stream;

  @override
  Future<void> stop() async {
    await _threatSubscription?.cancel();
    _threatSubscription = null;
    if (_listenerAttached) {
      await freerasp.Talsec.instance.detachListener();
      _listenerAttached = false;
    }
    if (!_controller.isClosed) await _controller.close();
  }

  void _emit(RaspThreatType type) {
    if (!_controller.isClosed) {
      _controller.add(RaspThreat(type, DateTime.now()));
    }
  }

  void _forwardError(Object error, StackTrace stackTrace) {
    if (!_controller.isClosed) _controller.addError(error, stackTrace);
  }
}
