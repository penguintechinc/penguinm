import 'package:penguin_core/penguin_core.dart';

/// OTLP wire protocol requested for export. Only [httpJson] is implemented
/// in this version; [httpProtobuf] and [grpc] are accepted for forward
/// compatibility but `Telemetry.start` rejects them with a WARN log and
/// falls back to [httpJson].
enum OtlpProtocol {
  /// OTLP/HTTP with a JSON-encoded body — the only implemented protocol.
  httpJson,

  /// OTLP/HTTP with a protobuf-encoded body — not implemented.
  httpProtobuf,

  /// OTLP/gRPC — not implemented.
  grpc,
}

/// Immutable configuration for a running `Telemetry` instance: where to
/// export, how OTLP resource attributes are populated, and buffering
/// limits.
class TelemetryConfig {
  /// Creates a telemetry config directly; prefer [TelemetryConfig.fromAppConfig]
  /// in apps.
  const TelemetryConfig({
    required this.serviceName,
    required this.serviceVersion,
    this.endpoint,
    this.protocol = OtlpProtocol.httpJson,
    this.headers = const <String, String>{},
    this.resourceAttributes = const <String, Object?>{},
    this.exportInterval = const Duration(seconds: 10),
    this.maxQueue = 2048,
    this.consoleMirror = false,
  });

  /// Builds a [TelemetryConfig] from an app's [AppConfig]: `productKey`
  /// becomes `serviceName`, `appVersion` becomes `serviceVersion`, the OTLP
  /// endpoint/protocol/headers pass through as configured, the deployment
  /// environment is recorded under the standard `deployment.environment`
  /// resource attribute (which `Telemetry.start` also reads to decide
  /// whether DEBUG logs are enabled), and console mirroring is enabled
  /// below `beta`.
  factory TelemetryConfig.fromAppConfig(AppConfig c) {
    final protocol = switch (c.otlpProtocol) {
      'http/json' => OtlpProtocol.httpJson,
      'http/protobuf' => OtlpProtocol.httpProtobuf,
      'grpc' => OtlpProtocol.grpc,
      _ => OtlpProtocol.httpJson,
    };
    final isPreProd =
        c.environment == PenguinEnvironment.prealpha ||
        c.environment == PenguinEnvironment.alpha;
    return TelemetryConfig(
      serviceName: c.productKey,
      serviceVersion: c.appVersion,
      endpoint: c.otlpEndpoint,
      protocol: protocol,
      headers: c.otlpHeaders,
      resourceAttributes: <String, Object?>{
        'deployment.environment': c.environment.name,
      },
      consoleMirror: isPreProd,
    );
  }

  /// OTLP resource `service.name` — the app's product key.
  final String serviceName;

  /// OTLP resource `service.version` — the app's semantic version.
  final String serviceVersion;

  /// OTLP collector base URL; null disables export (uses `NoopExporter`).
  final Uri? endpoint;

  /// Requested wire protocol; only [OtlpProtocol.httpJson] is implemented.
  final OtlpProtocol protocol;

  /// Extra headers sent with every export request.
  final Map<String, String> headers;

  /// Extra OTLP resource attributes merged into every exported batch.
  final Map<String, Object?> resourceAttributes;

  /// How often buffered telemetry is exported automatically, in addition
  /// to any explicit `Telemetry.flush()` call.
  final Duration exportInterval;

  /// Maximum items retained per signal queue before the oldest is dropped.
  final int maxQueue;

  /// Whether every log record is also mirrored to a console logger.
  final bool consoleMirror;
}
