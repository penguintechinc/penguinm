#!/usr/bin/env bash
# new-app.sh — scaffold a new Flutter app under apps/<name>.
#
# Usage: new-app.sh [--overwrite] <name> <product_key> <display_name>
#
# Default (dir does not exist):
#   flutter create --org io.penguintech --platforms android,ios --empty
#     --project-name <name> apps/<name>
#   then `mason make penguin_app` (templates/penguin_app), then registers
#   apps/<name> in the root pubspec.yaml workspace: list (and melos.yaml/CI
#   matrix, if a recognizable list is found there).
#
# --overwrite (dir already exists):
#   re-runs `mason make penguin_app` with --on-conflict overwrite to
#   regenerate lib/ test/ env/ README.md CHANGELOG.md integration_test/ only
#   — pubspec.yaml and android/ are backed up before the render and
#   restored after, so hand-authored dependencies/config in either survive
#   (ios/ is never touched: it is outside the brick's file list by design).
#
# Fails when: <name> is not snake_case, or apps/<name> already exists and
# --overwrite was not passed.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: new-app.sh [--overwrite] <name> <product_key> <display_name>

Scaffolds apps/<name>: flutter create (first run only) + `mason make
penguin_app` from templates/penguin_app, then registers the app in the root
pubspec.yaml workspace list (and melos.yaml/CI matrix where recognizable).

--overwrite regenerates lib/ test/ env/ README.md CHANGELOG.md
integration_test/ of an EXISTING app; pubspec.yaml and android/ are backed
up beforehand and restored afterward so hand-authored changes survive
(ios/ is untouched, outside the brick's file list).
EOF
}

OVERWRITE=0
POSITIONAL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --overwrite)
      OVERWRITE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [ $# -gt 0 ]; do
        POSITIONAL="$POSITIONAL
$1"
        shift
      done
      ;;
    -*)
      echo "new-app.sh: unknown flag: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      POSITIONAL="$POSITIONAL
$1"
      shift
      ;;
  esac
done

NAME="$(echo "$POSITIONAL" | sed -n '2p')"
PRODUCT_KEY="$(echo "$POSITIONAL" | sed -n '3p')"
DISPLAY_NAME="$(echo "$POSITIONAL" | sed -n '4p')"
EXTRA="$(echo "$POSITIONAL" | sed -n '5p')"

if [ -z "$NAME" ] || [ -z "$PRODUCT_KEY" ] || [ -z "$DISPLAY_NAME" ] || [ -n "$EXTRA" ]; then
  echo "new-app.sh: expected exactly 3 positional args: <name> <product_key> <display_name>" >&2
  usage >&2
  exit 1
fi

if ! echo "$NAME" | grep -Eq '^[a-z][a-z0-9_]*$'; then
  echo "new-app.sh: FAIL - name '$NAME' is not snake_case" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

APP_DIR="apps/$NAME"

if [ -d "$APP_DIR" ] && [ "$OVERWRITE" -eq 0 ]; then
  echo "new-app.sh: FAIL - $APP_DIR already exists (pass --overwrite to regenerate lib/test/env/docs)" >&2
  exit 1
fi

if [ ! -d "$APP_DIR" ]; then
  echo "new-app.sh: flutter create --org io.penguintech --platforms android,ios --empty --project-name $NAME $APP_DIR"
  flutter create --org io.penguintech --platforms android,ios --empty --project-name "$NAME" "$APP_DIR"
else
  echo "new-app.sh: --overwrite - $APP_DIR exists, skipping flutter create; pubspec.yaml/android/ backed up and restored, ios/ untouched"
fi

MASON_VERSION="0.1.3"
if ! dart pub global list 2>/dev/null | grep -q "mason_cli $MASON_VERSION"; then
  echo "new-app.sh: activating mason_cli $MASON_VERSION"
  dart pub global activate mason_cli "$MASON_VERSION"
fi

if [ ! -d templates/penguin_app ]; then
  echo "new-app.sh: FAIL - templates/penguin_app brick not found (blocker: brick not scaffolded yet)" >&2
  exit 1
fi

# Create temporary JSON config with all brick variables.
# Mason CLI 0.1.3 does not support variable flags; it requires a config file.
MASON_CONFIG=$(mktemp)
BACKUP_DIR=""
cleanup() {
  rm -f "$MASON_CONFIG"
  if [ -n "$BACKUP_DIR" ]; then
    rm -rf "$BACKUP_DIR"
  fi
}
trap cleanup EXIT

# --overwrite clobbers everything mason's --on-conflict overwrite touches,
# and the brick's own pubspec.yaml IS part of its file list — so without a
# guard, --overwrite silently destroys any hand-authored dependency or
# config a prior run added to $APP_DIR/pubspec.yaml (and, defensively,
# android/, in case a future brick revision starts shipping one). Back
# both up before the render and restore them after.
if [ "$OVERWRITE" -eq 1 ]; then
  BACKUP_DIR=$(mktemp -d)
  if [ -f "$APP_DIR/pubspec.yaml" ]; then
    cp "$APP_DIR/pubspec.yaml" "$BACKUP_DIR/pubspec.yaml"
  fi
  if [ -d "$APP_DIR/android" ]; then
    cp -a "$APP_DIR/android" "$BACKUP_DIR/android"
  fi
fi

cat >"$MASON_CONFIG" <<EOFCONFIG
{
  "name": "$NAME",
  "product_key": "$PRODUCT_KEY",
  "display_name": "$DISPLAY_NAME",
  "org": "io.penguintech",
  "api_base_url_dev": "http://10.0.2.2:5000"
}
EOFCONFIG

echo "new-app.sh: mason make penguin_app -> $APP_DIR"
dart pub global run mason_cli:mason make penguin_app \
  --on-conflict overwrite \
  -o "$APP_DIR" \
  --config-path "$MASON_CONFIG"

if [ "$OVERWRITE" -eq 1 ] && [ -n "$BACKUP_DIR" ]; then
  if [ -f "$BACKUP_DIR/pubspec.yaml" ]; then
    cp "$BACKUP_DIR/pubspec.yaml" "$APP_DIR/pubspec.yaml"
    echo "new-app.sh: restored hand-authored $APP_DIR/pubspec.yaml (preserved across --overwrite)"
  fi
  if [ -d "$BACKUP_DIR/android" ]; then
    rm -rf "$APP_DIR/android"
    cp -a "$BACKUP_DIR/android" "$APP_DIR/android"
    echo "new-app.sh: restored hand-authored $APP_DIR/android (preserved across --overwrite)"
  fi
fi

WORKSPACE_PUBSPEC="pubspec.yaml"
if [ ! -f "$WORKSPACE_PUBSPEC" ]; then
  echo "new-app.sh: FAIL - root pubspec.yaml not found" >&2
  exit 1
fi

if grep -qF "$APP_DIR" "$WORKSPACE_PUBSPEC"; then
  echo "new-app.sh: $APP_DIR already present in $WORKSPACE_PUBSPEC workspace list"
else
  if ! grep -qE '^workspace:' "$WORKSPACE_PUBSPEC"; then
    echo "new-app.sh: FAIL - $WORKSPACE_PUBSPEC has no top-level 'workspace:' list" >&2
    exit 1
  fi
  awk -v member="$APP_DIR" '
    BEGIN { in_ws = 0; inserted = 0 }
    {
      if ($0 ~ /^workspace:/) { in_ws = 1; print; next }
      if (in_ws == 1) {
        if ($0 !~ /^  - /) {
          if (!inserted) { print "  - " member; inserted = 1 }
          in_ws = 0
          print
          next
        }
        print
        next
      }
      print
    }
    END {
      if (in_ws == 1 && !inserted) { print "  - " member }
    }
  ' "$WORKSPACE_PUBSPEC" > "${WORKSPACE_PUBSPEC}.new"
  mv "${WORKSPACE_PUBSPEC}.new" "$WORKSPACE_PUBSPEC"
  echo "new-app.sh: appended $APP_DIR to $WORKSPACE_PUBSPEC workspace list"
fi

if [ -f melos.yaml ]; then
  if grep -qF "$APP_DIR" melos.yaml; then
    echo "new-app.sh: $APP_DIR already present in melos.yaml"
  else
    echo "new-app.sh: NOTE - $APP_DIR not found in melos.yaml; melos packages: is glob-based unless overridden, verify manually" >&2
  fi
fi

if [ -f .github/workflows/ci.yml ]; then
  if grep -qE "^\s*-\s*${NAME}\s*$" .github/workflows/ci.yml; then
    echo "new-app.sh: $NAME already present in ci.yml android matrix"
  else
    echo "new-app.sh: NOTE - $NAME not found in .github/workflows/ci.yml android matrix; add it manually" >&2
  fi
fi

echo "new-app.sh: done ($APP_DIR, product_key=$PRODUCT_KEY, display_name=\"$DISPLAY_NAME\")"
