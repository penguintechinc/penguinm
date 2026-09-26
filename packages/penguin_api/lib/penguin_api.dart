/// PenguinApiClient over package:http with AuthClient/RetryClient/TraceClient
/// middleware; observes requests through penguin_core's MetricsSink/TraceSink.
library;

export 'src/client.dart' show PenguinApiClient;
export 'src/client_version_info.dart' show ClientVersionInfo;
export 'src/failure_mapper.dart' show mapFailure;
export 'src/retry_policy.dart' show RetryPolicy;
export 'src/middleware/auth_client.dart' show AuthClient;
export 'src/middleware/retry_client.dart' show RetryClient;
export 'src/middleware/trace_client.dart' show TraceClient;
export 'src/middleware/sanitized_log_client.dart' show SanitizedLogClient;
export 'src/providers.dart' show apiClientProvider;
