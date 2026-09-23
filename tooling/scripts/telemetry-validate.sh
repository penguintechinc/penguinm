#!/usr/bin/env bash
# telemetry-validate.sh — start the local OTLP/HTTP sink, run the reference
# app's telemetry smoke test against it, and assert the sink actually
# received log records, metric data points, histograms, and spans.
#
# Usage: telemetry-validate.sh
#
# This is the "logs + metrics + traces are mandatory" gate: a feature is not
# complete until it emits all three, and this script is what proves it on
# every commit rather than trusting a hand-wavy "should be instrumented".
#
# Fails when:
#   - tooling/otlp_sink or apps/penguin_reference are missing
#   - the sink does not answer GET /summary within 30s
#   - the sink process exits before it answers
#   - the telemetry smoke test fails
#   - logRecords < 1, metricDataPoints < 1, histograms < 1, or spans < 1
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: telemetry-validate.sh

Starts tooling/otlp_sink on 127.0.0.1:4318, runs
apps/penguin_reference/test/telemetry_smoke_test.dart against it, and
asserts the sink received >=1 log record, >=1 metric data point, >=1
histogram, and >=1 span. The sink is always killed on exit.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

SINK_PORT="4318"
SINK_URL="http://127.0.0.1:${SINK_PORT}"
SINK_PID=""

cleanup() {
  if [ -n "$SINK_PID" ] && kill -0 "$SINK_PID" 2>/dev/null; then
    kill "$SINK_PID" 2>/dev/null || true
    wait "$SINK_PID" 2>/dev/null || true
  fi
  # `dart run otlp_sink` spawns a dartvm grandchild that actually holds the
  # port; killing the launcher above does not reap it. Free the port explicitly
  # so a subsequent run can bind (root cause of leaked :4318 listeners).
  _port_pid="$(ss -ltnp 2>/dev/null | grep "127.0.0.1:${SINK_PORT} " | grep -oE 'pid=[0-9]+' | cut -d= -f2 | sort -u)"
  [ -n "$_port_pid" ] && kill -9 $_port_pid 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if [ ! -d tooling/otlp_sink ]; then
  echo "telemetry-validate: FAIL - tooling/otlp_sink not found" >&2
  exit 1
fi

if [ ! -d apps/penguin_reference ]; then
  echo "telemetry-validate: FAIL - apps/penguin_reference not found" >&2
  exit 1
fi

echo "telemetry-validate: starting otlp_sink on $SINK_URL"
(cd tooling/otlp_sink && dart run otlp_sink --port "$SINK_PORT") &
SINK_PID=$!

waited=0
until curl -sf -o /dev/null "$SINK_URL/summary" 2>/dev/null; do
  if ! kill -0 "$SINK_PID" 2>/dev/null; then
    echo "telemetry-validate: FAIL - otlp_sink process exited before answering $SINK_URL/summary" >&2
    exit 1
  fi
  if [ "$waited" -ge 30 ]; then
    echo "telemetry-validate: FAIL - otlp_sink did not answer $SINK_URL/summary within 30s" >&2
    exit 1
  fi
  sleep 1
  waited=$((waited + 1))
done
echo "telemetry-validate: otlp_sink is up (waited ${waited}s)"

echo "telemetry-validate: running telemetry smoke test in apps/penguin_reference"
(
  cd apps/penguin_reference
  OTLP_SINK="$SINK_URL" flutter test test/telemetry_smoke_test.dart
)

summary="$(curl -sf "$SINK_URL/summary")"
if [ -z "$summary" ]; then
  echo "telemetry-validate: FAIL - empty response from $SINK_URL/summary" >&2
  exit 1
fi

extract_count() {
  field="$1"
  echo "$summary" | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*[0-9]*" | grep -o '[0-9]*$'
}

log_records="$(extract_count logRecords)"
metric_points="$(extract_count metricDataPoints)"
histograms="$(extract_count histograms)"
spans="$(extract_count spans)"

log_records="${log_records:-0}"
metric_points="${metric_points:-0}"
histograms="${histograms:-0}"
spans="${spans:-0}"

echo "telemetry-validate: logRecords=$log_records metricDataPoints=$metric_points histograms=$histograms spans=$spans"

fail=0
[ "$log_records" -ge 1 ] || { echo "telemetry-validate: FAIL - logRecords=$log_records (<1)" >&2; fail=1; }
[ "$metric_points" -ge 1 ] || { echo "telemetry-validate: FAIL - metricDataPoints=$metric_points (<1)" >&2; fail=1; }
[ "$histograms" -ge 1 ] || { echo "telemetry-validate: FAIL - histograms=$histograms (<1)" >&2; fail=1; }
[ "$spans" -ge 1 ] || { echo "telemetry-validate: FAIL - spans=$spans (<1)" >&2; fail=1; }

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "telemetry-validate: PASS"
exit 0
