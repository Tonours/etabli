. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hash.sh"

HARNESS_EVALUATOR_ID="binary-final-state-v2"
HARNESS_CURSOR_SENTINEL='Cursor Task is absent|required Cursor Task|CURSOR_TASK_REQUIRED'
HARNESS_DECIDING_ROW_RE='\|[^|]*[a-zA-Z0-9_./-]+:[0-9]'
HARNESS_STOP_CONTEXT_RE='^isolation: |^runner: |hard stop|arrêt|interromp'

harness_die() {
  printf 'etabli-harness-eval-v2: %s\n' "$1" >&2
  exit 2
}

harness_sha256() {
  local digest
  digest="$(hash256 "$1")"
  printf '%s\n' "${digest%% *}"
}

harness_iso_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

harness_fixtures_dir() {
  printf '%s\n' "${HARNESS_ROOT:?}/tests/fixtures/harness-v2"
}

harness_manifest_path() {
  printf '%s/manifest.json\n' "$(harness_fixtures_dir)"
}

harness_grade_lib_path() {
  printf '%s/scripts/lib/etabli-harness-grade.sh\n' "${HARNESS_ROOT:?}"
}

harness_task_dir() {
  printf '%s/tasks/%s\n' "$(harness_fixtures_dir)" "$1"
}

harness_task_ids() {
  jq -r '.tasks[].id' "$(harness_manifest_path)"
}

harness_task_field() {
  jq -r --arg id "$1" --arg field "$2" \
    '.tasks[] | select(.id == $id) | .[$field] | if type == "array" then join(" ") else tostring end' \
    "$(harness_manifest_path)"
}

harness_task_has_runner() {
  jq -e --arg id "$1" --arg runner "$2" \
    '.tasks[] | select(.id == $id) | .runners | index($runner)' \
    "$(harness_manifest_path)" >/dev/null
}

harness_task_sha() {
  local dir="$1"
  local digest
  digest="$(
    cd "$dir" &&
      find . -type f ! -path './synthetic/*' | LC_ALL=C sort |
      while IFS= read -r f; do
        printf '%s\0' "$f"
        cat "$f"
        printf '\0'
      done | hash256
  )"
  printf '%s\n' "${digest%% *}"
}

harness_parse_review() {
  local file="$1"
  local line last="" act=0 dec=0
  REVIEW_VERDICT=""
  REVIEW_ISOLATED=0
  REVIEW_ISOLATION_NONE=0
  REVIEW_RUNNER_PI_CHILD=0
  REVIEW_LENS_TABLE=0
  REVIEW_DECIDING_TABLE=0
  REVIEW_DECIDING_FILE_LINE=0
  REVIEW_SENTINEL=0
  REVIEW_STOP_CONTEXT=0
  REVIEW_ACT_BLOCK=""
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "${line//[[:space:]]/}" ] && last="$line"
    case "$line" in
    'isolation: isolated') REVIEW_ISOLATED=1 ;;
    'isolation: none') REVIEW_ISOLATION_NONE=1 ;;
    'runner: pi-child') REVIEW_RUNNER_PI_CHILD=1 ;;
    esac
    case "$line" in *'| Lens |'*) REVIEW_LENS_TABLE=1 ;; esac
    case "$line" in *Deciding-code* | *'Changed behavior'*) REVIEW_DECIDING_TABLE=1 ;; esac
    case "$line" in *HUNTER_SPAWN_UNAVAILABLE* | *HUNTER_TIMEOUT*) REVIEW_SENTINEL=1 ;; esac
    shopt -s nocasematch
    [[ "$line" =~ $HARNESS_STOP_CONTEXT_RE ]] && REVIEW_STOP_CONTEXT=1
    shopt -u nocasematch
    if [ "$act" -eq 0 ]; then
      case "$line" in *'Act on'*) act=1 ;; esac
    fi
    if [ "$act" -lt 2 ]; then
      case "$line" in
      Verdict:*)
        [ "$act" -eq 1 ] && REVIEW_ACT_BLOCK+="$line"$'\n'
        act=2
        ;;
      *) [ "$act" -eq 1 ] && REVIEW_ACT_BLOCK+="$line"$'\n' ;;
      esac
    fi
    if [ "$dec" -lt 2 ]; then
      case "$line" in
      *Deciding-code*) dec=1 ;;
      Verdict:*) [ "$dec" -eq 1 ] && dec=2 ;;
      *)
        if [ "$dec" -eq 1 ] && [[ "$line" =~ $HARNESS_DECIDING_ROW_RE ]]; then
          REVIEW_DECIDING_FILE_LINE=1
        fi
        ;;
      esac
    fi
  done <"$file"
  case "$last" in
  'Verdict: GO WITH NOTES' | 'Verdict: BLOCK' | 'Verdict: GO') REVIEW_VERDICT="${last#Verdict: }" ;;
  esac
}

harness_oracle_fail() {
  printf 'oracle %s: %s\n' "${TASK_ID:-unknown}" "$1" >&2
  exit 1
}

harness_oracle_init() {
  [ -n "${WORKTREE:-}" ] && [ -d "$WORKTREE" ] || harness_oracle_fail "WORKTREE is required"
  [ -n "${TRANSCRIPT:-}" ] && [ -f "$TRANSCRIPT" ] || harness_oracle_fail "TRANSCRIPT is required"
  [ -n "${TASK_DIR:-}" ] && [ -d "$TASK_DIR" ] || harness_oracle_fail "TASK_DIR is required"
  harness_parse_review "$TRANSCRIPT"
}

harness_require_verdict() {
  local allowed
  [ -n "$REVIEW_VERDICT" ] ||
    harness_oracle_fail "unparseable verdict; need a final line matching ^Verdict: (GO WITH NOTES|BLOCK|GO)$"
  for allowed in "$@"; do
    [ "$REVIEW_VERDICT" = "$allowed" ] && return 0
  done
  harness_oracle_fail "final verdict was ${REVIEW_VERDICT}; expected one of: $*"
}

harness_forbid_verdict() {
  [ "$REVIEW_VERDICT" != "$1" ] || harness_oracle_fail "final verdict must not be $1"
}

harness_forbid_go_without_isolation() {
  if [ "$REVIEW_VERDICT" = "GO" ] && [ "$REVIEW_ISOLATION_NONE" -eq 1 ]; then
    harness_oracle_fail "GO with isolation: none in the same transcript"
  fi
}

harness_require_tables() {
  [ "$REVIEW_LENS_TABLE" -eq 1 ] || harness_oracle_fail "missing lens table"
  [ "$REVIEW_DECIDING_TABLE" -eq 1 ] || harness_oracle_fail "missing deciding-code table"
}

harness_require_deciding_file_line() {
  [ "$REVIEW_DECIDING_FILE_LINE" -eq 1 ] ||
    harness_oracle_fail "deciding-code section has no row with a file:line reference"
}

harness_require_act_on_mentions() {
  case "$REVIEW_ACT_BLOCK" in
  *"$1"*) ;;
  *) harness_oracle_fail "$1 missing from Act on / verdict block" ;;
  esac
}

harness_require_sentinel() {
  [ "$REVIEW_SENTINEL" -eq 1 ] || harness_oracle_fail "transcript missing HUNTER_SPAWN_UNAVAILABLE|HUNTER_TIMEOUT"
}

harness_require_stop_context() {
  [ "$REVIEW_STOP_CONTEXT" -eq 1 ] || harness_oracle_fail "sentinel without isolation/runner context"
}

harness_require_isolated_hunt() {
  [ "$REVIEW_ISOLATED" -eq 1 ] || harness_oracle_fail "expected isolation: isolated"
  [ "$REVIEW_RUNNER_PI_CHILD" -eq 1 ] || harness_oracle_fail "expected runner: pi-child"
  harness_require_spawn_evidence
}

harness_require_spawn_evidence() {
  local log="${SPAWN_LOG:-}"
  [ -n "$log" ] || harness_oracle_fail "spawn evidence required but SPAWN_LOG not provided (driver misuse)"
  [ -s "$log" ] ||
    harness_oracle_fail "transcript claims an isolated child hunt but no pi spawn was observed"
  grep -Eq -- '--no-session.*--append-system-prompt|--append-system-prompt.*--no-session' "$log" ||
    harness_oracle_fail "spawn log has no hunter invocation (needs --no-session and --append-system-prompt on one line)"
}

harness_require_unchanged() {
  local source="$1" path="$2"
  [ -f "$WORKTREE/$path" ] || harness_oracle_fail "missing $path"
  [ -f "$TASK_DIR/$source/$path" ] || harness_oracle_fail "missing expected $source/$path"
  cmp -s "$WORKTREE/$path" "$TASK_DIR/$source/$path" || harness_oracle_fail "SHA mismatch: $path"
}

harness_path_allowed() {
  local path="$1"
  shift
  local pat
  for pat in "$@"; do
    case "$pat" in
    */)
      [ "$path" = "${pat%/}" ] && return 0
      [[ "$path" == "${pat}"* ]] && return 0
      ;;
    *)
      [ "$path" = "$pat" ] && return 0
      ;;
    esac
  done
  return 1
}

harness_porcelain_paths() {
  HARNESS_PORCELAIN_PATHS=()
  local line st path
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    st="${line:0:2}"
    path="${line:3}"
    case "$st" in
    'R ' | 'C ') HARNESS_PORCELAIN_PATHS+=("${path%% -> *}" "${path##* -> }") ;;
    *) HARNESS_PORCELAIN_PATHS+=("$path") ;;
    esac
  done < <(git -C "$WORKTREE" status --porcelain -uall)
}

harness_require_only_paths() {
  local path
  [ -d "$WORKTREE/.git" ] || harness_oracle_fail "worktree is not a git repo"
  harness_porcelain_paths
  if [ "${#HARNESS_PORCELAIN_PATHS[@]}" -gt 0 ]; then
    for path in "${HARNESS_PORCELAIN_PATHS[@]}"; do
      [ -n "$path" ] || continue
      harness_path_allowed "$path" "$@" || harness_oracle_fail "path outside allowlist: $path"
    done
  fi
}

harness_head_sha() {
  local wt="$1" head_target head_file sha
  read -r head_target <"$wt/.git/HEAD" 2>/dev/null || return 1
  case "$head_target" in
  'ref: refs/heads/'*) ;;
  *) return 1 ;;
  esac
  head_file="$wt/.git/${head_target#ref: }"
  [ -f "$head_file" ] || return 1
  read -r sha <"$head_file" || return 1
  [ -n "$sha" ] || return 1
  printf '%s\n' "$sha"
}

harness_resolved_head() {
  harness_head_sha "$1" || git -C "$1" rev-parse HEAD
}

harness_write_baseline() {
  harness_resolved_head "$1" >"$1.harness-baseline" 2>/dev/null
}

harness_require_head_unchanged() {
  local expected actual
  if [ -n "${BASELINE_EXPECTED:-}" ]; then
    expected="$BASELINE_EXPECTED"
  else
    local baseline="${BASELINE_FILE:?}"
    [ -f "$baseline" ] || harness_oracle_fail "missing worktree baseline (prepare not run)"
    expected="$(head -n 1 "$baseline")"
  fi
  actual="$(harness_resolved_head "$WORKTREE")"
  [ "$expected" = "$actual" ] || harness_oracle_fail "worktree HEAD changed (commit/amend burial)"
}

harness_ensure_ignore() {
  local gi="$1/.gitignore"
  if [ -f "$gi" ]; then
    grep -qxF '.workflow/' "$gi" || printf '.workflow/\n' >>"$gi"
    grep -qxF 'docs/agent-memory/' "$gi" || printf 'docs/agent-memory/\n' >>"$gi"
    grep -qxF '.pi/' "$gi" || printf '.pi/\n' >>"$gi"
  else
    printf '.workflow/\ndocs/agent-memory/\n.pi/\n' >"$gi"
  fi
}

harness_constant_baseline_transcript() {
  cat <<'EOF'
HUNTER_SPAWN_UNAVAILABLE: pi not on PATH
isolation: none
runner: not run

## Lens table
| Lens | Checked (file:line) | Found |
| --- | --- | --- |
| Logic | src/runtime.sh:4 | checked |
| Spec | src/runtime.sh:4 | checked |

## Deciding-code table
| Changed behavior | Deciding code opened (file:line) | Sibling / resolver | Result |
| --- | --- | --- | --- |
| runtime helper | src/runtime.sh:4 | n/a | reviewed |

## Act on
- Spec: uncommitted FORBIDDEN.txt violates PLAN.md Out.

Verdict: BLOCK
EOF
}

harness_make_spawn_stubs() {
  local dir="$1"
  local name node
  mkdir -p "$dir"
  for name in pi grok claude agent cursor-agent; do
    cat >"$dir/$name" <<'EOF'
#!/bin/sh
printf 'HUNTER_SPAWN_UNAVAILABLE: %s stub\n' "$(basename "$0")" >&2
exit 2
EOF
    chmod +x "$dir/$name"
  done
  node="$(command -v node)" || harness_die "node not on PATH (needed to launch pi without a PATH-mutating wrapper)"
  ln -sf "$node" "$dir/node"
}

harness_make_logging_pi_wrapper() {
  local dir="$1" log_path="$2" real_pi="$3"
  mkdir -p "$dir"
  cat >"$dir/pi" <<EOF
#!/bin/sh
printf '%s %s\n' "\$(date -u +%Y%m%dT%H%M%SZ)" "\$*" >>"$log_path"
exec "$real_pi" "\$@"
EOF
  chmod +x "$dir/pi"
}

harness_cursor_sentinel_hit() {
  grep -Eiq -- "$HARNESS_CURSOR_SENTINEL" "$1"
}

harness_model_mismatch_hit() {
  local transcript="$1"
  local requested="${2:-}"
  grep -Fq 'unknown effort level' "$transcript" && return 0
  grep -Eiq 'unknown thinking|invalid thinking' "$transcript" && return 0
  if grep -Fq 'Warning: No models match pattern' "$transcript"; then
    if [ -n "$requested" ] && [ "$requested" != "none" ]; then
      grep -F 'Warning: No models match pattern' "$transcript" | grep -Fq -- "$requested"
      return
    fi
    return 0
  fi
  return 1
}

harness_json_row() {
  jq -n \
    --arg evaluator_id "$HARNESS_EVALUATOR_ID" \
    --arg task_id "$1" \
    --arg split "$2" \
    --arg runner "$3" \
    --arg model_requested "$4" \
    --arg model_effective "$5" \
    --arg thinking_requested "$6" \
    --arg thinking_effective "$7" \
    --arg started_at "$8" \
    --argjson duration_s "$9" \
    --argjson runner_exit "${10}" \
    --argjson oracle_exit "${11}" \
    --argjson pass "${12}" \
    --arg transcript_path "${13}" \
    --arg manifest_sha "${14}" \
    --arg oracle_sha "${15}" \
    --arg task_sha "${16}" \
    '{
      evaluator_id: $evaluator_id,
      task_id: $task_id,
      split: $split,
      runner: $runner,
      model_requested: $model_requested,
      model_effective: $model_effective,
      thinking_requested: $thinking_requested,
      thinking_effective: $thinking_effective,
      started_at: $started_at,
      duration_s: $duration_s,
      runner_exit: $runner_exit,
      oracle_exit: $oracle_exit,
      pass: $pass,
      transcript_path: $transcript_path,
      manifest_sha: $manifest_sha,
      oracle_sha: $oracle_sha,
      task_sha: $task_sha
    }'
}

harness_grade_precheck_failure() {
  local runner="$1" transcript="$2" model_requested="$3"
  if harness_cursor_sentinel_hit "$transcript"; then
    printf 'cursor sentinel in transcript\n'
  elif [ "$runner" != "offline" ] && harness_model_mismatch_hit "$transcript" "$model_requested"; then
    printf 'model or effort mismatch in transcript\n'
  elif [ "$runner" != "offline" ] && [ -z "${BASELINE_EXPECTED:-}" ]; then
    printf 'runner %s graded without a driver-held BASELINE_EXPECTED\n' "$runner"
  fi
}

harness_grade() {
  local task_id="$1" worktree="$2" transcript="$3" runner="${4:-offline}"
  local model_requested="${5:-none}" model_effective="${6:-none}"
  local thinking_requested="${7:-none}" thinking_effective="${8:-none}"
  local runner_exit="${9:-0}" run_started="${10:-}" run_duration="${11:-}"
  local fixtures task_dir oracle split manifest_sha oracle_sha task_sha started precheck
  local t0 duration oracle_exit pass

  fixtures="$(harness_fixtures_dir)"
  task_dir="$fixtures/tasks/$task_id"
  [ -d "$task_dir" ] || harness_die "unknown task: $task_id"
  oracle="$task_dir/oracle.sh"
  [ -f "$oracle" ] || harness_die "missing oracle: $oracle"
  [ -f "$transcript" ] || harness_die "missing transcript: $transcript"
  [ -d "$worktree" ] || harness_die "missing worktree: $worktree"

  split="$(harness_task_field "$task_id" split)"
  manifest_sha="$(harness_sha256 "$fixtures/manifest.json")"
  oracle_sha="$(harness_sha256 "$oracle")"
  task_sha="$(harness_task_sha "$task_dir")"
  started="${run_started:-$(harness_iso_now)}"

  precheck="$(harness_grade_precheck_failure "$runner" "$transcript" "$model_requested")"
  if [ -n "$precheck" ]; then
    printf 'grade %s: %s\n' "$task_id" "$precheck" >&2
    harness_json_row "$task_id" "$split" "$runner" "$model_requested" "$model_effective" \
      "$thinking_requested" "$thinking_effective" "$started" 0 "$runner_exit" 1 false \
      "$transcript" "$manifest_sha" "$oracle_sha" "$task_sha"
    return 0
  fi

  t0=$SECONDS
  set +e
  WORKTREE="$worktree" TRANSCRIPT="$transcript" TASK_DIR="$task_dir" TASK_ID="$task_id" \
    BASELINE_FILE="$worktree.harness-baseline" BASELINE_EXPECTED="${BASELINE_EXPECTED:-}" \
    SPAWN_LOG="${SPAWN_LOG:-/nonexistent-spawn-log}" \
    ETABLI_HARNESS_LIB="$(harness_grade_lib_path)" \
    bash "$oracle"
  oracle_exit=$?
  set -e
  duration="${run_duration:-$((SECONDS - t0))}"
  pass=false
  [ "$oracle_exit" -eq 0 ] && pass=true
  if [ "$runner" != "offline" ] && [ "$runner_exit" -ne 0 ]; then
    pass=false
  fi

  harness_json_row "$task_id" "$split" "$runner" "$model_requested" "$model_effective" \
    "$thinking_requested" "$thinking_effective" "$started" "$duration" "$runner_exit" \
    "$oracle_exit" "$pass" "$transcript" "$manifest_sha" "$oracle_sha" "$task_sha"
}
