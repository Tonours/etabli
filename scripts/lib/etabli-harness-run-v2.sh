. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/etabli-harness-grade.sh"

HARNESS_PI_MODEL="zai/glm-5.3"
HARNESS_PI_THINKING="max"
HARNESS_GROK_MODEL="grok-4.7"
HARNESS_GROK_EFFORT="xhigh"
HARNESS_GROK_PERMISSION="acceptEdits"
HARNESS_TIMEOUT_DEFAULT="${ETABLI_HARNESS_EVAL_TIMEOUT:-600}"
HARNESS_SCAFFOLD_CACHE=""
HARNESS_SCAFFOLD_CACHE_DIR="${TMPDIR:-/tmp}/etabli-harness-v2-scaffold-cache"
HARNESS_GIT_TEMPLATE=""

harness_print_argv() {
  local runner="$1"
  local cwd="${2:-/tmp/etabli-harness-eval}"
  local prompt="${3:-PROMPT}"
  case "$runner" in
  pi)
    printf '%s\n' pi -p --no-session --approve \
      --model "$HARNESS_PI_MODEL" --thinking "$HARNESS_PI_THINKING" "$prompt"
    ;;
  grok)
    printf '%s\n' grok --cwd "$cwd" -m "$HARNESS_GROK_MODEL" \
      --reasoning-effort "$HARNESS_GROK_EFFORT" --permission-mode "$HARNESS_GROK_PERMISSION" \
      -p "$prompt"
    ;;
  *) harness_die "unknown runner: $runner" ;;
  esac
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
  command -v "$1" 2>/dev/null
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

harness_scaffold_template() {
  local tmp
  if [ -n "$HARNESS_SCAFFOLD_CACHE" ]; then
    printf '%s\n' "$HARNESS_SCAFFOLD_CACHE"
    return 0
  fi
  if [ ! -d "$HARNESS_SCAFFOLD_CACHE_DIR" ] ||
    ! "${HARNESS_ROOT:?}/scripts/deploy-workflow" "$HARNESS_SCAFFOLD_CACHE_DIR" --check >/dev/null 2>&1; then
    rm -rf "$HARNESS_SCAFFOLD_CACHE_DIR"
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/etabli-harness-v2-scaffold.XXXXXX")"
    "${HARNESS_ROOT:?}/scripts/deploy-workflow" "$tmp" >/dev/null
    mv "$tmp" "$HARNESS_SCAFFOLD_CACHE_DIR" 2>/dev/null || rm -rf "$tmp"
  fi
  HARNESS_SCAFFOLD_CACHE="$HARNESS_SCAFFOLD_CACHE_DIR"
  printf '%s\n' "$HARNESS_SCAFFOLD_CACHE"
}

harness_git_init() {
  local dest="$1"
  local tmpl_dir
  if [ -z "$HARNESS_GIT_TEMPLATE" ]; then
    tmpl_dir="$(mktemp -d "${TMPDIR:-/tmp}/etabli-harness-v2-git.XXXXXX")"
    HARNESS_GIT_TEMPLATE="$tmpl_dir/.git"
    git init -q "$tmpl_dir"
    rm -rf "$HARNESS_GIT_TEMPLATE/hooks"
  fi
  cp -R "$HARNESS_GIT_TEMPLATE" "$dest/.git"
}

harness_prepare_worktree() {
  local task_id="$1"
  local dest="$2"
  local task_dir
  task_dir="$(harness_task_dir "$task_id")"
  mkdir -p "$dest"
  if [ "${HARNESS_PREPARE_SCAFFOLD:-1}" != "0" ]; then
    cp -R "$(harness_scaffold_template)/." "$dest/"
  fi
  if [ -d "$task_dir/overlay" ]; then
    cp -R "$task_dir/overlay/." "$dest/"
  fi
  harness_ensure_ignore "$dest"
  harness_git_init "$dest"
  printf '[user]\n\temail = harness-eval@etabli.test\n\tname = harness-eval\n' >>"$dest/.git/config"
  git -C "$dest" add -A
  git -C "$dest" -c commit.gpgsign=false commit --allow-empty -qm 'harness-eval fixture'
  if [ -d "$task_dir/uncommitted" ]; then
    cp -R "$task_dir/uncommitted/." "$dest/"
  fi
  harness_write_baseline "$dest"
}

harness_effective_from_transcript() {
  local line
  line="$(grep -E "^$2:" "$1" | tail -n 1 || true)"
  if [ -n "$line" ]; then
    printf '%s\n' "${line#*: }"
  else
    printf 'unobserved\n'
  fi
}

harness_collect_argv() {
  local line
  HARNESS_ARGV=()
  while IFS= read -r line; do
    HARNESS_ARGV+=("$line")
  done < <(harness_print_argv "$1" "$2" "$3")
  HARNESS_ARGV[0]="$4"
}

harness_require_cell_dir_empty() {
  if [ -e "$1" ] && [ -n "$(ls -A "$1" 2>/dev/null)" ]; then
    harness_die "cell dir not empty (stale ETABLI_HARNESS_EVAL_DIR): $1"
  fi
}

harness_run_once() {
  local runner="$1" task_id="$2" out_dir="$3"
  local worktree transcript prompt_file prompt hide abs_bin status model_req think_req
  local model_eff think_eff run_path stub started t0 duration baseline_expected

  worktree="$out_dir/worktree"
  transcript="$out_dir/transcript.txt"
  harness_require_cell_dir_empty "$out_dir"
  mkdir -p "$worktree"
  harness_prepare_worktree "$task_id" "$worktree"
  baseline_expected="$(git -C "$worktree" rev-parse HEAD)"
  prompt_file="$(harness_task_dir "$task_id")/prompt.md"
  [ -f "$prompt_file" ] || harness_die "missing prompt: $prompt_file"
  prompt="$(cat "$prompt_file")"

  hide="$(harness_task_field "$task_id" hide_spawn_binaries)"
  run_path="$PATH"
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
      stub="$out_dir/spawn-bin"
      harness_make_logging_pi_wrapper "$stub" "$out_dir/spawn.log" "$abs_bin"
      run_path="$stub:$PATH"
    fi
    harness_collect_argv pi "$worktree" "$prompt" "$abs_bin"
    set +e
    (
      cd "$worktree"
      PATH="$run_path" PI_SKIP_VERSION_CHECK=1 harness_run_bounded "$HARNESS_TIMEOUT_DEFAULT" "${HARNESS_ARGV[@]}"
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
    PATH="$run_path" harness_run_bounded "$HARNESS_TIMEOUT_DEFAULT" "${HARNESS_ARGV[@]}" >"$transcript" 2>&1
    status=$?
    set -e
    ;;
  *) harness_die "unknown runner: $runner" ;;
  esac

  model_eff="$(harness_effective_from_transcript "$transcript" hunter_model)"
  think_eff="$(harness_effective_from_transcript "$transcript" thinking)"
  duration=$((SECONDS - t0))
  BASELINE_EXPECTED="$baseline_expected" SPAWN_LOG="$out_dir/spawn.log" \
    harness_grade "$task_id" "$worktree" "$transcript" "$runner" \
    "$model_req" "$model_eff" "$think_req" "$think_eff" "$status" "$started" "$duration"
}

harness_baseline_once() {
  local kind="$1" task_id="$2" out_dir="$3" started="$4"
  local worktree="$out_dir/worktree" transcript="$out_dir/transcript.txt"
  mkdir -p "$worktree"
  harness_prepare_worktree "$task_id" "$worktree"
  if [ "$kind" = "null" ]; then
    : >"$transcript"
  else
    harness_constant_baseline_transcript >"$transcript"
  fi
  BASELINE_EXPECTED="$(harness_resolved_head "$worktree")" \
    harness_grade "$task_id" "$worktree" "$transcript" "$kind" none none none none 0 "$started" 0
}

harness_baseline_suite() {
  local kind="$1" output="$2"
  local results_dir cell row cell_status id row_file started
  case "$kind" in
  null | constant) ;;
  *) harness_die "unknown baseline kind: $kind" ;;
  esac
  results_dir="${ETABLI_HARNESS_EVAL_DIR:-}"
  if [ -z "$results_dir" ]; then
    results_dir="$(mktemp -d "${TMPDIR:-/tmp}/etabli-harness-eval-v2.XXXXXX")"
  else
    mkdir -p "$results_dir"
  fi
  printf 'etabli-harness-eval-v2: keeping %s-baseline cells in %s\n' "$kind" "$results_dir" >&2
  HARNESS_PREPARE_SCAFFOLD=0
  row_file="$(mktemp "${TMPDIR:-/tmp}/etabli-harness-v2-row.XXXXXX")"
  started="$(harness_iso_now)"
  while IFS= read -r id; do
    cell="$results_dir/$kind-$id-1"
    harness_require_cell_dir_empty "$cell"
    cell_status=0
    harness_baseline_once "$kind" "$id" "$cell" "$started" >"$row_file" || cell_status=$?
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

harness_report() {
  [ -f "$1" ] || harness_die "missing jsonl: $1"
  jq -s '
    group_by(.task_id + "/" + .runner)
    | map({
        cell: (.[0].task_id + "/" + .[0].runner),
        n: length,
        passed: ([.[] | select(.pass == true)] | length),
        pass_at_1: (([.[] | select(.pass == true)] | length) / length)
      })
  ' "$1"
}
