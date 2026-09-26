#!/usr/bin/env bash
# build-android.sh — build an app's Android artifact inside the pinned
# flutter-android toolchain image, and copy the result to
# build/artifacts/<app>/.
#
# Usage: build-android.sh [--dry-run] <app> <flavor> [apk|aab]
#   app     apps/<app> must exist
#   flavor  dev | beta | prod
#   format  apk (default) | aab
#
# Release artifacts are always obfuscated for `aab` (Play Store uploads),
# and for `apk` when flavor=prod (spec §6: "isMinifyEnabled +
# --obfuscate --split-debug-info for release") — `--obfuscate
# --split-debug-info=build/artifacts/<app>/debug-info/` is appended to the
# flutter build command in those two cases. dev/beta apk builds are left
# un-obfuscated so local/QA builds stay symbolicated.
#
# --dry-run prints the composed `flutter build` command (and creates the
# debug-info dir when one would apply) without requiring the toolchain
# image to exist and without invoking docker at all.
#
# Fails when: any step is non-zero — app dir missing, image missing (run
# `make docker-build` first; not checked in --dry-run), env/<flavor>.json
# missing, the build itself fails, or no .apk/.aab artifact is found
# afterwards.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build-android.sh [--dry-run] <app> <flavor> [apk|aab]

Runs `flutter build <apk|aab> --release --flavor <flavor>
--dart-define-from-file=env/<flavor>.json` for apps/<app> inside the
penguinm/flutter-android:local toolchain image (docker run --rm -u 1000 -v
"$PWD":/work -w /work), then copies the resulting artifact to
build/artifacts/<app>/.

Release builds are obfuscated (--obfuscate
--split-debug-info=build/artifacts/<app>/debug-info/) for format=aab, and
for format=apk when flavor=prod.

--dry-run prints the composed flutter build command and exits without
requiring the toolchain image or invoking docker.
EOF
}

DRY_RUN=0
ARGS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      ARGS="$ARGS
$1"
      shift
      ;;
  esac
done

APP="$(echo "$ARGS" | sed -n '2p')"
FLAVOR="$(echo "$ARGS" | sed -n '3p')"
FORMAT="$(echo "$ARGS" | sed -n '4p')"
EXTRA="$(echo "$ARGS" | sed -n '5p')"
FORMAT="${FORMAT:-apk}"

if [ -z "$APP" ] || [ -z "$FLAVOR" ] || [ -n "$EXTRA" ]; then
  echo "build-android.sh: expected <app> <flavor> [apk|aab] (plus optional --dry-run)" >&2
  usage >&2
  exit 1
fi

case "$FLAVOR" in
  dev|beta|prod) ;;
  *)
    echo "build-android.sh: FAIL - flavor must be dev, beta, or prod (got '$FLAVOR')" >&2
    exit 1
    ;;
esac

case "$FORMAT" in
  apk|aab) ;;
  *)
    echo "build-android.sh: FAIL - format must be apk or aab (got '$FORMAT')" >&2
    exit 1
    ;;
esac

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [ ! -d "apps/$APP" ]; then
  echo "build-android.sh: FAIL - apps/$APP not found" >&2
  exit 1
fi

ENV_FILE="apps/$APP/env/${FLAVOR}.json"
if [ ! -f "$ENV_FILE" ]; then
  echo "build-android.sh: FAIL - $ENV_FILE not found" >&2
  exit 1
fi

ARTIFACT_DIR="build/artifacts/$APP"
mkdir -p "$ARTIFACT_DIR"

OBFUSCATE_FLAGS=""
if [ "$FORMAT" = "aab" ] || { [ "$FORMAT" = "apk" ] && [ "$FLAVOR" = "prod" ]; }; then
  DEBUG_INFO_DIR="$ARTIFACT_DIR/debug-info"
  mkdir -p "$DEBUG_INFO_DIR"
  OBFUSCATE_FLAGS="--obfuscate --split-debug-info=/work/$DEBUG_INFO_DIR"
fi

BUILD_CMD="flutter build $FORMAT --release --flavor $FLAVOR --dart-define-from-file=env/${FLAVOR}.json"
if [ -n "$OBFUSCATE_FLAGS" ]; then
  BUILD_CMD="$BUILD_CMD $OBFUSCATE_FLAGS"
fi

echo "build-android.sh: composed command for apps/$APP ($FLAVOR, $FORMAT): $BUILD_CMD"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "build-android.sh: --dry-run - not invoking docker"
  exit 0
fi

IMAGE="penguinm/flutter-android:local"
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "build-android.sh: FAIL - $IMAGE not found locally; run 'make docker-build' first" >&2
  exit 1
fi

echo "build-android.sh: building apps/$APP ($FLAVOR, $FORMAT) inside $IMAGE"
docker run --rm -u 1000 -v "$PWD":/work -w "/work/apps/$APP" "$IMAGE" bash -c "$BUILD_CMD"

if [ "$FORMAT" = "apk" ]; then
  SRC_DIR="apps/$APP/build/app/outputs/flutter-apk"
else
  SRC_DIR="apps/$APP/build/app/outputs/bundle/${FLAVOR}Release"
fi

if [ ! -d "$SRC_DIR" ]; then
  echo "build-android.sh: FAIL - expected output dir $SRC_DIR not found after build" >&2
  exit 1
fi

found_any=0
for f in "$SRC_DIR"/*."$FORMAT"; do
  [ -e "$f" ] || continue
  cp "$f" "$ARTIFACT_DIR/"
  echo "build-android.sh: copied $(basename "$f") -> $ARTIFACT_DIR/"
  found_any=1
done

if [ "$found_any" -eq 0 ]; then
  echo "build-android.sh: FAIL - no .$FORMAT artifacts found in $SRC_DIR" >&2
  exit 1
fi

echo "build-android.sh: done"
exit 0
