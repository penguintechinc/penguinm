# penguin_testing

Fakes for every shared-package interface (`FakeClock`, `FakeTokenProvider`,
`FakeAuthBackend`, `FakeFlagSource`, `FakeLicenseSource`,
`InMemoryTelemetryExporter`, `FakeConnectivityMonitor`,
`InMemoryOfflineStore`, `FakeUpdateChecker`), `penguinGolden`,
`OtlpSinkClient`, and shared `fixtures/`. A regular (non-dev) dependency
here — not a dev one — because its `lib/` code exposes `flutter_test`
types to consumers; every *consumer* of this package still takes it as a
`dev_dependency`. See spec §4.11.

This package deliberately does **not** depend on the shell — `pumpPenguinApp`
lives in `package:penguin_app_shell/testing.dart` instead.
