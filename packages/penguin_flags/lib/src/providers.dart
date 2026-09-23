import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'feature_flags.dart';

/// Provider for the app's single configured [FeatureFlags] instance. Every
/// app shell must override this with the real instance at startup; the
/// default throws so a missing override fails loudly instead of silently
/// gating every feature off.
final featureFlagsProvider = Provider<FeatureFlags>(
  (_) => throw UnimplementedError('featureFlagsProvider not configured'),
);

/// Provider family evaluating a single flag [key] against the app's
/// [featureFlagsProvider] instance; convenient for `ref.watch(flagProvider('x'))`
/// call sites that only need one flag's boolean value.
final flagProvider = Provider.family<bool, String>((ref, key) {
  return ref.watch(featureFlagsProvider).isEnabled(key);
});

/// Stream provider over [FeatureFlags.changes], added beyond spec §4.6 so
/// [FeatureGate] (and any other widget) can `ref.watch` it to rebuild
/// whenever a [FeatureFlags.refresh] changes flags or tier — `ref.listen`
/// alone does not trigger a widget rebuild.
final flagChangesProvider = StreamProvider<void>((ref) {
  final flags = ref.watch(featureFlagsProvider);
  return flags.changes;
});
