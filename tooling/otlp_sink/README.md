# otlp_sink

Local OTLP/HTTP JSON receiver used by `tooling/scripts/telemetry-validate.sh`
to prove telemetry emission end-to-end: it counts received log records,
metric data points, histogram metrics, and spans so a smoke test can assert
`>=1` of each. Never deployed — a throwaway process started and killed
around a single test run. The only package in the workspace where `print(`
is allowed — CLI stdout is legitimate here. See spec §7.

## Run

```bash
cd tooling/otlp_sink
dart run otlp_sink --port 4318            # binds 127.0.0.1:4318
dart run otlp_sink --port 4318 --host 0.0.0.0
```

`--port` defaults to `4318`; `--host` defaults to `127.0.0.1`. The process
logs one line per request to stdout and runs until it receives
`SIGINT`/`SIGTERM`.

## Endpoints

| Method | Path | Behavior |
|---|---|---|
| `POST` | `/v1/logs` | OTLP/HTTP JSON logs payload; adds to `logRecords` |
| `POST` | `/v1/metrics` | OTLP/HTTP JSON metrics payload; adds to `metricDataPoints`/`histograms` |
| `POST` | `/v1/traces` | OTLP/HTTP JSON traces payload; adds to `spans` |
| `GET` | `/summary` | Returns current counts as JSON |
| `POST` | `/reset` | Zeroes every counter |
| anything else | — | `404` |

A malformed or non-object JSON body on any `/v1/*` path returns `400` and
leaves counters unchanged.

## `/summary` response

```json
{"logRecords": 0, "metricDataPoints": 0, "histograms": 0, "spans": 0}
```

## Counting rules

- **`logRecords`** — length of every `resourceLogs[].scopeLogs[].logRecords[]`.
- **`metricDataPoints`** — sum of `dataPoints[]` length across every metric's
  `sum`, `gauge`, and `histogram` aggregation, under
  `resourceMetrics[].scopeMetrics[].metrics[]`.
- **`histograms`** — count of metrics that carry a `histogram` key (counts
  metrics, not data points).
- **`spans`** — length of every `resourceSpans[].scopeSpans[].spans[]`.

## `telemetry-validate.sh` integration

`tooling/scripts/telemetry-validate.sh` starts this sink on
`127.0.0.1:4318`, runs `apps/penguin_reference`'s telemetry smoke test
against it, then asserts `logRecords >= 1`, `metricDataPoints >= 1`,
`histograms >= 1`, and `spans >= 1` from `GET /summary` before killing the
sink process.
