# penguin_telemetry

`Telemetry`, `Meter`/`Tracer`, and `OtlpHttpJsonExporter` — OpenTelemetry
logs/metrics/traces shipped to an env-configurable OTLP endpoint, never a
hardcoded vendor URL. Implements `MetricsSink`/`TraceSink` from
`penguin_core`. See spec §4.3.
