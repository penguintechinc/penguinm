# penguin_app_shell

`FeatureModule`, `AppManifest`, `runPenguinApp`, `PenguinApp`, `Bootstrap`.
Wires every shared package together for an app: no bootstrap step may throw
out of `runPenguinApp` — each records a `BootstrapWarning` and the app
continues. See spec §4.10.
