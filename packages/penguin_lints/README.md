# penguin_lints

Shared `analysis_options.yaml` for every `penguinm` workspace member.

Every package/app/shell includes it via:

```yaml
include: package:penguin_lints/analysis_options.yaml
```

Built on `package:flutter_lints/flutter.yaml` plus `strict-casts`,
`strict-inference`, `strict-raw-types`, and the house rule set
(`public_member_api_docs`, `avoid_print`, `unawaited_futures`,
`require_trailing_commas`, `avoid_dynamic_calls`). `avoid_print` is
disabled only in `tooling/otlp_sink`, where CLI stdout is legitimate.
