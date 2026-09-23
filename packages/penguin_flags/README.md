# penguin_flags

`FeatureFlags`: `PostHogFlagSource` + `PenguinLicenseSource` (license tier),
`FlagCache` (offline-safe), `FeatureGate` widget. Bypass is domain-based only
(`AppConfig.isLicenseBypassDomain`); unreachable → cached value, never a
crash. See spec §4.6, `critical-rules.md` Feature Flags & License Tiers.

## License server endpoints used

- `POST <posthogHost>/decide?v=3` — PostHog flag evaluation (`PostHogFlagSource`).
  Body: `{api_key, distinct_id, person_properties}`; reads the response's
  `featureFlags` map.
- `POST <licenseServerUrl>/api/v2/validate` — license tier validation
  (`PenguinLicenseSource`). Body: `{productKey, licenseKey?, installationId}`;
  reads `tier`, `expiresAt`, `features` from the response. See the
  `integrating-license-server` skill for the full endpoint reference.

## Additions beyond spec §4.6

- `flagChangesProvider` (`lib/src/providers.dart`) — a `StreamProvider<void>`
  over `FeatureFlags.changes`, not shown in the spec's class snippet.
  `FeatureGate` needs a Riverpod provider to `ref.watch` (rather than
  `ref.listen`, which does not trigger a widget rebuild) so it reacts to
  `FeatureFlags.refresh()` changing flags or tier.
