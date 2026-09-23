/// Fakes for every shared-package interface (FakeClock, FakeAuthBackend, …),
/// the golden-image helper, the OtlpSinkClient test client, and shared
/// fixtures. `pumpPenguinApp` lives in `shells/penguin_app_shell`'s own
/// `lib/testing.dart` (T24) — this package deliberately has no dependency
/// on the shell.
library;

export 'src/fake_auth_backend.dart';
export 'src/fake_clock.dart';
export 'src/fake_connectivity_monitor.dart';
export 'src/fake_flag_source.dart';
export 'src/fake_license_source.dart';
export 'src/fake_token_provider.dart';
export 'src/fake_update_checker.dart';
export 'src/fixtures/chat_messages.dart';
export 'src/fixtures/client_versions.dart';
export 'src/fixtures/communities.dart';
export 'src/fixtures/members.dart';
export 'src/fixtures/springboard_items.dart';
export 'src/fixtures/users.dart';
export 'src/golden.dart';
export 'src/in_memory_flag_cache.dart';
export 'src/in_memory_offline_store.dart';
export 'src/in_memory_telemetry_exporter.dart';
export 'src/otlp_sink_client.dart';
export 'src/scripted_http_client.dart';
