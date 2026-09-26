import 'package:freerasp/freerasp.dart';
import 'package:penguin_core/penguin_core.dart';

/// Maps a freerasp (Talsec) [Threat] identifier to the engine-agnostic
/// [RaspThreatType] the rest of this workspace reasons about
/// (`RaspGuard`, `RaspPolicy.actionFor`, `AppManifest.raspPolicy`). Pure and
/// exhaustive over every [Threat] value freerasp 8.2.2 exposes, so it is
/// unit-testable without any native platform channel.
///
/// `Threat.appIntegrity` is freerasp's tamper-detection signal (invalid
/// signature/package name/signing hash) — mapped to [RaspThreatType.tampering]
/// per the design spec, not a separate "integrity" category.
///
/// Malware detection is intentionally NOT handled here: freerasp delivers it
/// via a distinct `ThreatCallback.onMalware(List<SuspiciousAppInfo>)`
/// pigeon callback carrying a payload, not a [Threat] enum value — see
/// `FreeraspEngine`, which maps that callback straight to
/// [RaspThreatType.other].
RaspThreatType mapFreeraspThreat(Threat threat) {
  switch (threat) {
    case Threat.privilegedAccess:
      return RaspThreatType.rootJailbreak;
    case Threat.hooks:
      return RaspThreatType.hooking;
    case Threat.debug:
      return RaspThreatType.debugger;
    case Threat.simulator:
      return RaspThreatType.emulator;
    case Threat.appIntegrity:
      return RaspThreatType.tampering;
    case Threat.unofficialStore:
      return RaspThreatType.untrustedInstallSource;
    case Threat.deviceBinding:
      return RaspThreatType.deviceBinding;
    case Threat.screenshot:
    case Threat.screenRecording:
      return RaspThreatType.screenCapture;
    case Threat.deviceId:
    case Threat.passcode:
    case Threat.obfuscationIssues:
    case Threat.secureHardwareNotAvailable:
    case Threat.systemVPN:
    case Threat.devMode:
    case Threat.adbEnabled:
    case Threat.multiInstance:
    case Threat.unsecureWiFi:
    case Threat.timeSpoofing:
    case Threat.locationSpoofing:
    case Threat.automation:
    case Threat.bootloader:
      return RaspThreatType.other;
  }
}
