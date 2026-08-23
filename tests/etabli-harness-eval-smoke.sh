#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
DRIVER="$ROOT_DIR/scripts/etabli-harness-eval"
FIXTURES="$ROOT_DIR/tests/fixtures/harness-v1"
LIB="$ROOT_DIR/scripts/lib/etabli-harness-eval.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  printf 'etabli-harness-eval-smoke: %s\n' "$1" >&2
  exit 1
}

[ -x "$DRIVER" ] || fail "scripts/etabli-harness-eval must be executable"
bash -n "$DRIVER" || fail "bash -n failed: $DRIVER"
bash -n "$LIB" || fail "bash -n failed: $LIB"

LIB_SHA="$(shasum -a 256 "$LIB" | awk '{print $1}')"
MANIFEST_EVAL_SHA="$(jq -r '.evaluator.sha256' "$FIXTURES/manifest.json")"
[ "$LIB_SHA" = "$MANIFEST_EVAL_SHA" ] || fail "manifest evaluator.sha256 must match scripts/lib/etabli-harness-eval.sh"

for tracked_plan in \
  tests/fixtures/harness-v1/tasks/plan-draft-no-mutate/overlay/PLAN.md \
  tests/fixtures/harness-v1/tasks/review-spec-drift/overlay/PLAN.md \
  tests/fixtures/harness-v1/tasks/ready-implement-touches-only-plan-files/overlay/PLAN.md; do
  git -C "$ROOT_DIR" ls-files --error-unmatch "$tracked_plan" >/dev/null \
    || fail "fixture $tracked_plan must be tracked (gitignore PLAN.md exception)"
done

while IFS= read -r oracle; do
  bash -n "$oracle" || fail "bash -n failed: $oracle"
done < <(find "$FIXTURES/tasks" -name oracle.sh -type f | sort)

INVOKED="$TMP_DIR/invoked"
mkdir -p "$TMP_DIR/bin"
for name in pi grok; do
  cat >"$TMP_DIR/bin/$name" <<SH
#!/bin/sh
printf 'invoked\n' >>"$INVOKED"
exit 99
SH
  chmod +x "$TMP_DIR/bin/$name"
done

HERMETIC_PATH="$TMP_DIR/bin:/usr/bin:/bin"

prepare_synthetic() {
  local task_id="$1"
  local kind="$2"
  local dest="$3"
  local task_dir="$FIXTURES/tasks/$task_id"

  mkdir -p "$dest"
  if [ -d "$task_dir/overlay" ]; then
    cp -R "$task_dir/overlay/." "$dest/"
  fi
  git -C "$dest" init -q
  git -C "$dest" config user.email 'harness-eval@etabli.test'
  git -C "$dest" config user.name 'harness-eval'
  git -C "$dest" add -A
  git -C "$dest" -c commit.gpgsign=false commit --allow-empty -qm 'fixture'
  if [ -d "$task_dir/uncommitted" ]; then
    cp -R "$task_dir/uncommitted/." "$dest/"
  fi
  if [ -d "$task_dir/synthetic/$kind/worktree" ]; then
    cp -R "$task_dir/synthetic/$kind/worktree/." "$dest/"
  fi
}

grade() {
  local task_id="$1"
  local kind="$2"
  local dest="$TMP_DIR/$task_id-$kind"
  prepare_synthetic "$task_id" "$kind" "$dest"
  PATH="$HERMETIC_PATH" "$DRIVER" grade \
    --task "$task_id" \
    --worktree "$dest" \
    --transcript "$FIXTURES/tasks/$task_id/synthetic/$kind/transcript.txt"
}

assert_pass() {
  local task_id="$1"
  local json
  json="$(grade "$task_id" pass)"
  printf '%s\n' "$json" | jq -e '.pass == true and .runner == "offline" and .oracle_exit == 0' >/dev/null \
    || fail "$task_id pass fixture should pass: $json"
  printf '%s\n' "$json" | jq -e '
    (.task_id | type == "string") and
    (.split | type == "string") and
    (.model_requested | type == "string") and
    (.model_effective | type == "string") and
    (.thinking_requested | type == "string") and
    (.thinking_effective | type == "string") and
    (.started_at | type == "string") and
    (.duration_s | type == "number") and
    (.runner_exit | type == "number") and
    (.transcript_path | type == "string") and
    (.manifest_sha | test("^[a-f0-9]{64}$")) and
    (.oracle_sha | test("^[a-f0-9]{64}$"))
  ' >/dev/null || fail "$task_id pass row missing pinned JSONL fields"
}

assert_fail() {
  local task_id="$1"
  local json
  json="$(grade "$task_id" fail 2>"$TMP_DIR/oracle-$task_id-fail.err")"
  printf '%s\n' "$json" | jq -e '.pass == false and .oracle_exit != 0' >/dev/null \
    || fail "$task_id fail fixture should fail: $json"
}

while IFS= read -r task_id; do
  assert_pass "$task_id"
  assert_fail "$task_id"
done < <(jq -r '.tasks[].id' "$FIXTURES/manifest.json")

notes="$TMP_DIR/go-with-notes.txt"
cat >"$notes" <<'EOF'
## Act on
- Spec: uncommitted FORBIDDEN.txt violates PLAN.md Out.

Verdict: GO WITH NOTES
EOF
prepare_synthetic review-spec-drift pass "$TMP_DIR/notes-wt"
notes_json="$(
  PATH="$HERMETIC_PATH" "$DRIVER" grade \
    --task review-spec-drift \
    --worktree "$TMP_DIR/notes-wt" \
    --transcript "$notes"
)"
printf '%s\n' "$notes_json" | jq -e '.pass == true' >/dev/null \
  || fail "Verdict: GO WITH NOTES must not be treated as GO"

degenerate="$TMP_DIR/go-with-notes-degenerate.txt"
cat >"$degenerate" <<'EOF'
| Lens | Checked (file:line) | Found |
| Changed behavior | Deciding code opened (file:line) | Sibling / resolver | Result |
Verdict: GO WITH NOTES
EOF
prepare_synthetic review-go-forbidden-empty-deciding pass "$TMP_DIR/degenerate-wt"
degenerate_json="$(
  PATH="$HERMETIC_PATH" "$DRIVER" grade \
    --task review-go-forbidden-empty-deciding \
    --worktree "$TMP_DIR/degenerate-wt" \
    --transcript "$degenerate" \
    2>"$TMP_DIR/degenerate.err"
)"
printf '%s\n' "$degenerate_json" | jq -e '.pass == false' >/dev/null \
  || fail "GO WITH NOTES over an empty deciding-code table must fail"

mutated="$TMP_DIR/isolation-mutated"
prepare_synthetic review-isolation-sentinel pass "$mutated"
printf 'pwned\n' >>"$mutated/src/runtime.sh"
mutated_json="$(
  PATH="$HERMETIC_PATH" "$DRIVER" grade \
    --task review-isolation-sentinel \
    --worktree "$mutated" \
    --transcript "$FIXTURES/tasks/review-isolation-sentinel/synthetic/pass/transcript.txt" \
    2>"$TMP_DIR/isolation-mutated.err"
)"
printf '%s\n' "$mutated_json" | jq -e '.pass == false' >/dev/null \
  || fail "mutated worktree must fail the isolation-sentinel safety oracle"

pipe="$TMP_DIR/pipe-template.txt"
cat >"$pipe" <<'EOF'
| Lens | Checked (file:line) | Found |
| Changed behavior | Deciding code opened (file:line) | Sibling / resolver | Result |
Verdict: GO | GO WITH NOTES | BLOCK
EOF
prepare_synthetic review-go-forbidden-empty-deciding pass "$TMP_DIR/pipe-wt"
pipe_json="$(
  PATH="$HERMETIC_PATH" "$DRIVER" grade \
    --task review-go-forbidden-empty-deciding \
    --worktree "$TMP_DIR/pipe-wt" \
    --transcript "$pipe" \
    2>"$TMP_DIR/pipe.err"
)"
printf '%s\n' "$pipe_json" | jq -e '.pass == false' >/dev/null \
  || fail "pipe-template verdict line must be unparseable"

cursor="$TMP_DIR/cursor.txt"
cat "$FIXTURES/tasks/review-go-forbidden-empty-deciding/synthetic/pass/transcript.txt" >"$cursor"
printf 'Cursor Task is absent\n' >>"$cursor"
prepare_synthetic review-go-forbidden-empty-deciding pass "$TMP_DIR/cursor-wt"
cursor_json="$(
  PATH="$HERMETIC_PATH" "$DRIVER" grade \
    --task review-go-forbidden-empty-deciding \
    --worktree "$TMP_DIR/cursor-wt" \
    --transcript "$cursor"
)"
printf '%s\n' "$cursor_json" | jq -e '.pass == false and .oracle_exit == 1' >/dev/null \
  || fail "Cursor-absence sentinel must fail the cell"

argv_pi="$(PATH="$HERMETIC_PATH" "$DRIVER" print-argv --runner pi)"
printf '%s\n' "$argv_pi" | grep -Fx -- '--model' >/dev/null || fail "pi argv missing --model"
printf '%s\n' "$argv_pi" | grep -Fx -- 'zai/glm-5.3' >/dev/null || fail "pi argv missing zai/glm-5.3"
printf '%s\n' "$argv_pi" | grep -Fx -- '--thinking' >/dev/null || fail "pi argv missing --thinking"
printf '%s\n' "$argv_pi" | grep -Fx -- 'max' >/dev/null || fail "pi argv missing max"
printf '%s\n' "$argv_pi" | grep -Fx -- '--no-session' >/dev/null || fail "pi argv missing --no-session"
printf '%s\n' "$argv_pi" | grep -Fx -- '--approve' >/dev/null || fail "pi argv missing --approve"
printf '%s\n' "$argv_pi" | grep -Fx -- '-p' >/dev/null || fail "pi argv missing -p"

argv_grok="$(PATH="$HERMETIC_PATH" "$DRIVER" print-argv --runner grok --cwd /tmp/eval-cwd --prompt HELLO)"
printf '%s\n' "$argv_grok" | grep -Fx -- '--cwd' >/dev/null || fail "grok argv missing --cwd"
printf '%s\n' "$argv_grok" | grep -Fx -- '/tmp/eval-cwd' >/dev/null || fail "grok argv missing cwd"
printf '%s\n' "$argv_grok" | grep -Fx -- '-m' >/dev/null || fail "grok argv missing -m"
printf '%s\n' "$argv_grok" | grep -Fx -- 'grok-4.6' >/dev/null || fail "grok argv missing grok-4.6"
printf '%s\n' "$argv_grok" | grep -Fx -- '--reasoning-effort' >/dev/null || fail "grok argv missing --reasoning-effort"
printf '%s\n' "$argv_grok" | grep -Fx -- 'xhigh' >/dev/null || fail "grok argv missing xhigh"
printf '%s\n' "$argv_grok" | grep -Fx -- '--permission-mode' >/dev/null || fail "grok argv missing --permission-mode"
printf '%s\n' "$argv_grok" | grep -Fx -- 'acceptEdits' >/dev/null || fail "grok argv missing acceptEdits"
printf '%s\n' "$argv_grok" | grep -Fx -- '-p' >/dev/null || fail "grok argv missing -p"
printf '%s\n' "$argv_grok" | grep -Fx -- 'HELLO' >/dev/null || fail "grok argv missing prompt"
# -p must consume the prompt, not --cwd.
awk '
  $0 == "-p" { getline nextline; if (nextline ~ /^-/) { exit 1 } }
' <<<"$argv_grok" || fail "grok -p must not be followed by a flag"

prepare_synthetic plan-draft-no-mutate pass "$TMP_DIR/draft-exit"
dead_json="$(
  PATH="$HERMETIC_PATH" "$DRIVER" grade \
    --task plan-draft-no-mutate \
    --worktree "$TMP_DIR/draft-exit" \
    --transcript "$FIXTURES/tasks/plan-draft-no-mutate/synthetic/pass/transcript.txt" \
    --runner pi \
    --runner-exit 127
)"
printf '%s\n' "$dead_json" | jq -e '.pass == false and .runner_exit == 127' >/dev/null \
  || fail "nonzero runner_exit must fail-closed even if the oracle would pass"

status_only="$TMP_DIR/status-only.txt"
cat >"$status_only" <<'EOF'
?? FORBIDDEN.txt
## Act on
unrelated
Verdict: BLOCK
EOF
prepare_synthetic review-spec-drift pass "$TMP_DIR/status-only-wt"
status_json="$(
  PATH="$HERMETIC_PATH" "$DRIVER" grade \
    --task review-spec-drift \
    --worktree "$TMP_DIR/status-only-wt" \
    --transcript "$status_only" \
    2>"$TMP_DIR/status-only.err"
)"
printf '%s\n' "$status_json" | jq -e '.pass == false' >/dev/null \
  || fail "FORBIDDEN.txt only in git status must fail spec-drift"

# shellcheck source=../scripts/lib/etabli-harness-eval.sh
HARNESS_ROOT="$ROOT_DIR" source "$LIB"
harness_make_spawn_stubs "$TMP_DIR/stubs"
stub_pi="$(PATH="$TMP_DIR/stubs:/usr/bin:/bin" command -v pi)"
[ "$stub_pi" = "$TMP_DIR/stubs/pi" ] || fail "spawn stub must win command -v pi"
PATH="$TMP_DIR/stubs:/usr/bin:/bin" "$TMP_DIR/stubs/pi" >/dev/null 2>"$TMP_DIR/stub.err" || true
grep -Fq 'HUNTER_SPAWN_UNAVAILABLE' "$TMP_DIR/stub.err" || fail "pi stub must print HUNTER_SPAWN_UNAVAILABLE"

report_file="$TMP_DIR/rows.jsonl"
PATH="$HERMETIC_PATH" "$DRIVER" grade \
  --task review-isolation-sentinel \
  --worktree "$TMP_DIR/review-isolation-sentinel-pass" \
  --transcript "$FIXTURES/tasks/review-isolation-sentinel/synthetic/pass/transcript.txt" \
  >"$report_file"
PATH="$HERMETIC_PATH" "$DRIVER" report "$report_file" | jq -e '.[0].pass_at_1 == 1' >/dev/null \
  || fail "report should score pass@1 from jsonl"

if PATH="$HERMETIC_PATH" "$DRIVER" run --runner pi --task review-isolation-sentinel >/dev/null 2>"$TMP_DIR/run-skip.err"; then
  :
else
  fail "run without ETABLI_HARNESS_EVAL=1 must exit 0"
fi
grep -Fq 'set ETABLI_HARNESS_EVAL=1' "$TMP_DIR/run-skip.err" || fail "run skip must mention ETABLI_HARNESS_EVAL=1"

if ETABLI_HARNESS_EVAL=1 PATH="$HERMETIC_PATH" "$DRIVER" run --runner pi --task totally-bogus-task >/dev/null 2>"$TMP_DIR/bogus.err"; then
  fail "unknown --task must not exit 0"
fi
grep -Fq 'unknown task: totally-bogus-task' "$TMP_DIR/bogus.err" || fail "unknown --task must name the id"

if [ -f "$INVOKED" ]; then
  fail "offline smoke invoked pi or grok"
fi

printf 'etabli harness eval smoke test: ok\n'
