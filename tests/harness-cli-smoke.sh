#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SCRIPT="$ROOT_DIR/scripts/deploy-harness"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

trim_output() {
  sed -e 's/^[[:space:]`]*//' -e 's/[[:space:]`]*$//'
}

run_bounded() {
  local seconds="$1"
  shift

  perl -e '
    my $seconds = shift @ARGV;
    die "missing timeout\n" unless defined $seconds && $seconds =~ /\A[1-9][0-9]*\z/;
    die "missing command\n" unless @ARGV;
    alarm $seconds;
    exec @ARGV or die "exec failed: $!\n";
  ' "$seconds" "$@"
}

pi_bin() {
  local asdf_shim="${ASDF_DATA_DIR:-$HOME/.asdf}/shims/pi"

  if command -v pi >/dev/null 2>&1; then
    command -v pi
    return 0
  fi

  if [ -x "$asdf_shim" ]; then
    printf '%s\n' "$asdf_shim"
  fi
}

claude_bin() {
  command -v claude 2>/dev/null || true
}

pi_supports_flag() {
  local bin="$1"
  local flag="$2"

  "$bin" --help 2>&1 | grep -Eq -- "(^|[[:space:]])${flag}([,[:space:]]|$)"
}

if [ "${RUN_AGENT_CLI_SMOKE:-}" != "1" ] && [ "${RUN_AGENT_CLI_SMOKE_SELF_TEST:-}" != "1" ]; then
  printf 'harness CLI smoke test: skipped (set RUN_AGENT_CLI_SMOKE=1 to run real agent CLIs)\n'
  exit 0
fi

if ! command -v perl >/dev/null 2>&1; then
  printf 'missing perl, needed for bounded CLI smoke timeouts\n' >&2
  exit 1
fi

if [ "${RUN_AGENT_CLI_SMOKE_SELF_TEST:-}" = "1" ]; then
  if ! run_bounded 2 sh -c 'exit 0'; then
    printf 'bounded runner should allow successful commands\n' >&2
    exit 1
  fi

  if run_bounded 2 "$TMP_DIR/missing-cli" >/dev/null 2>&1; then
    printf 'bounded runner should fail when exec fails\n' >&2
    exit 1
  fi

  if run_bounded 1 sh -c 'sleep 5' >/dev/null 2>&1; then
    printf 'bounded runner should fail when commands exceed their timeout\n' >&2
    exit 1
  fi

  printf 'harness CLI bounded runner self-test: ok\n'

  STUB_BIN="$TMP_DIR/stub-bin"
  mkdir -p "$STUB_BIN"
  cat >"$STUB_BIN/pi" <<'SH'
#!/usr/bin/env sh
if [ "${1:-}" = "--help" ]; then
  printf 'Usage: pi [options]\n  --approve Trust project-local files for this run\n'
  exit 0
fi

case " $* " in
  *" --approve "*) ;;
  *" -a "*) ;;
  *)
    printf 'missing Pi --approve flag\n' >&2
    exit 42
    ;;
esac

if [ "${PI_SKIP_VERSION_CHECK:-}" != "1" ]; then
  printf 'missing PI_SKIP_VERSION_CHECK=1\n' >&2
  exit 42
fi

printf 'map/manual\n'
SH
  chmod +x "$STUB_BIN/pi"
  cat >"$STUB_BIN/claude" <<'SH'
#!/usr/bin/env sh
if [ "${1:-}" = "--version" ]; then
  printf 'claude-stub\n'
  exit 0
fi

cat >/dev/null
printf 'AGENTS.md\n'
SH
  chmod +x "$STUB_BIN/claude"

  PATH="$STUB_BIN:$PATH" RUN_AGENT_CLI_SMOKE=1 RUN_AGENT_CLI_SMOKE_SELF_TEST=0 "$0" >/dev/null
  printf 'harness CLI stub smoke: ok\n'

  if [ "${RUN_AGENT_CLI_SMOKE:-}" != "1" ]; then
    exit 0
  fi
fi

PROJECT="$TMP_DIR/project"
"$SCRIPT" "$PROJECT" >/dev/null

PI_BIN="$(pi_bin || true)"
if [ -n "$PI_BIN" ]; then
  pi_args=(--print --no-session --no-tools --thinking off)
  if pi_supports_flag "$PI_BIN" "--approve"; then
    pi_args+=(--approve)
  fi
  pi_args+=(
    'According to the local project instructions, complete this sentence with the two missing words: Treat this file as a ___, not a ___. Reply only as word/word.'
  )

  pi_output="$(
    cd "$PROJECT"
    PI_SKIP_VERSION_CHECK=1 run_bounded 45 "$PI_BIN" "${pi_args[@]}"
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
  claude_version="$(
    run_bounded 20 "$CLAUDE_BIN" --version 2>&1
  )"
  claude_version="$(printf '%s' "$claude_version" | trim_output)"
  if [ -z "$claude_version" ]; then
    printf 'unexpected empty Claude Code --version output\n' >&2
    exit 1
  fi
  printf 'Claude Code binary smoke: ok\n'
else
  printf 'Claude Code binary smoke: skipped (claude not found)\n'
fi

if [ "${RUN_CLAUDE_PRINT_SMOKE:-}" != "1" ]; then
  printf 'Claude Code print smoke: skipped (set RUN_CLAUDE_PRINT_SMOKE=1 to run claude --print)\n'
elif [ -n "$CLAUDE_BIN" ]; then
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
  printf 'Claude Code print smoke: ok\n'
else
  printf 'Claude Code print smoke: skipped (claude not found)\n'
fi

printf 'harness CLI smoke test: ok\n'
