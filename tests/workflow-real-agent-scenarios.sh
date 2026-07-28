#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
DEPLOY_WORKFLOW="$ROOT_DIR/scripts/deploy-workflow"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ "${RUN_REAL_AGENT_SCENARIOS:-}" != "1" ]; then
  printf 'workflow real agent scenarios: skipped (set RUN_REAL_AGENT_SCENARIOS=1 to run real Pi and Claude CLIs)\n'
  exit 0
fi

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

normalize_agent_output() {
  awk '
    NF && $0 !~ /^Warning: No models match pattern / && $0 !~ /^⚠ / {
      line = $0
    }
    END {
      gsub(/^[[:space:]`]+|[[:space:]`]+$/, "", line)
      print line
    }
  '
}

assert_exact() {
  local label="$1"
  local expected="$2"
  local actual="$3"

  if [ "$actual" != "$expected" ]; then
    printf 'FAIL: %s expected %s, got %s\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_one_of() {
  local label="$1"
  local actual="$2"
  shift 2
  local expected

  for expected in "$@"; do
    if [ "$actual" = "$expected" ]; then
      return 0
    fi
  done

  printf 'FAIL: %s got unexpected output %s\nexpected one of:' "$label" "$actual" >&2
  for expected in "$@"; do
    printf ' %s' "$expected" >&2
  done
  printf '\n' >&2
  exit 1
}

assert_contains() {
  local label="$1"
  local haystack="$2"
  local needle="$3"

  case "$haystack" in
    *"$needle"*) ;;
    *)
      printf 'FAIL: %s expected output to contain %s\noutput was:\n%s\n' "$label" "$needle" "$haystack" >&2
      exit 1
      ;;
  esac
}

new_project() {
  local name="$1"
  local project="$TMP_DIR/$name"

  "$DEPLOY_WORKFLOW" "$project" >/dev/null
  printf '%s\n' "$project"
}

write_plan() {
  local project="$1"
  local status="$2"

  cat >"$project/PLAN.md" <<EOF
# PLAN.md

## Meta
- Status: $status

## Goal
Validate workflow routing in a temporary real-agent scenario.
EOF
}

PI_TIMEOUT="${REAL_AGENT_PI_TIMEOUT:-90}"
PI_TASKEXECUTE_TIMEOUT="${REAL_AGENT_TASKEXECUTE_TIMEOUT:-240}"
PI_MODEL="${REAL_AGENT_PI_MODEL:-openai-codex/gpt-5.3-codex-spark}"
CLAUDE_TIMEOUT="${REAL_AGENT_CLAUDE_TIMEOUT:-90}"
CLAUDE_MODEL="${REAL_AGENT_CLAUDE_MODEL:-haiku}"
CLAUDE_EFFORT="${REAL_AGENT_CLAUDE_EFFORT:-low}"
CLAUDE_BUDGET="${REAL_AGENT_CLAUDE_BUDGET:-0.10}"
CLAUDE_HOOK_BUDGET="${REAL_AGENT_CLAUDE_HOOK_BUDGET:-0.01}"
REAL_AGENT_RETRIES="${REAL_AGENT_RETRIES:-3}"

PI_BIN="$(pi_bin || true)"
CLAUDE_BIN="$(claude_bin)"

if [ "${RUN_REAL_AGENT_PI:-1}" = "1" ] && [ -z "$PI_BIN" ]; then
  printf 'FAIL: RUN_REAL_AGENT_PI=1 but pi was not found on PATH or asdf shims\n' >&2
  exit 1
fi

if [ "${RUN_REAL_AGENT_CLAUDE:-1}" = "1" ] && [ -z "$CLAUDE_BIN" ]; then
  printf 'FAIL: RUN_REAL_AGENT_CLAUDE=1 but claude was not found on PATH\n' >&2
  exit 1
fi

run_pi_prompt() {
  local project="$1"
  local prompt="$2"
  local output
  local status
  local normalized
  local attempt
  local args=(--print --no-session --no-tools --thinking off --model "$PI_MODEL")

  if pi_supports_flag "$PI_BIN" "--approve"; then
    args+=(--approve)
  fi
  args+=("$prompt")

  for attempt in $(seq 1 "$REAL_AGENT_RETRIES"); do
    set +e
    output="$(
      cd "$project"
      PI_SKIP_VERSION_CHECK=1 run_bounded "$PI_TIMEOUT" "$PI_BIN" "${args[@]}" 2>&1
    )"
    status=$?
    set -e

    normalized="$(printf '%s\n' "$output" | normalize_agent_output)"
    if [ "$status" -eq 0 ] \
      && ! printf '%s\n' "$normalized" | grep -Eiq 'Codex error|error occurred while processing|rate limit|temporar|timeout|timed out'; then
      printf '%s\n' "$normalized"
      return 0
    fi

    if [ "$attempt" -lt "$REAL_AGENT_RETRIES" ]; then
      sleep "$attempt"
    fi
  done

  printf '%s\n' "$normalized"
}

resolve_tintinweb_subagents_extension() {
  local candidate
  local settings_path="$HOME/.pi/agent/settings.json"
  local temp_prefix
  local temp_extension

  for candidate in \
    "$HOME/.pi/agent/npm/node_modules/@tintinweb/pi-subagents/dist/index.js" \
    "$HOME/.pi/npm/node_modules/@tintinweb/pi-subagents/dist/index.js"; do
    if [ -f "$candidate" ]; then
      if [ -f "$settings_path" ] && grep -Fq 'npm:@tintinweb/pi-subagents' "$settings_path"; then
        return 0
      fi
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if ! command -v npm >/dev/null 2>&1; then
    printf 'FAIL: npm is required to install @tintinweb/pi-subagents for TaskExecute e2e\n' >&2
    exit 1
  fi

  temp_prefix="$TMP_DIR/tintinweb-pi-subagents"
  temp_extension="$temp_prefix/node_modules/@tintinweb/pi-subagents/dist/index.js"
  mkdir -p "$temp_prefix"

  if npm install --silent --prefix "$temp_prefix" @tintinweb/pi-subagents@0.13.0 >/dev/null 2>&1 \
    && [ -f "$temp_extension" ]; then
    printf '%s\n' "$temp_extension"
    return 0
  fi

  printf 'FAIL: could not install or locate @tintinweb/pi-subagents@0.13.0\n' >&2
  exit 1
}

run_pi_taskexecute_e2e() {
  local project="$1"
  local subagent_extension
  local archive_path="$project/docs/plan/20260702-pi-task-subagent-e2e.md"
  local proof_path="$project/subagent-proof.txt"
  local tasks_path="$project/.pi/tasks/e2e.json"
  local output
  local status
  local attempt
  local prompt
  local args

  subagent_extension="$(resolve_tintinweb_subagents_extension)"
  args=(--print --no-session --no-builtin-tools --tools TaskCreate,TaskList,TaskExecute,TaskOutput,TaskGet --thinking off --model "$PI_MODEL")
  if [ -n "$subagent_extension" ]; then
    args=(--extension "$subagent_extension" "${args[@]}")
  fi
  if pi_supports_flag "$PI_BIN" "--approve"; then
    args+=(--approve)
  fi

  prompt="You are in a temporary Etabli workflow project. Use only Task* tools. Create exactly one pending task with metadata {\"agentType\":\"worker\"}. The task description must tell the worker to work in the current directory, create subagent-proof.txt with exactly SUBAGENT_E2E_OK and a trailing newline, create docs/plan/20260702-pi-task-subagent-e2e.md containing '# Pi Task subagent e2e archive' and 'Status: implemented', delete the root PLAN.md, and avoid changing other files. Then TaskExecute that task with model $PI_MODEL and max_turns 12. Then call TaskOutput with block=true and timeout=180000. Finish with a concise status."

  for attempt in $(seq 1 "$REAL_AGENT_RETRIES"); do
    rm -f "$proof_path" "$archive_path"
    mkdir -p "$project/.pi/tasks" "$project/docs/plan"
    write_plan "$project" "READY"

    set +e
    output="$(
      cd "$project"
      PI_TASKS="$tasks_path" PI_TASKS_DEBUG=1 PI_SKIP_VERSION_CHECK=1 \
        run_bounded "$PI_TASKEXECUTE_TIMEOUT" "$PI_BIN" "${args[@]}" "$prompt" 2>&1
    )"
    status=$?
    set -e

    if [ "$status" -eq 0 ] \
      && [ "$(cat "$proof_path" 2>/dev/null || true)" = "SUBAGENT_E2E_OK" ] \
      && [ -f "$archive_path" ] \
      && grep -Fq 'Status: implemented' "$archive_path" \
      && [ ! -e "$project/PLAN.md" ] \
      && printf '%s\n' "$output" | grep -Eq 'subagents:rpc:spawn|spawn:ok|spawn:call'; then
      printf '%s\n' "$output"
      return 0
    fi

    if [ "$attempt" -lt "$REAL_AGENT_RETRIES" ]; then
      sleep "$attempt"
    fi
  done

  printf 'FAIL: Pi TaskExecute subagent e2e did not produce expected archive/delete evidence\n' >&2
  printf 'project: %s\n' "$project" >&2
  printf 'output:\n%s\n' "$output" >&2
  exit 1
}

run_claude_answer() {
  local project="$1"
  local prompt="$2"
  local output
  local status
  local normalized
  local attempt

  for attempt in $(seq 1 "$REAL_AGENT_RETRIES"); do
    set +e
    output="$(
      cd "$project"
      run_bounded "$CLAUDE_TIMEOUT" "$CLAUDE_BIN" \
        --print \
        --no-session-persistence \
        --max-budget-usd "$CLAUDE_BUDGET" \
        --model "$CLAUDE_MODEL" \
        --effort "$CLAUDE_EFFORT" \
        --tools "" \
        --settings "$ROOT_DIR/claude/settings.workflow-hooks.json" \
        "$prompt" 2>&1
    )"
    status=$?
    set -e

    normalized="$(printf '%s\n' "$output" | normalize_agent_output)"
    if [ "$status" -eq 0 ] \
      && ! printf '%s\n' "$normalized" | grep -Eiq 'error occurred while processing|rate limit|temporar|timeout|timed out|Exceeded USD budget'; then
      printf '%s\n' "$normalized"
      return 0
    fi

    if [ "$attempt" -lt "$REAL_AGENT_RETRIES" ]; then
      sleep "$attempt"
    fi
  done

  printf '%s\n' "$normalized"
}

run_claude_hook_route() {
  local project="$1"
  local prompt="$2"
  local expected_route="$3"
  local expected_reason="${4:-}"
  local output
  local status

  set +e
  output="$(
    cd "$project"
    run_bounded "$CLAUDE_TIMEOUT" "$CLAUDE_BIN" \
      --print \
      --verbose \
      --output-format=stream-json \
      --include-hook-events \
      --no-session-persistence \
      --max-budget-usd "$CLAUDE_HOOK_BUDGET" \
      --model "$CLAUDE_MODEL" \
      --effort "$CLAUDE_EFFORT" \
      --tools "" \
      --settings "$ROOT_DIR/claude/settings.workflow-hooks.json" \
      "$prompt" 2>&1
  )"
  status=$?
  set -e

  assert_contains "Claude hook route $expected_route" "$output" '"hook_name":"UserPromptSubmit"'
  assert_contains "Claude hook route $expected_route" "$output" "Route: $expected_route"
  if [ -n "$expected_reason" ]; then
    assert_contains "Claude hook reason $expected_reason" "$output" "$expected_reason"
  fi

  # Claude may exceed the tiny hook-only budget after the hook has already
  # emitted the route. That is acceptable for this scenario; missing route
  # evidence is not.
  if [ "$status" -ne 0 ]; then
    assert_contains "Claude hook budget/termination" "$output" "Route: $expected_route"
  fi
}

route_prompt() {
  local prompt="$1"

  printf '%s If the Etabli Workflow Router context is present, reply with only its Route value in the format ROUTE=<value>.' "$prompt"
}

if [ "${RUN_REAL_AGENT_PI:-1}" = "1" ]; then
  PI_VERSION="$("$PI_BIN" --version 2>&1 | normalize_agent_output)"
  printf 'Pi CLI detected: %s\n' "$PI_VERSION"
fi

if [ "${RUN_REAL_AGENT_CLAUDE:-1}" = "1" ]; then
  CLAUDE_VERSION="$("$CLAUDE_BIN" --version 2>&1 | normalize_agent_output)"
  printf 'Claude Code detected: %s\n' "$CLAUDE_VERSION"
fi

PROJECT="$(new_project scaffold-map)"
if [ "${RUN_REAL_AGENT_PI:-1}" = "1" ]; then
  assert_one_of \
    "Pi scaffold map/manual" \
    "$(run_pi_prompt "$PROJECT" 'According to the local project instructions, complete this sentence with the two missing words: Treat this file as a ___, not a ___. Reply only as word/word.')" \
    "map/manual" \
    "carte/manual" \
    "carte/manuelle"
fi
if [ "${RUN_REAL_AGENT_CLAUDE:-1}" = "1" ]; then
  assert_contains \
    "Claude scaffold AGENTS.md" \
    "$(run_claude_answer "$PROJECT" 'According to the local project instructions, what file is the shared cross-agent map? Reply with only the path.')" \
    "AGENTS.md"
fi
printf 'PASS: scaffold-map scenario\n'

PROJECT="$(new_project ready-read-only)"
write_plan "$PROJECT" "READY"
if [ "${RUN_REAL_AGENT_PI:-1}" = "1" ]; then
  assert_exact "Pi ready read-only route" "ROUTE=answer" "$(run_pi_prompt "$PROJECT" "$(route_prompt 'Résume le PLAN.md ready.')")"
fi
if [ "${RUN_REAL_AGENT_CLAUDE:-1}" = "1" ]; then
  run_claude_hook_route "$PROJECT" "$(route_prompt 'Résume le PLAN.md ready.')" "answer" "read-only, question, or summary request"
fi
printf 'PASS: ready-read-only scenario\n'

PROJECT="$(new_project adversarial-code-review)"
if [ "${RUN_REAL_AGENT_PI:-1}" = "1" ]; then
  assert_exact "Pi adversarial code review route" "ROUTE=review" "$(run_pi_prompt "$PROJECT" "$(route_prompt 'fais une code-review complète puis une code-review adversary.')")"
fi
if [ "${RUN_REAL_AGENT_CLAUDE:-1}" = "1" ]; then
  run_claude_hook_route "$PROJECT" "$(route_prompt 'fais une code-review complète puis une code-review adversary.')" "review"
fi
printf 'PASS: adversarial-code-review scenario\n'

PROJECT="$(new_project read-only-adversarial-plan)"
write_plan "$PROJECT" "READY"
if [ "${RUN_REAL_AGENT_PI:-1}" = "1" ]; then
  assert_exact "Pi read-only adversarial plan route" "ROUTE=review" "$(run_pi_prompt "$PROJECT" "$(route_prompt 'Read-only adversarial PLAN.md review. Do not edit files.')")"
fi
if [ "${RUN_REAL_AGENT_CLAUDE:-1}" = "1" ]; then
  run_claude_hook_route "$PROJECT" "$(route_prompt 'Read-only adversarial PLAN.md review. Do not edit files.')" "review" "read-only adversarial review request"
fi
printf 'PASS: read-only-adversarial-plan scenario\n'

PROJECT="$(new_project ready-implement)"
write_plan "$PROJECT" "READY"
if [ "${RUN_REAL_AGENT_PI:-1}" = "1" ]; then
  assert_exact "Pi actual READY implement route" "ROUTE=implement" "$(run_pi_prompt "$PROJECT" "$(route_prompt 'Implémente le PLAN.md ready.')")"
fi
if [ "${RUN_REAL_AGENT_CLAUDE:-1}" = "1" ]; then
  run_claude_hook_route "$PROJECT" "$(route_prompt 'Implémente le PLAN.md ready.')" "implement" "implementation request with READY plan"
fi
printf 'PASS: ready-implement scenario\n'

PROJECT="$(new_project prompt-only-ready)"
if [ "${RUN_REAL_AGENT_PI:-1}" = "1" ]; then
  assert_exact "Pi prompt-only READY route" "ROUTE=plan-implement" "$(run_pi_prompt "$PROJECT" "$(route_prompt 'Implémente le PLAN.md ready.')")"
fi
if [ "${RUN_REAL_AGENT_CLAUDE:-1}" = "1" ]; then
  run_claude_hook_route "$PROJECT" "$(route_prompt 'Implémente le PLAN.md ready.')" "plan-implement" "actual PLAN.md status is not proven READY"
fi
printf 'PASS: prompt-only-ready scenario\n'

if [ "${RUN_REAL_AGENT_PI:-1}" = "1" ] && [ "${RUN_REAL_AGENT_TASKEXECUTE:-1}" = "1" ]; then
  PROJECT="$(new_project taskexecute-subagent-workflow)"
  run_pi_taskexecute_e2e "$PROJECT" >/dev/null
  printf 'PASS: taskexecute-subagent-workflow scenario\n'
fi

printf 'workflow real agent scenarios: ok\n'
