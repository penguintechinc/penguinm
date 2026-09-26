/// Short-edge output resolution for the encoded video stream, paired with
/// its pixel width/height at 16:9 and a compact UI label (e.g. "540p").
enum Resolution {
  p180(320, 180),
  p360(640, 360),
  p540(960, 540),
  p720(1280, 720),
  p1080(1920, 1080);

  const Resolution(this.width, this.height);

  /// Encoded frame width in pixels for this resolution tier.
  final int width;

  /// Encoded frame height in pixels for this resolution tier.
  final int height;

  /// Short label shown in the resolution picker, e.g. "540p".
  String get label => '${height}p';
}

/// Target encoder frame rate in frames per second.
enum FrameRate {
  fps15(15),
  fps30(30),
  fps50(50),
  fps60(60);

  const FrameRate(this.value);

  /// Frames per second value passed to the native encoder.
  final int value;
}

/// Minimum allowed video bitrate, in kbps, for the quality slider.
const int kMinBitrateKbps = 500;

/// Maximum allowed video bitrate, in kbps, for the quality slider.
const int kMaxBitrateKbps = 5000;

/// Step size, in kbps, between adjacent quality slider positions.
const int kBitrateStepKbps = 100;

/// Fixed AAC audio bitrate, in kbps, used for every stream in M1.
const int kAudioBitrateKbps = 128;

/// User-configurable video quality: resolution, frame rate, target bitrate
/// and whether the encoder is allowed to adapt bitrate down on congestion.
///
/// Hand-written immutable value class (no code generation): const
/// constructor, value equality, `copyWith`, and manual JSON codec.
class QualitySettings {
  /// Creates an immutable quality settings snapshot.
  const QualitySettings({
    required this.resolution,
    required this.frameRate,
    required this.videoBitrateKbps,
    required this.adaptiveBitrate,
  });

  /// Deserializes a [QualitySettings] from JSON (round-trip tests only;
  /// `SecureSettingsRepository` persists these as separate scalar keys).
  factory QualitySettings.fromJson(Map<String, dynamic> json) =>
      QualitySettings(
        resolution: Resolution.values.byName(json['resolution'] as String),
        frameRate: FrameRate.values.byName(json['frameRate'] as String),
        videoBitrateKbps: (json['videoBitrateKbps'] as num).toInt(),
        adaptiveBitrate: json['adaptiveBitrate'] as bool,
      );

  /// House default: 540p @ 30fps, 2000 kbps, adaptive bitrate on.
  factory QualitySettings.defaults() => const QualitySettings(
    resolution: Resolution.p540,
    frameRate: FrameRate.fps30,
    videoBitrateKbps: 2000,
    adaptiveBitrate: true,
  );

  /// Output resolution tier.
  final Resolution resolution;

  /// Target encoder frame rate.
  final FrameRate frameRate;

  /// Target video bitrate, in kbps.
  final int videoBitrateKbps;

  /// Whether the encoder is allowed to adapt bitrate down on congestion.
  final bool adaptiveBitrate;

  /// Serializes this instance to JSON (round-trip tests only).
  Map<String, dynamic> toJson() => <String, dynamic>{
    'resolution': resolution.name,
    'frameRate': frameRate.name,
    'videoBitrateKbps': videoBitrateKbps,
    'adaptiveBitrate': adaptiveBitrate,
  };

  /// Returns a copy with the given fields replaced.
  QualitySettings copyWith({
    Resolution? resolution,
    FrameRate? frameRate,
    int? videoBitrateKbps,
    bool? adaptiveBitrate,
  }) => QualitySettings(
    resolution: resolution ?? this.resolution,
    frameRate: frameRate ?? this.frameRate,
    videoBitrateKbps: videoBitrateKbps ?? this.videoBitrateKbps,
    adaptiveBitrate: adaptiveBitrate ?? this.adaptiveBitrate,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QualitySettings &&
          other.resolution == resolution &&
          other.frameRate == frameRate &&
          other.videoBitrateKbps == videoBitrateKbps &&
          other.adaptiveBitrate == adaptiveBitrate);

  @override
  int get hashCode =>
      Object.hash(resolution, frameRate, videoBitrateKbps, adaptiveBitrate);

  @override
  String toString() =>
      'QualitySettings(resolution: $resolution, frameRate: $frameRate, '
      'videoBitrateKbps: $videoBitrateKbps, adaptiveBitrate: $adaptiveBitrate)';
}
