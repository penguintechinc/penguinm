import 'package:flutter_test/flutter_test.dart';
import 'package:freerasp/freerasp.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_rasp/penguin_rasp.dart';

void main() {
  group('mapFreeraspThreat', () {
    const table = <Threat, RaspThreatType>{
      Threat.privilegedAccess: RaspThreatType.rootJailbreak,
      Threat.hooks: RaspThreatType.hooking,
      Threat.debug: RaspThreatType.debugger,
      Threat.simulator: RaspThreatType.emulator,
      Threat.appIntegrity: RaspThreatType.tampering,
      Threat.unofficialStore: RaspThreatType.untrustedInstallSource,
      Threat.deviceBinding: RaspThreatType.deviceBinding,
      Threat.screenshot: RaspThreatType.screenCapture,
      Threat.screenRecording: RaspThreatType.screenCapture,
      // Everything else freerasp exposes falls back to `other`.
      Threat.deviceId: RaspThreatType.other,
      Threat.passcode: RaspThreatType.other,
      Threat.obfuscationIssues: RaspThreatType.other,
      Threat.secureHardwareNotAvailable: RaspThreatType.other,
      Threat.systemVPN: RaspThreatType.other,
      Threat.devMode: RaspThreatType.other,
      Threat.adbEnabled: RaspThreatType.other,
      Threat.multiInstance: RaspThreatType.other,
      Threat.unsecureWiFi: RaspThreatType.other,
      Threat.timeSpoofing: RaspThreatType.other,
      Threat.locationSpoofing: RaspThreatType.other,
      Threat.automation: RaspThreatType.other,
      Threat.bootloader: RaspThreatType.other,
    };

    for (final entry in table.entries) {
      test('${entry.key} -> ${entry.value}', () {
        expect(mapFreeraspThreat(entry.key), entry.value);
      });
    }

    test('covers every value of the freerasp Threat enum', () {
      expect(table.keys.toSet(), Threat.values.toSet());
    });
  });
}
