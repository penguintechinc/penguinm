import 'package:flutter_riverpod/misc.dart' show Override;

/// One bootstrap step that failed but was recovered from — the app keeps
/// starting with a safe fallback (e.g. a `NoopExporter`); recorded here so
/// it can be surfaced in diagnostics/telemetry instead of vanishing
/// silently.
class BootstrapWarning {
  /// Creates a warning for the named bootstrap [step] and the [error] it
  /// recovered from.
  const BootstrapWarning(this.step, this.error);

  /// Short machine-readable step name, e.g. `'telemetry'`, `'flags'`,
  /// `'auth'`.
  final String step;

  /// The error that was caught and recovered from.
  final Object error;

  @override
  String toString() => 'BootstrapWarning($step: $error)';
}

/// Outcome of [Bootstrap.run]: the Riverpod overrides to mount the app
/// with, how long bootstrap took, and any recovered failures.
class BootstrapResult {
  /// Creates a bootstrap result.
  const BootstrapResult({
    required this.overrides,
    required this.startupDuration,
    required this.warnings,
  });

  /// Overrides for every provider Bootstrap resolved — merge into the
  /// `ProviderScope` that hosts the app.
  final List<Override> overrides;

  /// Wall-clock time [Bootstrap.run] took to complete.
  final Duration startupDuration;

  /// Every step that failed and fell back to a safe default; empty on a
  /// fully healthy bootstrap.
  final List<BootstrapWarning> warnings;
}
