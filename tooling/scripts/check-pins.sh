#!/usr/bin/env bash
# check-pins.sh — scan every pubspec.yaml, GitHub Actions workflow, and the
# Flutter/Android toolchain Dockerfile for mutable/unpinned references, and
# assert every Flutter-version pin in the repo agrees.
#
# Usage: check-pins.sh [ROOT_DIR]
#   ROOT_DIR defaults to the repo root (two levels above this script). An
#   explicit ROOT_DIR is accepted so this script can be exercised against an
#   isolated fixture directory in tests without needing a full repo scaffold.
#
# Fails when:
#   - any pubspec.yaml dependency uses ^, ~, "any", or a version range
#   - any pubspec.yaml git dependency has no 40-hex-character `ref:`
#   - any workflow `uses:` step is not pinned to a 40-hex-character SHA
#   - the Dockerfile FROM line has no `@sha256:` digest
#   - .fvmrc / .flutter-version / the Dockerfile's FLUTTER_VERSION ARG /
#     any workflow's `flutter-version:` disagree with each other
#   - zero pubspec.yaml files are found (files that don't exist yet, such as
#     workflows or the Dockerfile before their owning task lands, are skipped
#     rather than failed — only the pubspec scan is mandatory)
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-pins.sh [ROOT_DIR]

Scans every pubspec.yaml (excluding .dart_tool, build, .worktrees), every
.github/workflows/*.yml, and tooling/docker/Dockerfile.flutter-android for
mutable dependency refs, unpinned GitHub Actions/images, and mismatched
Flutter version pins. ROOT_DIR defaults to the repo root.
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

EXPECTED_FLUTTER_VERSION="3.44.8"
HEX40='[0-9a-fA-F]{40}'

violations=0
pubspec_count=0
workflow_count=0

# 1. pubspec.yaml dependency pinning
pubspec_files="$(find . -name pubspec.yaml \
  -not -path '*/.dart_tool/*' \
  -not -path '*/build/*' \
  -not -path '*/.worktrees/*' | sort)"

if [ -z "$pubspec_files" ]; then
  echo "check-pins: FAIL - 0 pubspec.yaml files found under $ROOT_DIR" >&2
  exit 1
fi

while IFS= read -r f; do
  [ -n "$f" ] || continue
  pubspec_count=$((pubspec_count + 1))
  bad_lines="$(awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    BEGIN { in_section = 0; nested_indent = 0; nested_git = 0; nested_ref_ok = 0 }
    {
      line = $0
      if (line ~ /^[A-Za-z0-9_]+:/) {
        if (nested_indent && nested_git && !nested_ref_ok) {
          print pending_ln ": " pending_line " -- git dependency missing 40-hex ref"
        }
        nested_indent = 0; nested_git = 0; nested_ref_ok = 0
        key = line
        sub(/:.*/, "", key)
        in_section = (key == "dependencies" || key == "dev_dependencies" || key == "dependency_overrides")
        next
      }
      if (!in_section) next

      if (line ~ /^  [A-Za-z0-9_]+:/) {
        if (nested_indent && nested_git && !nested_ref_ok) {
          print pending_ln ": " pending_line " -- git dependency missing 40-hex ref"
        }
        nested_indent = 0; nested_git = 0; nested_ref_ok = 0

        rest = line
        sub(/^  [A-Za-z0-9_]+:[ \t]*/, "", rest)
        rest = trim(rest)
        gsub(/"/, "", rest)
        if (rest == "") {
          nested_indent = 1
          pending_ln = NR
          pending_line = line
          next
        }
        if (rest ~ /\^/ || rest ~ /~/ || rest == "any" || rest ~ /</ || rest ~ />/) {
          print NR ": " line
        }
        next
      }

      if (nested_indent && line ~ /^    /) {
        if (line ~ /^    git:/) { nested_git = 1 }
        if (line ~ /ref:[ \t]*"?[0-9a-fA-F]{40}"?[ \t]*$/) { nested_ref_ok = 1 }
        next
      }
    }
    END {
      if (nested_indent && nested_git && !nested_ref_ok) {
        print pending_ln ": " pending_line " -- git dependency missing 40-hex ref"
      }
    }
  ' "$f")"
  if [ -n "$bad_lines" ]; then
    echo "check-pins: FAIL - mutable/unpinned dependency in $f" >&2
    echo "$bad_lines" >&2
    violations=$((violations + 1))
  fi
done <<PUBSPECS
$pubspec_files
PUBSPECS

echo "check-pins: scanned $pubspec_count pubspecs"

# 2. GitHub Actions workflow `uses:` pinning + flutter-version agreement
#
# Not every workflow declares flutter-version: — e.g. a container/buildx
# workflow, or one that runs inside the pinned toolchain image, legitimately
# pins Flutter through that image tag instead. Those are skipped for the
# per-workflow agreement check (not a violation), but at least one scanned
# workflow must declare it, or the check fails loudly — CI's own drift
# protection would otherwise have quietly gone missing.
found_versions=""
workflows_with_version=0

if [ -d .github/workflows ]; then
  for wf in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -e "$wf" ] || continue
    workflow_count=$((workflow_count + 1))
    bad_uses="$(grep -nE 'uses:[[:space:]]*[^[:space:]]+@' "$wf" \
      | grep -vE "@${HEX40}([[:space:]]|$)" || true)"
    if [ -n "$bad_uses" ]; then
      echo "check-pins: FAIL - unpinned 'uses:' (needs @<40-hex-sha>) in $wf" >&2
      echo "$bad_uses" >&2
      violations=$((violations + 1))
    fi

    # grep -m1 legitimately finds nothing for a workflow with no
    # flutter-version: line (e.g. a container/buildx workflow) — capture
    # with `|| true` so that non-match doesn't trip `set -e`/pipefail, and
    # treat "not declared" as skipped, not a violation.
    wf_ver_line="$(grep -m1 -E 'flutter-version:' "$wf" || true)"
    if [ -z "$wf_ver_line" ]; then
      echo "check-pins: skipped $wf (no flutter-version: — pins Flutter via the toolchain image instead)"
      continue
    fi

    workflows_with_version=$((workflows_with_version + 1))
    wf_ver="$(echo "$wf_ver_line" | sed -E 's/.*flutter-version:[[:space:]]*"?([0-9]+\.[0-9]+\.[0-9]+)"?.*/\1/')"
    found_versions="$found_versions $wf:$wf_ver"
    if [ "$wf_ver" != "$EXPECTED_FLUTTER_VERSION" ]; then
      echo "check-pins: FAIL - $wf flutter-version '$wf_ver' != $EXPECTED_FLUTTER_VERSION" >&2
      violations=$((violations + 1))
    else
      echo "check-pins: $wf flutter-version $wf_ver OK"
    fi
  done
fi
echo "check-pins: scanned $workflow_count workflow file(s), $workflows_with_version declared flutter-version:"

if [ "$workflow_count" -gt 0 ] && [ "$workflows_with_version" -eq 0 ]; then
  echo "check-pins: FAIL - 0 of $workflow_count workflow(s) declare flutter-version: (need at least one to pin against)" >&2
  violations=$((violations + 1))
fi

# 3. Dockerfile — FROM digest + FLUTTER_VERSION ARG
DOCKERFILE="tooling/docker/Dockerfile.flutter-android"
if [ -f "$DOCKERFILE" ]; then
  if ! grep -qE '^FROM[[:space:]].*@sha256:[0-9a-fA-F]{64}' "$DOCKERFILE"; then
    echo "check-pins: FAIL - $DOCKERFILE FROM line has no @sha256: digest" >&2
    violations=$((violations + 1))
  fi
  df_ver="$(grep -m1 -E '^ARG[[:space:]]+FLUTTER_VERSION=' "$DOCKERFILE" | sed -E 's/^ARG[[:space:]]+FLUTTER_VERSION=//' | tr -d '"'"'"'')"
  if [ -n "$df_ver" ]; then
    found_versions="$found_versions $DOCKERFILE:$df_ver"
    if [ "$df_ver" != "$EXPECTED_FLUTTER_VERSION" ]; then
      echo "check-pins: FAIL - $DOCKERFILE FLUTTER_VERSION '$df_ver' != $EXPECTED_FLUTTER_VERSION" >&2
      violations=$((violations + 1))
    fi
  else
    echo "check-pins: FAIL - $DOCKERFILE has no ARG FLUTTER_VERSION=" >&2
    violations=$((violations + 1))
  fi
  echo "check-pins: scanned $DOCKERFILE"
else
  echo "check-pins: skipped $DOCKERFILE (not present yet)"
fi

# 4. .fvmrc / .flutter-version agreement
if [ -f .fvmrc ]; then
  fvm_ver="$(grep -o '"flutter"[[:space:]]*:[[:space:]]*"[0-9.]*"' .fvmrc | grep -o '[0-9][0-9.]*' || true)"
  if [ -z "$fvm_ver" ]; then
    echo "check-pins: FAIL - .fvmrc has no parseable flutter version" >&2
    violations=$((violations + 1))
  else
    found_versions="$found_versions .fvmrc:$fvm_ver"
    if [ "$fvm_ver" != "$EXPECTED_FLUTTER_VERSION" ]; then
      echo "check-pins: FAIL - .fvmrc flutter version '$fvm_ver' != $EXPECTED_FLUTTER_VERSION" >&2
      violations=$((violations + 1))
    fi
  fi
  echo "check-pins: scanned .fvmrc"
else
  echo "check-pins: skipped .fvmrc (not present yet)"
fi

if [ -f .flutter-version ]; then
  fv_ver="$(tr -d '[:space:]' < .flutter-version)"
  found_versions="$found_versions .flutter-version:$fv_ver"
  if [ "$fv_ver" != "$EXPECTED_FLUTTER_VERSION" ]; then
    echo "check-pins: FAIL - .flutter-version '$fv_ver' != $EXPECTED_FLUTTER_VERSION" >&2
    violations=$((violations + 1))
  fi
  echo "check-pins: scanned .flutter-version"
else
  echo "check-pins: skipped .flutter-version (not present yet)"
fi

if [ -n "$found_versions" ]; then
  echo "check-pins: flutter version pins found:$found_versions"
fi

if [ "$violations" -ne 0 ]; then
  echo "check-pins: FAIL - $violations violation(s)" >&2
  exit 1
fi

echo "check-pins: PASS - $pubspec_count pubspecs, $workflow_count workflow(s) clean"
exit 0
