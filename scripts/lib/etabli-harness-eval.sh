# Shared helpers for scripts/etabli-harness-eval and per-task oracle.sh.
# Sourced only. Do not execute.

HARNESS_PI_MODEL="zai/glm-5.3"
HARNESS_PI_THINKING="max"
HARNESS_GROK_MODEL="grok-4.6"
HARNESS_GROK_EFFORT="xhigh"
HARNESS_GROK_PERMISSION="acceptEdits"
HARNESS_TIMEOUT_DEFAULT="${ETABLI_HARNESS_EVAL_TIMEOUT:-600}"
HARNESS_CURSOR_SENTINEL='Cursor Task is absent|required Cursor Task|CURSOR_TASK_REQUIRED'

harness_die() {
  printf 'etabli-harness-eval: %s\n' "$1" >&2
  exit 2
}

harness_sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

harness_iso_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

harness_fixtures_dir() {
  printf '%s\n' "${HARNESS_ROOT:?}/tests/fixtures/harness-v1"
}

harness_manifest_path() {
  printf '%s/manifest.json\n' "$(harness_fixtures_dir)"
}

harness_lib_path() {
  printf '%s/scripts/lib/etabli-harness-eval.sh\n' "${HARNESS_ROOT:?}"
}

harness_task_dir() {
  printf '%s/tasks/%s\n' "$(harness_fixtures_dir)" "$1"
}

harness_extract_verdict() {
  local file="$1"
  awk '
    /^Verdict: GO WITH NOTES$/ { v = $0 }
    /^Verdict: BLOCK$/ { v = $0 }
    /^Verdict: GO$/ { v = $0 }
    END { print v }
  ' "$file"
}

harness_oracle_fail() {
  printf 'oracle %s: %s\n' "${TASK_ID:-unknown}" "$1" >&2
  exit 1
}

harness_oracle_init() {
  [ -n "${WORKTREE:-}" ] && [ -d "$WORKTREE" ] || harness_oracle_fail "WORKTREE is required"
  [ -n "${TRANSCRIPT:-}" ] && [ -f "$TRANSCRIPT" ] || harness_oracle_fail "TRANSCRIPT is required"
  [ -n "${TASK_DIR:-}" ] && [ -d "$TASK_DIR" ] || harness_oracle_fail "TASK_DIR is required"
}

harness_require_verdict() {
  local verdict
  verdict="$(harness_extract_verdict "$TRANSCRIPT")"
  [ -n "$verdict" ] || harness_oracle_fail "unparseable verdict; need a final line matching ^Verdict: (GO WITH NOTES|BLOCK|GO)$"
  printf '%s\n' "$verdict"
}

harness_forbid_verdict_go() {
  local verdict
  verdict="$(harness_require_verdict)"
  [ "$verdict" != "Verdict: GO" ] || harness_oracle_fail "final verdict must not be GO"
}

harness_require_verdict_one_of() {
  local verdict allowed
  verdict="$(harness_require_verdict)"
  for allowed in "$@"; do
    if [ "$verdict" = "$allowed" ]; then
      return 0
    fi
  done
  harness_oracle_fail "final verdict was ${verdict}; expected one of: $*"
}

harness_require_transcript_re() {
  grep -Eq -- "$1" "$TRANSCRIPT" || harness_oracle_fail "transcript missing /$1/"
}

harness_require_tables() {
  grep -Fq '| Lens |' "$TRANSCRIPT" || harness_oracle_fail "missing lens table"
  grep -Eq 'Deciding-code|Changed behavior' "$TRANSCRIPT" || harness_oracle_fail "missing deciding-code table"
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
  git -C "$WORKTREE" status --porcelain | awk '{
    if ($1 == "R" || $1 == "C") {
      print $NF
    } else {
      $1 = ""
      sub(/^ /, "")
      print
    }
  }'
}

harness_require_porcelain_allowlist() {
  local path
  [ -d "$WORKTREE/.git" ] || harness_oracle_fail "worktree is not a git repo"
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    harness_path_allowed "$path" "$@" || harness_oracle_fail "path outside allowlist: $path"
  done < <(harness_porcelain_paths)
}

harness_require_file_sha_eq() {
  local actual="$1"
  local expected="$2"
  [ -f "$actual" ] || harness_oracle_fail "missing $actual"
  [ -f "$expected" ] || harness_oracle_fail "missing expected $expected"
  local a e
  a="$(harness_sha256 "$actual")"
  e="$(harness_sha256 "$expected")"
  [ "$a" = "$e" ] || harness_oracle_fail "SHA mismatch: $actual"
}

harness_require_contains() {
  grep -Fq -- "$2" "$1" || harness_oracle_fail "$1 missing: $2"
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
      if grep -F 'Warning: No models match pattern' "$transcript" | grep -Fq -- "$requested"; then
        return 0
      fi
      return 1
    fi
    return 0
  fi
  return 1
}

harness_task_ids() {
  jq -r '.tasks[].id' "$(harness_manifest_path)"
}

harness_task_field() {
  local id="$1"
  local field="$2"
  jq -r --arg id "$id" --arg field "$field" \
    '.tasks[] | select(.id == $id) | .[$field] | if type == "array" then join(" ") else tostring end' \
    "$(harness_manifest_path)"
}

harness_task_has_runner() {
  local id="$1"
  local runner="$2"
  jq -e --arg id "$id" --arg runner "$runner" \
    '.tasks[] | select(.id == $id) | .runners | index($runner)' \
    "$(harness_manifest_path)" >/dev/null
}

harness_print_argv() {
  local runner="$1"
  local cwd="${2:-/tmp/etabli-harness-eval}"
  local prompt="${3:-PROMPT}"

  case "$runner" in
  pi)
    printf '%s\n' \
      pi \
      -p \
      --no-session \
      --approve \
      --model \
      "$HARNESS_PI_MODEL" \
      --thinking \
      "$HARNESS_PI_THINKING" \
      "$prompt"
    ;;
  grok)
    printf '%s\n' \
      grok \
      --cwd \
      "$cwd" \
      -m \
      "$HARNESS_GROK_MODEL" \
      --reasoning-effort \
      "$HARNESS_GROK_EFFORT" \
      --permission-mode \
      "$HARNESS_GROK_PERMISSION" \
      -p \
      "$prompt"
    ;;
  *)
    harness_die "unknown runner: $runner"
    ;;
  esac
}

harness_json_row() {
  jq -n \
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
    '{
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
      oracle_sha: $oracle_sha
    }'
}

harness_grade() {
  local task_id="$1"
  local worktree="$2"
  local transcript="$3"
  local runner="${4:-offline}"
  local task_dir oracle started duration oracle_exit pass manifest_sha oracle_sha split
  local model_requested="${5:-none}"
  local model_effective="${6:-none}"
  local thinking_requested="${7:-none}"
  local thinking_effective="${8:-none}"
  local runner_exit="${9:-0}"
  local run_started="${10:-}"
  local run_duration="${11:-}"

  task_dir="$(harness_task_dir "$task_id")"
  [ -d "$task_dir" ] || harness_die "unknown task: $task_id"
  oracle="$task_dir/oracle.sh"
  [ -f "$oracle" ] || harness_die "missing oracle: $oracle"
  [ -f "$transcript" ] || harness_die "missing transcript: $transcript"
  [ -d "$worktree" ] || harness_die "missing worktree: $worktree"

  split="$(harness_task_field "$task_id" split)"
  manifest_sha="$(harness_sha256 "$(harness_manifest_path)")"
  oracle_sha="$(harness_sha256 "$oracle")"
  started="${run_started:-$(harness_iso_now)}"

  if harness_cursor_sentinel_hit "$transcript"; then
    harness_json_row "$task_id" "$split" "$runner" "$model_requested" "$model_effective" \
      "$thinking_requested" "$thinking_effective" "$started" 0 "$runner_exit" 1 false \
      "$transcript" "$manifest_sha" "$oracle_sha"
    return 0
  fi

  if [ "$runner" != "offline" ] && harness_model_mismatch_hit "$transcript" "$model_requested"; then
    harness_json_row "$task_id" "$split" "$runner" "$model_requested" "$model_effective" \
      "$thinking_requested" "$thinking_effective" "$started" 0 "$runner_exit" 1 false \
      "$transcript" "$manifest_sha" "$oracle_sha"
    return 0
  fi

  local t0=$SECONDS
  set +e
  WORKTREE="$worktree" TRANSCRIPT="$transcript" TASK_DIR="$task_dir" TASK_ID="$task_id" \
    ETABLI_HARNESS_LIB="$(harness_lib_path)" \
    bash "$oracle"
  oracle_exit=$?
  set -e
  if [ -n "$run_duration" ]; then
    duration="$run_duration"
  else
    duration=$((SECONDS - t0))
  fi
  if [ "$oracle_exit" -eq 0 ]; then
    pass=true
  else
    pass=false
  fi
  if [ "$runner" != "offline" ] && [ "$runner_exit" -ne 0 ]; then
    pass=false
  fi

  harness_json_row "$task_id" "$split" "$runner" "$model_requested" "$model_effective" \
    "$thinking_requested" "$thinking_effective" "$started" "$duration" "$runner_exit" \
    "$oracle_exit" "$pass" "$transcript" "$manifest_sha" "$oracle_sha"
}

harness_run_bounded() {
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

harness_resolve_bin() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi
  return 1
}

harness_prepare_worktree() {
  local task_id="$1"
  local dest="$2"
  local task_dir overlay uncommitted

  task_dir="$(harness_task_dir "$task_id")"
  overlay="$task_dir/overlay"
  uncommitted="$task_dir/uncommitted"
  mkdir -p "$dest"
  "${HARNESS_ROOT:?}/scripts/deploy-workflow" "$dest" >/dev/null
  if [ -d "$overlay" ]; then
    cp -R "$overlay/." "$dest/"
  fi
  harness_ensure_ignore "$dest"
  git -C "$dest" init -q
  git -C "$dest" config user.email 'harness-eval@etabli.test'
  git -C "$dest" config user.name 'harness-eval'
  git -C "$dest" add -A
  git -C "$dest" -c commit.gpgsign=false commit --allow-empty -qm 'harness-eval fixture'
  if [ -d "$uncommitted" ]; then
    cp -R "$uncommitted/." "$dest/"
  fi
}

harness_effective_from_transcript() {
  local transcript="$1"
  local _requested="$2"
  local key="$3"
  local line
  line="$(grep -E "^${key}:" "$transcript" | tail -n 1 || true)"
  if [ -n "$line" ]; then
    printf '%s\n' "${line#*: }"
  else
    printf 'unobserved\n'
  fi
}

harness_ensure_ignore() {
  local dest="$1"
  local gi="$dest/.gitignore"
  touch "$gi"
  grep -qxF '.workflow/' "$gi" || printf '.workflow/\n' >>"$gi"
  grep -qxF 'docs/agent-memory/' "$gi" || printf 'docs/agent-memory/\n' >>"$gi"
  grep -qxF '.pi/' "$gi" || printf '.pi/\n' >>"$gi"
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

harness_resolve_node_shebang_bin() {
  local name="$1"
  local dir cand
  local oldifs="$IFS"
  IFS=:
  for dir in $PATH; do
    IFS="$oldifs"
    cand="${dir}/${name}"
    [ -x "$cand" ] || continue
    case "$(head -n 1 "$cand")" in
    *node*)
      printf '%s\n' "$cand"
      return 0
      ;;
    esac
  done
  IFS="$oldifs"
  return 1
}

harness_collect_argv() {
  local runner="$1"
  local cwd="$2"
  local prompt="$3"
  local abs_bin="$4"
  HARNESS_ARGV=()
  while IFS= read -r line; do
    HARNESS_ARGV+=("$line")
  done < <(harness_print_argv "$runner" "$cwd" "$prompt")
  HARNESS_ARGV[0]="$abs_bin"
}

harness_run_once() {
  local runner="$1"
  local task_id="$2"
  local out_dir="$3"
  local worktree transcript prompt_file prompt hide abs_bin status model_req think_req
  local model_eff think_eff run_path stub started t0 duration

  worktree="$out_dir/worktree"
  transcript="$out_dir/transcript.txt"
  mkdir -p "$worktree" "$out_dir"
  harness_prepare_worktree "$task_id" "$worktree"
  prompt_file="$(harness_task_dir "$task_id")/prompt.md"
  [ -f "$prompt_file" ] || harness_die "missing prompt: $prompt_file"
  prompt="$(cat "$prompt_file")"

  hide="$(harness_task_field "$task_id" hide_spawn_binaries)"
  run_path="${PATH}"
  started="$(harness_iso_now)"
  t0=$SECONDS
  case "$runner" in
  pi)
    model_req="$HARNESS_PI_MODEL"
    think_req="$HARNESS_PI_THINKING"
    if [ "$hide" = "true" ]; then
      stub="$out_dir/stub-bin"
      harness_make_spawn_stubs "$stub"
      run_path="$stub:/usr/bin:/bin"
      abs_bin="$(harness_resolve_node_shebang_bin pi)" ||
        harness_die "pi with a node shebang not on PATH (refuse PATH-mutating wrappers for hide_spawn tasks)"
    else
      abs_bin="$(harness_resolve_bin pi)" || harness_die "pi not on PATH"
    fi
    harness_collect_argv pi "$worktree" "$prompt" "$abs_bin"
    set +e
    (
      cd "$worktree"
      PATH="$run_path" PI_SKIP_VERSION_CHECK=1 harness_run_bounded "$HARNESS_TIMEOUT_DEFAULT" \
        "${HARNESS_ARGV[@]}"
    ) >"$transcript" 2>&1
    status=$?
    set -e
    ;;
  grok)
    model_req="$HARNESS_GROK_MODEL"
    think_req="$HARNESS_GROK_EFFORT"
    abs_bin="$(harness_resolve_bin grok)" || harness_die "grok not on PATH"
    harness_collect_argv grok "$worktree" "$prompt" "$abs_bin"
    set +e
    PATH="$run_path" harness_run_bounded "$HARNESS_TIMEOUT_DEFAULT" \
      "${HARNESS_ARGV[@]}" >"$transcript" 2>&1
    status=$?
    set -e
    ;;
  *)
    harness_die "unknown runner: $runner"
    ;;
  esac

  model_eff="$(harness_effective_from_transcript "$transcript" "$model_req" "hunter_model")"
  think_eff="$(harness_effective_from_transcript "$transcript" "$think_req" "thinking")"
  duration=$((SECONDS - t0))
  harness_grade "$task_id" "$worktree" "$transcript" "$runner" \
    "$model_req" "$model_eff" "$think_req" "$think_eff" "$status" "$started" "$duration"
}

harness_report() {
  local file="$1"
  [ -f "$file" ] || harness_die "missing jsonl: $file"
  jq -s '
    group_by(.task_id + "/" + .runner)
    | map({
        cell: (.[0].task_id + "/" + .[0].runner),
        n: length,
        passed: ([.[] | select(.pass == true)] | length),
        pass_at_1: (([.[] | select(.pass == true)] | length) / length)
      })
  ' "$file"
}
