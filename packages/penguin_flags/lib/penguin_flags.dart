/// FeatureFlags: PostHog flag source + license-server tier, cached for
/// offline use, plus the FeatureGate widget. Unseen flags default OFF.
library;

export 'src/config.dart';
export 'src/license_tier.dart';
export 'src/license_entitlement.dart';
export 'src/flag_source.dart';
export 'src/posthog_flag_source.dart';
export 'src/license_source.dart';
export 'src/penguin_license_source.dart';
export 'src/cached_flags.dart';
export 'src/flag_cache.dart';
export 'src/feature_flags.dart';
export 'src/feature_gate.dart';
export 'src/providers.dart';
