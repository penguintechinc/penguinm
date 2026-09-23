/// License tier ordering used for feature entitlement checks across every
/// penguinm client. Declaration order is significant: [satisfies] compares
/// enum index, so tiers must stay declared free < professional < enterprise.
enum LicenseTier {
  /// Free tier — core product only, no license-gated functionality.
  free,

  /// Professional tier — adds whitelabelling and Google OAuth2 SSO.
  professional,

  /// Enterprise tier — adds SAML/OIDC SSO, audit & compliance, WaddleAI,
  /// and advanced analytics.
  enterprise;

  /// True when this tier includes everything [required] grants — tiers are
  /// cumulative, so professional satisfies a free requirement and
  /// enterprise satisfies everything.
  bool satisfies(LicenseTier required) {
    return index >= required.index;
  }
}
