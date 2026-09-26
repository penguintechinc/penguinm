# penguin_update

`UpdateChecker` (compares `ClientVersionInfo` via `pub_semver`, 5s timeout,
never throws) and `UpdatePrompt` (`url_launcher` to the store or
`market://details`). See spec §4.8.
