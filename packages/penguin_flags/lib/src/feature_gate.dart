import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'license_tier.dart';
import 'providers.dart';

/// Shows [child] when [flag] is enabled and (if given) [tier] is
/// satisfied; otherwise shows [fallback] (or nothing). Watches
/// `flagChangesProvider` so a [FeatureFlags.refresh] that changes the
/// underlying flag/tier rebuilds this widget automatically.
class FeatureGate extends ConsumerWidget {
  /// Creates a feature gate widget.
  const FeatureGate({
    required this.flag,
    required this.child,
    this.fallback,
    this.tier,
    super.key,
  });

  /// The feature flag key to check (must be `${productKey}.<feature>`).
  final String flag;

  /// Widget to show when the flag is enabled and tier is satisfied.
  final Widget child;

  /// Widget to show when the flag is disabled or tier is not satisfied.
  /// If null, shows an empty [SizedBox].
  final Widget? fallback;

  /// Required license tier. If null, no tier check is performed.
  final LicenseTier? tier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureFlagsProvider);
    // Subscribing via watch (not listen) makes this widget rebuild whenever
    // FeatureFlags.changes emits — a listen-only callback does not trigger
    // a rebuild on its own.
    ref.watch(flagChangesProvider);

    final enabled = flags.isEnabled(flag);
    final tierSatisfied = tier == null || flags.hasTier(tier!);

    if (enabled && tierSatisfied) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}
