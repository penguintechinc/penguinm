import 'package:penguin_core/penguin_core.dart';

/// Source of raw feature-flag values for a distinct user/installation.
/// Implemented by [PostHogFlagSource] in production and by a local test
/// fake in package tests — [FeatureFlags] depends only on this interface.
abstract interface class FlagSource {
  /// Fetches flags for [distinctId], optionally scoped by [properties]
  /// (person properties forwarded to the flag evaluator for targeting).
  ///
  /// Returns a map of flag key to value: `true`/`false` for boolean flags,
  /// or a non-empty variant string for multivariate flags.
  Future<Result<Map<String, Object?>>> fetch({
    required String distinctId,
    Map<String, String> properties = const {},
  });
}
