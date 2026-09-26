#!/usr/bin/env bash
# version.sh — apply one app's own VERSION (+ an epoch build number) to its
# pubspec.
#
# Usage: version.sh <app>
#
# Reads apps/<app>/VERSION ("<major>.<minor>.<patch>") and rewrites the
# top-level `version:` field of apps/<app>/pubspec.yaml to
# "<VERSION>+<epoch>". Every app versions, branches, and releases
# independently — this script touches ONLY apps/<app>/pubspec.yaml and
# never reads the root VERSION file (root VERSION is the shared-library
# version for packages/ + shells/, not an app version — see VERSION and
# docs/RELEASE.md).
#
# Fails when: no <app> argument is given, apps/<app>/ does not exist,
# apps/<app>/VERSION is missing or not in <major>.<minor>.<patch> format,
# or apps/<app>/pubspec.yaml is missing or has no top-level `version:`
# field.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: version.sh <app>

Reads apps/<app>/VERSION (e.g. "0.1.0") and applies "<VERSION>+<epoch>" as
the `version:` field of apps/<app>/pubspec.yaml. Only that app's pubspec is
touched — every app versions independently; run this once per app you're
releasing.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

APP="${1:-}"
if [ -z "$APP" ]; then
  echo "version.sh: FAIL - no app given" >&2
  usage >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

APP_DIR="apps/$APP"
VERSION_FILE="$APP_DIR/VERSION"
PUBSPEC="$APP_DIR/pubspec.yaml"

if [ ! -d "$APP_DIR" ]; then
  echo "version.sh: FAIL - $APP_DIR not found" >&2
  exit 1
fi

if [ ! -f "$VERSION_FILE" ]; then
  echo "version.sh: FAIL - $VERSION_FILE not found" >&2
  exit 1
fi

RAW_VERSION="$(head -n1 "$VERSION_FILE" | tr -d '[:space:]')"

if ! echo "$RAW_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "version.sh: FAIL - $VERSION_FILE '$RAW_VERSION' is not in <major>.<minor>.<patch> format" >&2
  exit 1
fi

if [ ! -f "$PUBSPEC" ]; then
  echo "version.sh: FAIL - $PUBSPEC not found" >&2
  exit 1
fi

if ! grep -qE '^version:' "$PUBSPEC"; then
  echo "version.sh: FAIL - $PUBSPEC has no top-level 'version:' field" >&2
  exit 1
fi

BUILD_NUMBER="$(date +%s)"
FULL_VERSION="${RAW_VERSION}+${BUILD_NUMBER}"

awk -v ver="$FULL_VERSION" '
  /^version:/ { print "version: " ver; next }
  { print }
' "$PUBSPEC" > "${PUBSPEC}.new"
mv "${PUBSPEC}.new" "$PUBSPEC"

echo "version.sh: $PUBSPEC -> $FULL_VERSION"
exit 0
