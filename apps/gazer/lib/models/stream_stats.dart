/// Dart-side aggregation of native 1Hz `StatsSample`s: rolling averages and
/// session totals shown in the status panel.
///
/// `PipelineController` owns the aggregation math (rolling average bitrate,
/// uptime clock, cumulative reconnect count); this class is the immutable
/// snapshot handed to the UI via `streamStatsProvider`. Not persisted, so
/// no JSON codec is needed.
///
/// Hand-written immutable value class (no code generation): const
/// constructor, value equality, and `copyWith`.
class StreamStats {
  /// Creates an immutable stream stats snapshot.
  const StreamStats({
    required this.currentBitrateKbps,
    required this.averageBitrateKbps,
    required this.fps,
    required this.droppedFrames,
    required this.sentBytes,
    required this.uptime,
    required this.reconnectCount,
    required this.congestionPercent,
  });

  /// The all-zero snapshot shown before streaming starts and after a full
  /// stop (session totals reset).
  factory StreamStats.zero() => const StreamStats(
    currentBitrateKbps: 0,
    averageBitrateKbps: 0,
    fps: 0,
    droppedFrames: 0,
    sentBytes: 0,
    uptime: Duration.zero,
    reconnectCount: 0,
    congestionPercent: 0,
  );

  /// Current instantaneous encoder bitrate, in kbps.
  final int currentBitrateKbps;

  /// Rolling average bitrate over the session, in kbps.
  final int averageBitrateKbps;

  /// Current encoder frames per second.
  final double fps;

  /// Cumulative frames dropped this session.
  final int droppedFrames;

  /// Cumulative bytes sent this session.
  final int sentBytes;

  /// Wall-clock time since the stream started.
  final Duration uptime;

  /// Cumulative reconnect attempts this session.
  final int reconnectCount;

  /// Current network congestion estimate, as a percentage (0-100).
  final double congestionPercent;

  /// Returns a copy with the given fields replaced.
  StreamStats copyWith({
    int? currentBitrateKbps,
    int? averageBitrateKbps,
    double? fps,
    int? droppedFrames,
    int? sentBytes,
    Duration? uptime,
    int? reconnectCount,
    double? congestionPercent,
  }) => StreamStats(
    currentBitrateKbps: currentBitrateKbps ?? this.currentBitrateKbps,
    averageBitrateKbps: averageBitrateKbps ?? this.averageBitrateKbps,
    fps: fps ?? this.fps,
    droppedFrames: droppedFrames ?? this.droppedFrames,
    sentBytes: sentBytes ?? this.sentBytes,
    uptime: uptime ?? this.uptime,
    reconnectCount: reconnectCount ?? this.reconnectCount,
    congestionPercent: congestionPercent ?? this.congestionPercent,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StreamStats &&
          other.currentBitrateKbps == currentBitrateKbps &&
          other.averageBitrateKbps == averageBitrateKbps &&
          other.fps == fps &&
          other.droppedFrames == droppedFrames &&
          other.sentBytes == sentBytes &&
          other.uptime == uptime &&
          other.reconnectCount == reconnectCount &&
          other.congestionPercent == congestionPercent);

  @override
  int get hashCode => Object.hash(
    currentBitrateKbps,
    averageBitrateKbps,
    fps,
    droppedFrames,
    sentBytes,
    uptime,
    reconnectCount,
    congestionPercent,
  );

  @override
  String toString() =>
      'StreamStats(currentBitrateKbps: $currentBitrateKbps, '
      'averageBitrateKbps: $averageBitrateKbps, fps: $fps, '
      'droppedFrames: $droppedFrames, sentBytes: $sentBytes, uptime: $uptime, '
      'reconnectCount: $reconnectCount, congestionPercent: $congestionPercent)';
}
