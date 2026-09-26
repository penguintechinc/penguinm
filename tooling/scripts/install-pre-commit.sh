#!/usr/bin/env bash
# install-pre-commit.sh — install or verify the pre-commit/pre-push git
# hooks defined in .pre-commit-config.yaml, via the `pre-commit` framework
# (never hand-written git hooks — see the setup-git-hooks skill).
#
# Usage: install-pre-commit.sh [--verify]
#   (no args)  install the hook shims into the repo's git hooks directory
#   --verify   report whether the hooks are installed, executable, non-empty,
#              and whether .pre-commit-config.yaml still declares every hook
#              id this repo relies on; exits 1 on any gap
#
# Resolves the hooks directory via `git rev-parse --git-common-dir` so this
# works correctly from any git worktree (hooks are shared with the main
# checkout, not per-worktree).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: install-pre-commit.sh [--verify]

Installs (default) or verifies (--verify) the pre-commit/pre-push git hooks
declared in .pre-commit-config.yaml, using the `pre-commit` framework.
--verify exits 1 when a hook is missing, not executable, empty, or does not
invoke the pre-commit framework, or when .pre-commit-config.yaml is missing
an expected hook id.
EOF
}

VERIFY=0
case "${1:-}" in
  --verify)
    VERIFY=1
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    echo "install-pre-commit.sh: unknown argument: $1" >&2
    usage >&2
    exit 1
    ;;
esac

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CONFIG=".pre-commit-config.yaml"

if [ ! -f "$CONFIG" ]; then
  echo "install-pre-commit.sh: FAIL - $CONFIG not found" >&2
  exit 1
fi

GIT_COMMON_DIR="$(git rev-parse --git-common-dir)"
HOOKS_DIR="$GIT_COMMON_DIR/hooks"

check_hook() {
  local hook_name hook_path
  hook_name="$1"
  hook_path="$HOOKS_DIR/$hook_name"
  if [ ! -e "$hook_path" ]; then
    echo "MISSING: $hook_name ($hook_path)"
    return 1
  fi
  if [ ! -x "$hook_path" ]; then
    echo "NOT EXECUTABLE: $hook_name ($hook_path)"
    return 1
  fi
  if [ ! -s "$hook_path" ]; then
    echo "EMPTY: $hook_name ($hook_path)"
    return 1
  fi
  if ! grep -q "pre-commit" "$hook_path"; then
    echo "STUBBED: $hook_name does not invoke the pre-commit framework ($hook_path)"
    return 1
  fi
  echo "OK: $hook_name ($hook_path)"
  return 0
}

# Hook ids this repo's .pre-commit-config.yaml is expected to declare.
PRE_COMMIT_STAGE_IDS="gitleaks dart-format flutter-analyze zizmor hadolint-flutter-android"
PRE_PUSH_STAGE_IDS="trivy-fs osv-scanner semgrep"

check_config_ids() {
  local cfg_status stage_id
  cfg_status=0
  for stage_id in $PRE_COMMIT_STAGE_IDS $PRE_PUSH_STAGE_IDS; do
    if ! grep -qE "id:[[:space:]]*${stage_id}([[:space:]]|\$)" "$CONFIG"; then
      echo "MISSING HOOK ID in $CONFIG: $stage_id"
      cfg_status=1
    fi
  done
  return $cfg_status
}

if [ "$VERIFY" -eq 1 ]; then
  status=0
  check_hook "pre-commit" || status=1
  check_hook "pre-push" || status=1
  check_config_ids || status=1

  if [ "$status" -eq 0 ]; then
    echo "install-pre-commit.sh: verify OK - hooks installed at $HOOKS_DIR, $CONFIG has every expected hook id"
  else
    echo "install-pre-commit.sh: verify FAILED" >&2
  fi
  exit "$status"
fi

if ! command -v pre-commit >/dev/null 2>&1; then
  echo "install-pre-commit.sh: FAIL - 'pre-commit' not found on PATH; install via 'pip install pre-commit' (https://pre-commit.com)" >&2
  exit 1
fi

echo "install-pre-commit.sh: installing hooks from $CONFIG into $HOOKS_DIR"
pre-commit install --hook-type pre-commit --hook-type pre-push

check_hook "pre-commit"
check_hook "pre-push"

echo "install-pre-commit.sh: done"
exit 0
