<!--
Keep this terse — a reviewer should understand the change and its test
evidence in under 30 seconds. Delete any section that doesn't apply.
-->

## Summary

<!-- What changed and why, 1-3 bullets. Link the plan task / issue. -->

-

## Test plan

<!-- Paste the pre-PR sequence output (denominators, not just "passed"). -->

- [ ] `make seed-mock-data`
- [ ] `make smoke-test`
- [ ] `make test-unit`
- [ ] `make coverage` (>= 90% per package, LH/LF reported)
- [ ] `make test-integration` (if `integration_test/` touched)
- [ ] `make test-security` (gitleaks, trivy, osv-scanner, semgrep, zizmor, hadolint — 0 findings)
- [ ] `tooling/scripts/check-pins.sh` — 0 unpinned refs
- [ ] `tooling/scripts/check-logging.sh` — 0 hand-rolled logging calls
- [ ] `tooling/scripts/telemetry-validate.sh` — logs/metrics/histograms/spans all >= 1

## Screenshots

<!-- Required for any UI-affecting change. Attach before/after. -->

## Checklist

- [ ] No secrets, tokens, or hardcoded credentials introduced
- [ ] No new dependency outside Appendix A / `pubspec.yaml` pins (exact versions only)
- [ ] Feature behind a PostHog flag, defaulted OFF, if applicable
- [ ] `flutter analyze --fatal-infos` clean; `dart format --set-exit-if-changed .` clean
- [ ] Docs updated if conventions or workflows changed
