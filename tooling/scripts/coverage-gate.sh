#!/usr/bin/env bash
# coverage-gate.sh — enforce a minimum per-package line coverage percentage
# by parsing each package's coverage/lcov.info (LF:/LH: sums via awk; lcov
# itself is not installed/required).
#
# Usage: coverage-gate.sh [--min PERCENT] [ROOT_DIR]
#   --min PERCENT  minimum required line coverage percentage (default: 90)
#   ROOT_DIR       repo root to scan (default: repo root, two levels above
#                   this script). Accepted so this script can be exercised
#                   against an isolated fixture directory in tests.
#
# Packages are discovered by globbing packages/* shells/* apps/*
# platform/android/plugins/* tooling/otlp_sink under ROOT_DIR (melos is not
# required). packages/flutter_libs/example is always excluded. A package
# with no lib/**/*.dart is skipped (printed, not failed).
#
# Fails when any counted package is below the threshold, any counted package
# has LF=0 (no instrumented lines), or zero packages were counted.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: coverage-gate.sh [--min PERCENT] [ROOT_DIR]

Parses coverage/lcov.info for every package under packages/*, shells/*,
apps/*, platform/android/plugins/*, and tooling/otlp_sink (relative to
ROOT_DIR, default: repo root) and enforces a minimum per-package line
coverage percentage (default: 90). Prints one row per package and a totals
line.
EOF
}

MIN=90
ROOT_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --min)
      [ $# -ge 2 ] || { echo "coverage-gate.sh: --min requires a value" >&2; exit 1; }
      MIN="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      ROOT_DIR="$1"
      shift
      ;;
  esac
done

if [ -z "$ROOT_DIR" ]; then
  ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
fi
cd "$ROOT_DIR"

# packages/flutter_libs/example is a nested workspace member (its own
# pubspec.yaml under packages/flutter_libs/example/), not a top-level
# packages/* entry — the one-level glob below never yields it as a
# candidate, so it is excluded from the coverage gate with no special-casing
# needed here.
candidates=""
for pattern in packages/* shells/* apps/* platform/android/plugins/* tooling/otlp_sink; do
  for d in $pattern; do
    [ -d "$d" ] || continue
    candidates="$candidates $d"
  done
done

found=0
fail=0
sum_lf=0
sum_lh=0

for pkg in $candidates; do
  if [ -d "$pkg/lib" ]; then
    has_dart="$(find "$pkg/lib" -name '*.dart' | head -n1)"
  else
    has_dart=""
  fi
  if [ -z "$has_dart" ]; then
    echo "skipped: no Dart sources ($pkg)"
    continue
  fi

  found=$((found + 1))
  lcov="$pkg/coverage/lcov.info"
  if [ ! -f "$lcov" ]; then
    echo "FAIL   $pkg   no coverage/lcov.info found"
    fail=1
    continue
  fi

  # Intentional word splitting: awk prints exactly "<lf> <lh>" (two
  # integers), and this is Bash 3.2 so there is no array to unpack into.
  # shellcheck disable=SC2046
  set -- $(awk -F: '
    /^LF:/ { lf += $2 }
    /^LH:/ { lh += $2 }
    END { printf "%d %d", lf+0, lh+0 }
  ' "$lcov")
  lf="$1"
  lh="$2"

  if [ "$lf" -eq 0 ]; then
    echo "FAIL   $pkg   LF=0 (no instrumented lines)"
    fail=1
    continue
  fi

  pct="$(awk -v lh="$lh" -v lf="$lf" 'BEGIN { printf "%.1f", (lh/lf)*100 }')"
  below="$(awk -v pct="$pct" -v min="$MIN" 'BEGIN { print (pct+0 < min+0) ? 1 : 0 }')"
  status="PASS"
  if [ "$below" -eq 1 ]; then
    status="FAIL"
    fail=1
  fi
  echo "$status   $pkg   ${pct}%   (LH=$lh LF=$lf, min=${MIN}%)"

  sum_lf=$((sum_lf + lf))
  sum_lh=$((sum_lh + lh))
done

if [ "$found" -eq 0 ]; then
  echo "coverage-gate: FAIL - zero packages counted" >&2
  exit 1
fi

if [ "$sum_lf" -gt 0 ]; then
  total_pct="$(awk -v lh="$sum_lh" -v lf="$sum_lf" 'BEGIN { printf "%.1f", (lh/lf)*100 }')"
else
  total_pct="0.0"
fi
echo "TOTAL   $found package(s) counted   ${total_pct}%   (LH=$sum_lh LF=$sum_lf)"

if [ "$fail" -ne 0 ]; then
  echo "coverage-gate: FAIL - one or more packages below ${MIN}% or LF=0" >&2
  exit 1
fi

echo "coverage-gate: PASS - $found package(s), ${total_pct}% >= ${MIN}%"
exit 0
