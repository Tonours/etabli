#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SCRIPT="$ROOT_DIR/scripts/deploy-harness"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ "${RUN_AGENT_CLI_SMOKE:-}" != "1" ]; then
  printf 'harness CLI smoke test: skipped (set RUN_AGENT_CLI_SMOKE=1 to run real agent CLIs)\n'
  exit 0
fi

if ! command -v perl >/dev/null 2>&1; then
  printf 'missing perl, needed for bounded CLI smoke timeouts\n' >&2
  exit 1
fi

trim_output() {
  sed -e 's/^[[:space:]`]*//' -e 's/[[:space:]`]*$//'
}

run_bounded() {
  local seconds="$1"
  shift

  perl -e 'alarm shift @ARGV; exec @ARGV' "$seconds" "$@"
}

pi_bin() {
  if command -v pi >/dev/null 2>&1; then
    command -v pi
    return 0
  fi

  if [ -x "$HOME/.asdf/shims/pi" ]; then
    printf '%s\n' "$HOME/.asdf/shims/pi"
  fi
}

claude_bin() {
  command -v claude 2>/dev/null || true
}

PROJECT="$TMP_DIR/project"
"$SCRIPT" "$PROJECT" >/dev/null

PI_BIN="$(pi_bin || true)"
if [ -n "$PI_BIN" ]; then
  pi_output="$(
    cd "$PROJECT"
    run_bounded 45 "$PI_BIN" --print --no-session --no-tools --thinking off \
      'According to the local project instructions, complete this sentence with the two missing words: Treat this file as a ___, not a ___. Reply only as word/word.'
  )"
  pi_output="$(printf '%s' "$pi_output" | trim_output)"
  if [ "$pi_output" != "map/manual" ]; then
    printf 'unexpected Pi output: %s\n' "$pi_output" >&2
    exit 1
  fi
  printf 'Pi CLI harness smoke: ok\n'
else
  printf 'Pi CLI harness smoke: skipped (pi not found)\n'
fi

CLAUDE_BIN="$(claude_bin)"
if [ -n "$CLAUDE_BIN" ]; then
  claude_output="$(
    cd "$PROJECT"
    printf '%s\n' 'According to the local project instructions, what file is the shared cross-agent map? Reply with only the path.' |
      run_bounded 60 "$CLAUDE_BIN" --print --no-session-persistence --max-budget-usd 0.10 --tools ""
  )"
  claude_output="$(printf '%s' "$claude_output" | trim_output)"
  case "$claude_output" in
    *"AGENTS.md"*) ;;
    *)
      printf 'unexpected Claude output: %s\n' "$claude_output" >&2
      exit 1
      ;;
  esac
  printf 'Claude Code harness smoke: ok\n'
else
  printf 'Claude Code harness smoke: skipped (claude not found)\n'
fi

printf 'harness CLI smoke test: ok\n'
