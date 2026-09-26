import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// True when [current] (a dotted version string, e.g. `'14.2'`) is strictly
/// below [minimum]. Compares segment-by-segment as integers; a shorter
/// operand is padded with `0` for any missing trailing segment (so `'14'`
/// is treated as `'14.0'` against `'14.2'`). Malformed input (empty string,
/// a non-numeric segment) returns `false` rather than throwing — callers
/// treat "can't tell" as "don't block", matching this package's fail-soft
/// posture.
bool isIosVersionBelow(String current, String minimum) {
  final currentParts = _parseVersion(current);
  final minimumParts = _parseVersion(minimum);
  if (currentParts == null || minimumParts == null) return false;

  final length = currentParts.length > minimumParts.length
      ? currentParts.length
      : minimumParts.length;
  for (var i = 0; i < length; i++) {
    final currentSegment = i < currentParts.length ? currentParts[i] : 0;
    final minimumSegment = i < minimumParts.length ? minimumParts[i] : 0;
    if (currentSegment != minimumSegment) {
      return currentSegment < minimumSegment;
    }
  }
  return false;
}

/// Parses a dotted version string into its integer segments; `null` on any
/// malformed input (empty string or a non-numeric segment) so callers can
/// fail soft instead of throwing.
List<int>? _parseVersion(String version) {
  if (version.isEmpty) return null;
  final parsed = <int>[];
  for (final segment in version.split('.')) {
    final value = int.tryParse(segment);
    if (value == null) return null;
    parsed.add(value);
  }
  return parsed;
}

/// Detected Android SDK level (`AndroidDeviceInfo.version.sdkInt`); `null`
/// off Android or if detection fails. Guarded by [defaultTargetPlatform]
/// (rather than `dart:io Platform`) so the guard itself is testable via
/// `debugDefaultTargetPlatformOverride` — thin platform glue over
/// `device_info_plus`, but the guard + error-handling branches ARE
/// unit-tested with an injected mock [plugin]; only a real device's
/// `androidInfo` response is out of reach of a host-machine test run. The
/// supplementary OS-version gate this feeds (`RaspGuard.start()`) is
/// exercised via its injected `currentAndroidSdk` parameter regardless.
Future<int?> detectAndroidSdk({DeviceInfoPlugin? plugin}) async {
  if (defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final info = await (plugin ?? DeviceInfoPlugin()).androidInfo;
    return info.version.sdkInt;
  } on Object {
    return null;
  }
}

/// Detected iOS system version (`IosDeviceInfo.systemVersion`, e.g.
/// `'17.4'`); `null` off iOS or if detection fails. Guarded by
/// [defaultTargetPlatform] (rather than `dart:io Platform`) so the guard
/// itself is testable via `debugDefaultTargetPlatformOverride` — thin
/// platform glue over `device_info_plus`, but the guard + error-handling
/// branches ARE unit-tested with an injected mock [plugin]; only a real
/// device/simulator's `iosInfo` response is out of reach of a host-machine
/// test run. Pair with [isIosVersionBelow] for the actual gate logic,
/// which is fully unit-tested.
Future<String?> detectIosVersion({DeviceInfoPlugin? plugin}) async {
  if (defaultTargetPlatform != TargetPlatform.iOS) return null;
  try {
    final info = await (plugin ?? DeviceInfoPlugin()).iosInfo;
    return info.systemVersion;
  } on Object {
    return null;
  }
}
