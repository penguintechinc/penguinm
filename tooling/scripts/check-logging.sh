#!/usr/bin/env bash
# check-logging.sh — assert every package/shell/app uses the PenguinLogger
# conformance path instead of hand-rolled logging.
#
# Usage: check-logging.sh [ROOT_DIR]
#   ROOT_DIR defaults to the repo root. Accepted so this script can be
#   exercised against an isolated fixture directory in tests.
#
# Scans packages/*/lib shells/*/lib apps/*/lib (tooling/otlp_sink is exempt
# — it is a standalone Dart CLI, not app/package source).
#
# Fails when:
#   - 0 .dart files are scanned
#   - any scanned file calls print(, debugPrint(, or developer.log(
#   - shells/ never references PenguinLogger (i.e. nothing actually uses the
#     standard logging path)
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-logging.sh [ROOT_DIR]

Scans packages/*/lib, shells/*/lib, and apps/*/lib for hand-rolled logging
(print(, debugPrint(, developer.log() and asserts PenguinLogger is
referenced under shells/. tooling/otlp_sink is exempt.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

ROOT_DIR="${1:-}"
if [ -z "$ROOT_DIR" ]; then
  ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
fi
cd "$ROOT_DIR"

files=""
count=0
for glob in packages/*/lib shells/*/lib apps/*/lib; do
  [ -d "$glob" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    files="$files
$f"
    count=$((count + 1))
  done <<FOUND
$(find "$glob" -name '*.dart')
FOUND
done

if [ "$count" -eq 0 ]; then
  echo "check-logging: FAIL - 0 .dart files scanned under packages/*/lib shells/*/lib apps/*/lib" >&2
  exit 1
fi

violations=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  # Sanctioned logging-sink implementations: these files ARE the logging output
  # channel (penguin_core's canonical PenguinLogger console sink, and flutter_libs'
  # shared sanitized/version console utilities), so they legitimately call
  # developer.log. Everything else must route through PenguinLogger. Narrow, explicit
  # allowlist — any OTHER file with print(/debugPrint(/developer.log( still FAILs.
  case "$f" in
    */packages/penguin_core/lib/src/console_logger.dart|\
    */packages/flutter_libs/lib/src/console_version/version_logger.dart|\
    */packages/flutter_libs/lib/src/form_modal_builder/sanitized_logger.dart|\
    packages/penguin_core/lib/src/console_logger.dart|\
    packages/flutter_libs/lib/src/console_version/version_logger.dart|\
    packages/flutter_libs/lib/src/form_modal_builder/sanitized_logger.dart)
      echo "check-logging: allow - $f (sanctioned logging sink)"
      continue
      ;;
  esac
  hit="$(grep -nE 'print\(|debugPrint\(|developer\.log\(' "$f" || true)"
  if [ -n "$hit" ]; then
    echo "check-logging: FAIL - hand-rolled logging in $f" >&2
    echo "$hit" >&2
    violations=$((violations + 1))
  fi
done <<FILES
$files
FILES

if [ "$violations" -ne 0 ]; then
  exit 1
fi

penguinlogger_found=0
if [ -d shells ]; then
  hit="$(grep -rlE 'PenguinLogger' shells --include='*.dart' 2>/dev/null || true)"
  if [ -n "$hit" ]; then
    penguinlogger_found=1
  fi
fi

echo "check-logging: scanned $count files"

if [ "$penguinlogger_found" -eq 0 ]; then
  echo "check-logging: FAIL - PenguinLogger is not referenced anywhere under shells/" >&2
  exit 1
fi

echo "check-logging: PASS - $count file(s), 0 hand-rolled logging calls, PenguinLogger in use under shells/"
exit 0
