#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/review-lifecycle.XXXXXX")"
trap 'for task_job in $(jobs -pr); do kill -TERM "$task_job" 2>/dev/null || true; wait "$task_job" 2>/dev/null || true; done; rm -rf "$fixture"' EXIT
export HOME="$fixture/home" PR_REVIEW_WATCH_STATE_DIR="$fixture/state" PR_COUNCIL_CLAUDE=/usr/bin/false PR_COUNCIL_CODEX=/usr/bin/false
mkdir -p "$HOME" "$PR_REVIEW_WATCH_STATE_DIR/runs" "$PR_REVIEW_WATCH_STATE_DIR/reports"
. "$ROOT/claude/scopes/work/scripts/pr-review-watch/watch.sh" || true
key="$RUNS/o_r_7"; sha=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
printf '%s\tcouncil\trunning\t1\n' "$sha" >"$key.status"
status_age() { echo 300; }
[ "$(running_count)" = 1 ] || { echo 'pending launch must reserve one slot'; exit 1; }
[ "$(next_attempt "$key" "$sha")" = wait ] || { echo 'missing PID must respect backoff'; exit 1; }
status_age() { echo 600; }
[ "$(next_attempt "$key" "$sha")" = 2 ]
# Immutable deliveries share one claim, including after the first has finished.
supervisor="$ROOT/claude/scopes/work/scripts/pr-review-watch/launch-run.sh"
cat >"$fixture/review-run.sh" <<'STUB'
#!/bin/bash
echo run >>"$HOME/calls"
while [ -f "$HOME/hold" ]; do sleep .05; done
exit 0
STUB
chmod +x "$fixture/review-run.sh"
run_delivery() { "$supervisor" "$key" "$1" council "$sha" 1 "$fixture/review-run.sh" "$key"; }
echo token1 >"$key.token"
run_delivery token1
run_delivery token1
[ "$(wc -l <"$HOME/calls" | tr -d ' ')" = 1 ]
# A late old-head delivery, including while paused, changes nothing.
printf '%s\tcouncil\trunning\t1\n' "$sha" >"$key.status"
echo token2 >"$key.token"; cp "$key.status" "$fixture/expected"
touch "$STATE_DIR/off"
run_delivery token1
cmp "$key.status" "$fixture/expected"
rc=0; run_delivery token2 || rc=$?
[ "$rc" = 75 ]
[ "$(cut -f3 "$key.status")" = 75 ]
[ "$(next_attempt "$key" "$sha")" = 1 ]
rm "$STATE_DIR/off"
# Failed exec is finalized with diagnostics retained by caller.
echo token3 >"$key.token"
printf '%s\tcouncil\trunning\t1\n' "$sha" >"$key.status"
rc=0
"$supervisor" "$key" token3 council "$sha" 1 "$fixture/missing" >"$fixture/exec.log" 2>&1 || rc=$?
[ "$rc" = 127 ] && [ "$(cut -f3 "$key.status")" = 127 ] && [ -s "$fixture/exec.log" ]
# A live unrelated PID cannot make a dead review look running.
printf '%s\n' "$$" >"$key.pid"
if run_alive "$key"; then echo 'unrelated PID accepted'; exit 1; fi
rm "$key.pid"
# Missing dependency fails explicitly even before normal runner work.
mkdir -p "$fixture/broken"
cp "$ROOT/claude/scopes/work/scripts/pr-review-watch/review-run.sh" "$fixture/broken/review-run.sh"
echo missing-library >"$key.token"
printf '%s\tcouncil\trunning\t1\n' "$sha" >"$key.status"
rc=0
"$supervisor" "$key" missing-library council "$sha" 1 "$fixture/broken/review-run.sh" council o/r 7 "$sha" - url "$REPORTS/missing.md" "$key" >"$fixture/library.log" 2>&1 || rc=$?
[ "$rc" = 1 ] && [ "$(cut -f3 "$key.status")" = 1 ] && [ -s "$fixture/library.log" ]
# Simultaneous delivery and another head cannot enter while owner is alive.
echo token4 >"$key.token"; touch "$HOME/hold"
printf '%s\tcouncil\trunning\t1\n' "$sha" >"$key.status"
run_delivery token4 & owner=$!
for ((i=0;i<100;i++)); do [ -f "$key.execution/pid" ] && [ -f "$key.pid" ] && break; sleep .02; done
run_delivery token4
run_alive "$key"
rm "$HOME/hold"
wait "$owner"
[ "$(wc -l <"$HOME/calls" | tr -d ' ')" = 2 ]
[ ! -e "$key.pid" ] && [ ! -d "$key.execution" ]
# Losing ownership after start cannot overwrite a newer status on exit.
touch "$HOME/hold"
echo stale-finish >"$key.token"
printf '%s\tcouncil\trunning\t1\n' "$sha" >"$key.status"
run_delivery stale-finish & owner=$!
for ((i=0;i<100;i++)); do [ "$(wc -l <"$HOME/calls" | tr -d ' ')" = 3 ] && break; sleep .02; done
echo new-head-token >"$key.token"
printf '%s\tverify\trunning\t2\n' bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb >"$key.status"
cp "$key.status" "$fixture/new-status"
rm "$HOME/hold"
wait "$owner"
cmp "$key.status" "$fixture/new-status"
# The next normal tick sees this older reservation as eligible in this fixture.
# Full launch function: ambiguous Herdr runs the command but returns failure;
# fallback delivers the same immutable token and cannot run it twice.
ensure_clone() { printf '%s' "$fixture"; }
RUNNER="$fixture/review-run.sh"
herdr_available() { return 0; }
open_review_tab() { eval "$3"; return 1; }
launch o/r 7 "$sha" url council - "$key" 1
for ((i=0;i<100;i++)); do [ "$(cut -f3 "$key.status")" = 0 ] && break; sleep .02; done
[ "$(wc -l <"$HOME/calls" | tr -d ' ')" = 4 ]
launcher="$(find "$RUNS" -name '*.launch.*' -type f | head -1)"
file_mode() {
  if stat -c %a "$1" >/dev/null 2>&1; then stat -c %a "$1"; else stat -f %Lp "$1"; fi
}
[ "$(file_mode "$launcher")" = 700 ]
[ "$(file_mode "$STATE_DIR/diagnostics")" = 700 ]
[ "$(file_mode "$(find "$STATE_DIR/diagnostics" -name '*.log' | head -1)")" = 600 ]
# Known pre-submission Herdr failure still runs headless successfully.
open_review_tab() { return 1; }
key="$RUNS/o_r_8"
launch o/r 8 "$sha" url council - "$key" 2
for ((i=0;i<100;i++)); do
  [ "$(cut -f3 "$key.status")" = 0 ] && [ ! -d "$key.execution" ] && break
  sleep .02
done
[ "$(wc -l <"$HOME/calls" | tr -d ' ')" = 5 ]
# Pre-work argument validation is captured/finalized by the supervisor.
printf '%s\tcouncil\trunning\t1\n' "$sha" >"$key.status"
echo bad-argv >"$key.token"
rc=0
"$supervisor" "$key" bad-argv council "$sha" 1 "$ROOT/claude/scopes/work/scripts/pr-review-watch/review-run.sh" council >"$fixture/argv.log" 2>&1 || rc=$?
[ "$rc" != 0 ] && [ "$(cut -f3 "$key.status")" = "$rc" ] && [ -s "$fixture/argv.log" ]
# A direct runner enters supervision, snapshots its attempt and finalizes a
# real pre-work gh failure; no model, review publication or network is invoked.
printf '%s\tcouncil\t1\t2\n' "$sha" >"$key.status"
rm -f "$key.token" "$key.claimed"
mkdir -p "$HOME/.local/bin"
printf '#!/bin/bash\nexit 1\n' >"$HOME/.local/bin/gh"
chmod +x "$HOME/.local/bin/gh"
rc=0
"$ROOT/claude/scopes/work/scripts/pr-review-watch/review-run.sh" council o/r 7 "$sha" - url "$REPORTS/report.md" "$key" >"$fixture/direct.log" 2>&1 || rc=$?
[ "$rc" = 1 ] && [ "$(cut -f3 "$key.status")" = 1 ] && [ "$(cut -f4 "$key.status")" = 2 ]
# Approve uses the same lock but neither pause nor failure rewrites attempts.
cp "$key.status" "$fixture/approve-status"
touch "$STATE_DIR/off"
rc=0
"$ROOT/claude/scopes/work/scripts/pr-review-watch/review-run.sh" approve o/r 7 "$sha" - url "$REPORTS/report.md" "$key" >"$fixture/approve.log" 2>&1 || rc=$?
[ "$rc" = 75 ]; cmp "$key.status" "$fixture/approve-status"
rm "$STATE_DIR/off"
# Clone preparation failures remain failures; valid preparation is cached.
. "$ROOT/claude/scopes/work/scripts/pr-review-watch/clones.sh"
find_clone() { return 1; }
mkdir -p "$HOME/.local/bin"
cat >"$HOME/.local/bin/gh" <<'GH'
#!/bin/bash
echo clone >>"$HOME/clone-calls"
[ "${FAIL_CLONE:-}" != yes ] || exit 1
mkdir -p "$4/.git"
GH
chmod +x "$HOME/.local/bin/gh"
if FAIL_CLONE=yes ensure_clone o/failed >/dev/null 2>&1; then echo 'failed clone accepted'; exit 1; fi
[ ! -e "$(temp_clone_dir o/failed)" ]
ensure_clone o/success >/dev/null
ensure_clone o/success >/dev/null
[ "$(wc -l <"$HOME/clone-calls" | tr -d ' ')" = 2 ]
printf '%s\tcouncil\trunning\t1\n' "$sha" >"$key.status"
status_age() { echo 300; }
repo_has_live_run o/r
status_age() { echo 600; }
if repo_has_live_run o/r; then echo 'expired reservation kept clone alive'; exit 1; fi
# Closing a PR invalidates pending delivery under the same execution lock.
printf 'o/r\t8\n' >"$WATCHED"
echo pending-close >"$key.token"
pr_snapshot() { printf 'CLOSED\tfalse\t%s\turl\ttrue\tfalse\tfalse\n' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; }
herdr_available() { return 1; }
process_watched me
[ ! -f "$key.token" ] && [ ! -f "$key.status" ]
run_delivery pending-close
[ ! -f "$key.status" ]
# Alias and canonical state keys must identify the same live run, including
# legacy/direct runners and all enumeration callers after reservation expiry.
ln -s "$STATE_DIR" "$fixture/state-alias"
alias_key="$fixture/state-alias/runs/o_r_8"
canonical_key="$(run_key o/r 8)"
for delivery_key in "$canonical_key" "$alias_key" o_r_8 ./o_r_8 ../runs/o_r_8; do
  printf '%s\tcouncil\trunning\t1\n' "$sha" >"$key.status"
  echo alias-run >"$key.token"; rm -f "$key.claimed"; touch "$HOME/hold"
  (cd "$RUNS" && "$supervisor" "$delivery_key" alias-run council "$sha" 1 "$fixture/review-run.sh" "$delivery_key") & owner=$!
  for ((i=0;i<100;i++)); do [ -f "$key.pid" ] && break; sleep .02; done
  status_age() { echo 900; }
  run_alive "$alias_key"
  run_alive "$canonical_key"
  [ "$(running_count)" = 1 ]
  repo_has_live_run o/r
  held_start="$(cat "$canonical_key.execution/start")"
  echo stale-start >"$canonical_key.execution/start"
  if execution_held "$canonical_key"; then echo 'reused owner birth accepted'; exit 1; fi
  printf '%s\n' "$held_start" >"$canonical_key.execution/start"; execution_held "$canonical_key"
  if clear_dead_execution "$canonical_key"; then echo 'live alias lock stolen'; exit 1; fi
  # Direct refusal is visible and cannot mutate the held attempt.
  cp "$key.status" "$fixture/held-status"
  rc=0
  "$ROOT/claude/scopes/work/scripts/pr-review-watch/review-run.sh" council o/r 8 "$sha" - url "$REPORTS/report.md" "$canonical_key" >"$fixture/busy.log" 2>&1 || rc=$?
  [ "$rc" = 75 ] && grep -q 'launch deferred' "$fixture/busy.log"
  cmp "$key.status" "$fixture/held-status"
  stop_everything || true
  rc=0; wait "$owner" || rc=$?
  [ "$rc" = 143 ]
  rm "$HOME/hold" "$KILL_SWITCH"
  [ ! -d "$key.execution" ]
done
# Recovery must not delete a replacement acquired after its liveness snapshot.
original_alive="$(declare -f run_alive)"
mkdir "$key.execution"; echo 999999999 >"$key.execution/pid"
run_alive() { rm -rf "$1.execution"; mkdir "$1.execution"; echo "$$" >"$1.execution/pid"; return 1; }
if clear_dead_execution "$key"; then echo 'replacement live lease erased'; exit 1; fi
[ "$(cat "$key.execution/pid")" = "$$" ]
eval "$original_alive"; rm -rf "$key.execution"
# A real pre-launch filesystem failure never claims transport submission.
mv "$STATE_DIR/diagnostics" "$fixture/saved-diagnostics"
: >"$STATE_DIR/diagnostics"
rc=0
launch o/r 8 "$sha" url council - "$key" 2 >"$fixture/fs-error.log" 2>&1 || rc=$?
[ "$rc" = 1 ] && ! grep -q submitted "$fixture/fs-error.log"
[ ! -d "$key.execution" ]
echo 'review lifecycle smoke: ok'
