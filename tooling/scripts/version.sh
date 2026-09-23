#!/usr/bin/env bash
# version.sh — apply VERSION (+ an epoch build number) to every app pubspec.
#
# Usage: version.sh
#
# Reads VERSION (repo root, "<major>.<minor>.<patch>") and rewrites the
# top-level `version:` field of every apps/*/pubspec.yaml to
# "<VERSION>+<epoch>".
#
# Fails when: VERSION is missing or not in <major>.<minor>.<patch> format,
# any apps/*/pubspec.yaml has no top-level `version:` field, or no
# apps/*/pubspec.yaml files are found.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: version.sh

Reads VERSION (repo root, e.g. "0.1.0") and applies "<VERSION>+<epoch>" as
the `version:` field of every apps/*/pubspec.yaml.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [ ! -f VERSION ]; then
  echo "version.sh: FAIL - VERSION file not found at repo root" >&2
  exit 1
fi

RAW_VERSION="$(head -n1 VERSION | tr -d '[:space:]')"

if ! echo "$RAW_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "version.sh: FAIL - VERSION '$RAW_VERSION' is not in <major>.<minor>.<patch> format" >&2
  exit 1
fi

BUILD_NUMBER="$(date +%s)"
FULL_VERSION="${RAW_VERSION}+${BUILD_NUMBER}"

updated=0
for pubspec in apps/*/pubspec.yaml; do
  [ -f "$pubspec" ] || continue
  if ! grep -qE '^version:' "$pubspec"; then
    echo "version.sh: FAIL - $pubspec has no top-level 'version:' field" >&2
    exit 1
  fi
  awk -v ver="$FULL_VERSION" '
    /^version:/ { print "version: " ver; next }
    { print }
  ' "$pubspec" > "${pubspec}.new"
  mv "${pubspec}.new" "$pubspec"
  echo "version.sh: $pubspec -> $FULL_VERSION"
  updated=$((updated + 1))
done

if [ "$updated" -eq 0 ]; then
  echo "version.sh: FAIL - no apps/*/pubspec.yaml found" >&2
  exit 1
fi

echo "version.sh: applied $FULL_VERSION to $updated app pubspec(s)"
exit 0
