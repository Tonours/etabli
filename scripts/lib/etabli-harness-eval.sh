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
  # single process: shasum only, strip the filename with a parameter
  # expansion (was shasum | awk — one fork per digest adds up over ~70
  # grade/oracle calls per smoke)
  local digest
  digest="$(shasum -a 256 "$1")"
  printf '%s\n' "${digest%% *}"
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
  # The contract requires one final line in an exact shape; the last
  # non-blank line of the transcript must be the verdict.
  grep -v '^[[:space:]]*$' "$file" | tail -n 1 | awk '
    /^Verdict: GO WITH NOTES$/ { print; exit }
    /^Verdict: BLOCK$/ { print; exit }
    /^Verdict: GO$/ { print; exit }
  '
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
  # -uall: untracked directories must not collapse into a single entry;
  # renames/copies emit both sides so an allowlisted destination cannot
  # smuggle a mutation of a non-allowlisted source.
  git -C "$WORKTREE" status --porcelain -uall | awk '{
    if ($1 == "R" || $1 == "C") {
      print $2; print $NF
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

harness_write_baseline() {
  local worktree="$1"
  git -C "$worktree" rev-parse HEAD >"$worktree.harness-baseline" 2>/dev/null
}

harness_require_head_unchanged() {
  # Preferred source: BASELINE_EXPECTED, held by the driver process and
  # passed at grade time — outside the subject's write reach. Fallback:
  # the prepare-time baseline file (offline/manual grading only).
  local expected actual
  if [ -n "${BASELINE_EXPECTED:-}" ]; then
    expected="$BASELINE_EXPECTED"
  else
    local baseline="${BASELINE_FILE:?}"
    [ -f "$baseline" ] || harness_oracle_fail "missing worktree baseline (prepare not run)"
    expected="$(head -n 1 "$baseline")"
  fi
  actual="$(git -C "$WORKTREE" rev-parse HEAD)"
  [ "$expected" = "$actual" ] ||
    harness_oracle_fail "worktree HEAD changed (commit/amend burial)"
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
  if [ -z "${HARNESS_MANIFEST_SHA_CACHE:-}" ]; then
    HARNESS_MANIFEST_SHA_CACHE="$(harness_sha256 "$(harness_manifest_path)")"
  fi
  manifest_sha="$HARNESS_MANIFEST_SHA_CACHE"
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
    BASELINE_FILE="$worktree.harness-baseline" BASELINE_EXPECTED="${BASELINE_EXPECTED:-}" \
    SPAWN_LOG="${SPAWN_LOG:-/nonexistent-spawn-log}" \
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

HARNESS_SCAFFOLD_CACHE=""
HARNESS_SCAFFOLD_CACHE_DIR="${TMPDIR:-/tmp}/etabli-harness-scaffold-cache"

harness_scaffold_template() {
  # deploy-workflow's output is static per harness checkout but costs
  # ~300ms of shell work per call. Keep one shared scaffold under TMPDIR,
  # freshness-validated with `deploy-workflow --check` (any template edit
  # self-heals the cache; the check is ~1/3 of a rebuild). Each worktree
  # still receives a full physical copy, so cells stay independent.
  local tmp
  if [ -n "$HARNESS_SCAFFOLD_CACHE" ]; then
    printf '%s\n' "$HARNESS_SCAFFOLD_CACHE"
    return 0
  fi
  if [ ! -d "$HARNESS_SCAFFOLD_CACHE_DIR" ] ||
    ! "${HARNESS_ROOT:?}/scripts/deploy-workflow" "$HARNESS_SCAFFOLD_CACHE_DIR" --check >/dev/null 2>&1; then
    rm -rf "$HARNESS_SCAFFOLD_CACHE_DIR"
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/etabli-harness-scaffold.XXXXXX")"
    "${HARNESS_ROOT:?}/scripts/deploy-workflow" "$tmp" >/dev/null
    # Atomic publish; if a concurrent run won the race its complete
    # scaffold is already in place — drop ours and reuse it.
    mv "$tmp" "$HARNESS_SCAFFOLD_CACHE_DIR" 2>/dev/null || rm -rf "$tmp"
  fi
  HARNESS_SCAFFOLD_CACHE="$HARNESS_SCAFFOLD_CACHE_DIR"
  export HARNESS_SCAFFOLD_CACHE
  printf '%s\n' "$HARNESS_SCAFFOLD_CACHE"
}

harness_prepare_worktree() {
  local task_id="$1"
  local dest="$2"
  local task_dir overlay uncommitted

  task_dir="$(harness_task_dir "$task_id")"
  overlay="$task_dir/overlay"
  uncommitted="$task_dir/uncommitted"
  mkdir -p "$dest"
  cp -R "$(harness_scaffold_template)/." "$dest/"
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
  harness_write_baseline "$dest"
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

harness_make_logging_pi_wrapper() {
  local dir="$1"
  local log_path="$2"
  local real_pi="$3"
  mkdir -p "$dir"
  # The log path and the real binary are baked into the wrapper (not in
  # the environment): a subject that never spawns pi cannot discover the
  # path from its own env. exec keeps exit code and signals transparent.
  cat >"$dir/pi" <<EOF
#!/bin/sh
printf '%s %s\n' "\$(date -u +%Y%m%dT%H%M%SZ)" "\$*" >>"$log_path"
exec "$real_pi" "\$@"
EOF
  chmod +x "$dir/pi"
}

harness_require_spawn_evidence() {
  # State-derived isolation: a transcript may claim `isolation: isolated`
  # + `runner: pi-child`, but on a task where pi is reachable the claim is
  # only worth what the spawn log proves. The log lives in the cell dir,
  # written exclusively by the PATH wrapper, and a valid line must carry the
  # hunter argv markers from the contract (`--no-session` and
  # `--append-system-prompt`): a generic forged line without the hunter
  # invocation shape fails. Ceiling (documented): a fabricator that knows
  # the contract argv can still forge the line — the load-bearing cells
  # (final-state SHA, GO-only) do not depend on this evidence.
  local log="${SPAWN_LOG:-}"
  [ -n "$log" ] || harness_oracle_fail "spawn evidence required but SPAWN_LOG not provided (driver misuse)"
  [ -s "$log" ] ||
    harness_oracle_fail "transcript claims an isolated child hunt but no pi spawn was observed"
  grep -Eq -- '--no-session.*--append-system-prompt|--append-system-prompt.*--no-session' "$log" ||
    harness_oracle_fail "spawn log has no hunter invocation (needs --no-session and --append-system-prompt on one line)"
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
  local model_eff think_eff run_path stub started t0 duration baseline_expected

  worktree="$out_dir/worktree"
  transcript="$out_dir/transcript.txt"
  harness_require_cell_dir_empty "$out_dir"
  mkdir -p "$worktree" "$out_dir"
  harness_prepare_worktree "$task_id" "$worktree"
  # Driver-held baseline: never written inside the cell, so a subject with
  # write access cannot overwrite the pin (file fallback stays for offline
  # grade invocations).
  baseline_expected="$(git -C "$worktree" rev-parse HEAD)"
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
      # Spawn-evidence wrapper: pi stays reachable, but every invocation is
      # logged outside the worktree so `isolation: isolated` claims become
      # state-derived instead of self-declared.
      stub="$out_dir/spawn-bin"
      harness_make_logging_pi_wrapper "$stub" "$out_dir/spawn.log" "$abs_bin"
      run_path="$stub:${PATH}"
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
  BASELINE_EXPECTED="$baseline_expected" SPAWN_LOG="$out_dir/spawn.log" \
    harness_grade "$task_id" "$worktree" "$transcript" "$runner" \
    "$model_req" "$model_eff" "$think_req" "$think_eff" "$status" "$started" "$duration"
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

harness_constant_baseline_once() {
  local task_id="$1" out_dir="$2"
  local worktree transcript
  worktree="$out_dir/worktree"
  transcript="$out_dir/transcript.txt"
  mkdir -p "$worktree" "$out_dir"
  harness_prepare_worktree "$task_id" "$worktree"
  harness_constant_baseline_transcript >"$transcript"
  harness_grade "$task_id" "$worktree" "$transcript" "constant" none none none none 0 "$(harness_iso_now)" 0
}

harness_require_cell_dir_empty() {
  local cell="$1"
  if [ -e "$cell" ] && [ -n "$(ls -A "$cell" 2>/dev/null)" ]; then
    harness_die "cell dir not empty (stale ETABLI_HARNESS_EVAL_DIR): $cell"
  fi
}

harness_baseline_suite() {
  local kind="$1"
  local output="$2"
  local results_dir cell row cell_status id row_file
  case "$kind" in
  null | constant) ;;
  *) harness_die "unknown baseline kind: $kind" ;;
  esac
  results_dir="${ETABLI_HARNESS_EVAL_DIR:-}"
  if [ -z "$results_dir" ]; then
    results_dir="$(mktemp -d "${TMPDIR:-/tmp}/etabli-harness-eval.XXXXXX")"
  else
    mkdir -p "$results_dir"
  fi
  printf 'etabli-harness-eval: keeping %s-baseline cells in %s\n' "$kind" "$results_dir" >&2
  harness_scaffold_template >/dev/null # pre-warm: cells run via redirection
  # Cells run in this shell (output redirected to a file, not captured in
  # a $() subshell) so per-process caches like HARNESS_MANIFEST_SHA_CACHE
  # survive from cell to cell.
  row_file="$(mktemp "${TMPDIR:-/tmp}/etabli-harness-row.XXXXXX")"
  while IFS= read -r id; do
    cell="$results_dir/$kind-$id-1"
    harness_require_cell_dir_empty "$cell"
    cell_status=0
    : >"$row_file"
    if [ "$kind" = "null" ]; then
      harness_null_baseline_once "$id" "$cell" >"$row_file" || cell_status=$?
    else
      harness_constant_baseline_once "$id" "$cell" >"$row_file" || cell_status=$?
    fi
    row="$(<"$row_file")"
    [ "$cell_status" -eq 0 ] && [ -n "$row" ] || harness_die "$kind-baseline cell failed: $id"
    if [ -n "$output" ]; then
      printf '%s\n' "$row" >>"$output"
    else
      printf '%s\n' "$row"
    fi
  done < <(harness_task_ids)
  rm -f "$row_file"
}

harness_null_baseline_once() {
  local task_id="$1" out_dir="$2"
  local worktree transcript
  worktree="$out_dir/worktree"
  transcript="$out_dir/transcript.txt"
  mkdir -p "$worktree" "$out_dir"
  harness_prepare_worktree "$task_id" "$worktree"
  : >"$transcript"
  harness_grade "$task_id" "$worktree" "$transcript" "null" none none none none 0 "$(harness_iso_now)" 0
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
