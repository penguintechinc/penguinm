import 'quality.dart';
import 'stream_target_settings.dart';

/// User's chosen audio source for the stream.
///
/// `auto` resolves at Go Live time (M1: always mic, since M1 has no UVC/USB
/// audio path); `usbAudio` is reserved for M2 and falls back to mic in M1.
enum AudioSourceChoice { auto, mic, usbAudio, silence }

/// The complete set of user-configurable Gazer settings: target, quality,
/// audio source and the hidden developer "force libuvc" toggle.
///
/// This is the aggregate root `SettingsRepository` loads/saves; persistence
/// itself is split across secure storage (target) and shared_preferences
/// (everything else) — see `SecureSettingsRepository`.
///
/// Hand-written immutable value class (no code generation): const
/// constructor, value equality, `copyWith`, and manual JSON codec. [target] and [quality] are themselves value classes,
/// so [toJson] calls their own `toJson()` explicitly (the freezed
/// equivalent of `explicit_to_json: true`) rather than embedding the raw
/// nested object.
class GazerSettings {
  /// Creates an immutable settings snapshot.
  const GazerSettings({
    required this.target,
    required this.quality,
    required this.audio,
    required this.forceLibuvc,
    required this.debugLogs,
  });

  /// Deserializes a [GazerSettings] from JSON (round-trip tests only —
  /// [SecureSettingsRepository] persists fields individually, not as one blob).
  factory GazerSettings.fromJson(Map<String, dynamic> json) => GazerSettings(
    target: StreamTargetSettings.fromJson(
      json['target'] as Map<String, dynamic>,
    ),
    quality: QualitySettings.fromJson(json['quality'] as Map<String, dynamic>),
    audio: AudioSourceChoice.values.byName(json['audio'] as String),
    forceLibuvc: json['forceLibuvc'] as bool,
    debugLogs: json['debugLogs'] as bool,
  );

  /// First-launch defaults: empty target, default quality, auto audio,
  /// developer toggles (force libuvc, debug logs) off.
  factory GazerSettings.defaults() => GazerSettings(
    target: StreamTargetSettings.empty(),
    quality: QualitySettings.defaults(),
    audio: AudioSourceChoice.auto,
    forceLibuvc: false,
    debugLogs: false,
  );

  /// The configured RTMP/RTMPS destination.
  final StreamTargetSettings target;

  /// The configured video/audio quality.
  final QualitySettings quality;

  /// The user's chosen audio source.
  final AudioSourceChoice audio;

  /// Hidden developer toggle: force the libuvc UVC backend.
  final bool forceLibuvc;

  /// Whether verbose debug logs are enabled.
  final bool debugLogs;

  /// Serializes this instance to JSON, calling [target]/[quality]'s own
  /// `toJson()` rather than embedding them raw.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'target': target.toJson(),
    'quality': quality.toJson(),
    'audio': audio.name,
    'forceLibuvc': forceLibuvc,
    'debugLogs': debugLogs,
  };

  /// Returns a copy with the given fields replaced.
  GazerSettings copyWith({
    StreamTargetSettings? target,
    QualitySettings? quality,
    AudioSourceChoice? audio,
    bool? forceLibuvc,
    bool? debugLogs,
  }) => GazerSettings(
    target: target ?? this.target,
    quality: quality ?? this.quality,
    audio: audio ?? this.audio,
    forceLibuvc: forceLibuvc ?? this.forceLibuvc,
    debugLogs: debugLogs ?? this.debugLogs,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GazerSettings &&
          other.target == target &&
          other.quality == quality &&
          other.audio == audio &&
          other.forceLibuvc == forceLibuvc &&
          other.debugLogs == debugLogs);

  @override
  int get hashCode =>
      Object.hash(target, quality, audio, forceLibuvc, debugLogs);

  @override
  String toString() =>
      'GazerSettings(target: $target, quality: $quality, audio: $audio, '
      'forceLibuvc: $forceLibuvc, debugLogs: $debugLogs)';
}
