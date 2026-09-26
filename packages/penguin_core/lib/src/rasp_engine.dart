/// Runtime application self-protection engine: detects device/app integrity
/// threats and surfaces them as a stream. A no-op default keeps RASP optional.
abstract interface class RaspEngine {
  /// Begin detection. Idempotent; safe to call once at bootstrap.
  Future<void> start(RaspConfig config);

  /// Threats as they are detected. Never emits PII.
  Stream<RaspThreat> get threats;

  /// Stop detection and release resources.
  Future<void> stop();
}

/// A detected runtime threat, category + timestamp only (no device
/// fingerprint/PII).
final class RaspThreat {
  /// Creates a threat record for [type] detected at [detectedAt].
  const RaspThreat(this.type, this.detectedAt);

  /// The category of threat detected.
  final RaspThreatType type;

  /// When the threat was detected.
  final DateTime detectedAt;

  @override
  bool operator ==(Object other) =>
      other is RaspThreat &&
      other.type == type &&
      other.detectedAt == detectedAt;

  @override
  int get hashCode => Object.hash(type, detectedAt);
}

/// Threat categories penguin_rasp recognises (superset mapped from freerasp
/// and an OS-version check). [other] catches any freerasp threat not
/// individually modelled.
enum RaspThreatType {
  /// Device is rooted (Android) or jailbroken (iOS).
  rootJailbreak,

  /// A hooking/instrumentation framework (e.g. Frida, Xposed) was detected.
  hooking,

  /// A debugger is attached to the running process.
  debugger,

  /// The app is running inside an emulator or simulator.
  emulator,

  /// The app binary or its resources have been tampered with.
  tampering,

  /// The app was installed from an untrusted source (not an official
  /// app store).
  untrustedInstallSource,

  /// The device's OS version is below the app's configured minimum.
  unsupportedOs,

  /// Device/app-instance integrity binding check failed.
  deviceBinding,

  /// Screen capture or screen recording was detected.
  screenCapture,

  /// Any other threat not individually modelled by this type.
  other,
}

/// What to do when a threat fires. [block] terminates only when enforcing.
enum RaspAction {
  /// Log/report the threat but do not terminate the app.
  alert,

  /// Terminate the app in response to the threat (only when enforcing).
  block,
}

/// Per-app RASP policy carried on `AppManifest`.
final class RaspPolicy {
  /// Creates a RASP policy; defaults to disabled with the standard
  /// block-by-default threat set and no OS-version gate.
  const RaspPolicy({
    this.enabled = false,
    this.blockThreats = defaultBlockThreats,
    this.minAndroidSdk,
    this.minIosVersion,
  });

  /// Whether RASP should be started at all for this app.
  final bool enabled;

  /// Threat types that should terminate the app (when enforcing); all
  /// other types only alert.
  final Set<RaspThreatType> blockThreats;

  /// Minimum supported Android SDK level; null disables the OS-version
  /// gate on Android.
  final int? minAndroidSdk;

  /// Minimum supported iOS version string; null disables the OS-version
  /// gate on iOS.
  final String? minIosVersion;

  /// User-chosen default block set (2026-09-26).
  static const Set<RaspThreatType> defaultBlockThreats = {
    RaspThreatType.hooking,
    RaspThreatType.tampering,
    RaspThreatType.debugger,
    RaspThreatType.rootJailbreak,
    RaspThreatType.unsupportedOs,
    RaspThreatType.emulator,
  };

  /// Resolves the action to take for a detected threat of type [t].
  RaspAction actionFor(RaspThreatType t) =>
      blockThreats.contains(t) ? RaspAction.block : RaspAction.alert;

  @override
  bool operator ==(Object other) =>
      other is RaspPolicy &&
      other.enabled == enabled &&
      other.minAndroidSdk == minAndroidSdk &&
      other.minIosVersion == minIosVersion &&
      other.blockThreats.length == blockThreats.length &&
      other.blockThreats.containsAll(blockThreats);

  @override
  int get hashCode => Object.hash(
    enabled,
    minAndroidSdk,
    minIosVersion,
    Object.hashAllUnordered(blockThreats),
  );
}

/// Immutable config handed to the engine at start (from [RaspPolicy] + app
/// identity). Carries no PII — only static app/build identity used for
/// integrity checks.
final class RaspConfig {
  /// Creates an engine config; every field is optional so `const
  /// RaspConfig()` is valid for tests and the no-op engine.
  const RaspConfig({
    this.packageName,
    this.signingCertHashes = const [],
    this.bundleIds = const [],
    this.isProd = false,
    this.minAndroidSdk,
    this.minIosVersion,
  });

  /// Android application id / package name the engine should expect.
  final String? packageName;

  /// Expected Android APK signing certificate hashes.
  final List<String> signingCertHashes;

  /// Expected iOS bundle identifiers.
  final List<String> bundleIds;

  /// Whether this is a production build.
  final bool isProd;

  /// Minimum supported Android SDK level; null disables the OS-version
  /// gate on Android.
  final int? minAndroidSdk;

  /// Minimum supported iOS version string; null disables the OS-version
  /// gate on iOS.
  final String? minIosVersion;
}

/// Safe default [RaspEngine]: detects nothing, never emits, and every call
/// completes trivially. Used until a real engine (e.g. `FreeraspEngine`
/// from `penguin_rasp`) is wired in by the shell.
final class NoopRaspEngine implements RaspEngine {
  /// Creates a no-op RASP engine.
  const NoopRaspEngine();

  @override
  Future<void> start(RaspConfig config) async {}

  @override
  Stream<RaspThreat> get threats => const Stream<RaspThreat>.empty();

  @override
  Future<void> stop() async {}
}
