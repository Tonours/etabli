#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/review-private.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT
export HOME="$fixture/home" TMPDIR="$fixture/tmp"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid
export GH_TOKEN=invalid-test-token GITHUB_TOKEN=invalid-test-token GH_CONFIG_DIR="$fixture/gh-config"
export PR_COUNCIL_CLAUDE="$HOME/.local/bin/claude" PR_COUNCIL_CODEX=/usr/bin/false
export PR_REVIEW_WATCH_STATE_DIR="$fixture/state" PR_REVIEW_WATCH_COUNCIL="$fixture/council"
export PR_REVIEW_USAGE_LOG="$fixture/usage" PR_REVIEW_STOP_GRACE=1
export CALLS="$fixture/calls" ARGS="$fixture/args" WRITES="$fixture/writes"
export VIEW_FILE="$fixture/view-target"
export BASE_VIEW_FILE="$fixture/view-base"
mkdir -p "$HOME/.local/bin" "$TMPDIR" "$PR_REVIEW_WATCH_STATE_DIR/runs" "$PR_REVIEW_WATCH_STATE_DIR/reports" "$GH_CONFIG_DIR"
: >"$CALLS"; : >"$ARGS"; : >"$WRITES"
cat >"$HOME/.local/bin/gh" <<'GH'
#!/bin/bash
for arg in "$@"; do
  case "$arg" in --input|-f|-F|-X|--method|--field|--raw-field) echo "$*" >>"$WRITES"; exit 1 ;; esac
done
case "$1 $2" in
  'api user') echo "${ACTOR:-me}" ;;
  'pr view')
    [ "${FAKE_GH_FAIL:-0}" = 0 ] || exit 1
    if [ -f "$VIEW_FILE" ]; then VIEW_TARGET="$(cat "$VIEW_FILE")"; fi
    base="${BASE_REF_NAME:-main}"
    oid="$(git rev-parse "refs/remotes/origin/$base")"
    if [ -f "$BASE_VIEW_FILE" ]; then oid="$(cat "$BASE_VIEW_FILE")"; fi
    jq -cn --arg sha "${VIEW_TARGET:-$TARGET}" --arg author "${ACTOR:-me}" --arg base "$base" --arg oid "$oid" '{state:"OPEN",isDraft:false,headRefOid:$sha,baseRefName:$base,baseRefOid:$oid,author:{login:$author}}' ;;
  *) echo "unexpected gh: $*" >&2; exit 1 ;;
esac
GH
cat >"$fixture/council" <<'COUNCIL'
#!/bin/bash
echo full >>"$CALLS"
case " $* " in *' --post '*) echo forbidden >>"$WRITES"; exit 1 ;; esac
count=2; comments=2
oid="$(git rev-parse "refs/remotes/origin/${BASE_REF_NAME:-main}")"
printf 'COUNCIL_BASE ref=%s merge_base=%s base_oid=%s\n' "${BASE_REF_NAME:-main}" "$(git merge-base "$oid" "$TARGET")" "$oid"
case "${FULL_CASE:-normal}" in partial) count=5; comments=1 ;; extra) count=2; comments=3 ;; clean) count=0; comments=0 ;; esac
echo '=== phase B: /validator'
echo 'WOULD SUBMIT'
jq -n --arg sha "$TARGET" --argjson n "$comments" '{commit_id:$sha,body:(if $n==0 then "" else "Finding summary" end),comments:[range($n)|{path:"a.txt",line:1,body:("failure "+tostring)}]}'
printf '<!-- claudine:v1 {"kind":"run","run":"r1","sha":"%s","findings":%s,"floor":"should-fix","suppressed":0,"security":"clean","lenses":["done"]} -->\n' "$TARGET" "$count"
echo '=== done (validator exit 0)'
COUNCIL
cat >"$HOME/.local/bin/claude" <<'CLAUDE'
#!/bin/bash
[ "${1:-}" != --version ] || { echo 'test-cli'; exit 0; }
echo private >>"$CALLS"
printf '%s\n' "$@" >>"$ARGS"
prompt="$2"
items="$(sed -n 's/^SOURCE_ITEMS: //p' <<<"$prompt")"
source="$(sed -n 's/^SOURCE_SHA: //p' <<<"$prompt")"
[ -f "$items" ] || { echo 'private prompt has no source items' >&2; exit 1; }
[ "${PRIVATE_CASE:-normal}" != transport ] || exit 1
verdicts="$(jq --arg scenario "${PRIVATE_CASE:-normal}" '[to_entries[]|{source_index:.key,settled:(if $scenario=="retain" then .value.kind!="body" elif $scenario=="retain-comment" then .value.kind!="comment" else true end),evidence:"Read immutable target and its caller; predicate is addressed"}]' "$items")"
response="$(jq -cn --arg source "$source" --arg sha "$TARGET" --argjson verdicts "$verdicts" '{source_sha:$source,sha:$sha,complete:true,confident:true,verdicts:$verdicts,new_findings:[]}')"
case "${PRIVATE_CASE:-normal}" in
  missing) response="$(jq '.verdicts|=.[1:]' <<<"$response")" ;;
  duplicate) response="$(jq '.verdicts += [.verdicts[0]]' <<<"$response")" ;;
  evidence) response="$(jq '.verdicts[0].evidence=""' <<<"$response")" ;;
  wrongsha) response="$(jq '.sha="0000000000000000000000000000000000000000"' <<<"$response")" ;;
  wrongsource) response="$(jq '.source_sha="0000000000000000000000000000000000000000"' <<<"$response")" ;;
  uncertain) response="$(jq '.confident=false' <<<"$response")" ;;
  incomplete) response="$(jq '.complete=false|.verdicts=[]' <<<"$response")" ;;
  unverified|new)
    response="$(jq --arg v "$([ "$PRIVATE_CASE" = new ] && echo confirmed || echo unverified)" '.new_findings=[{path:"a.txt",line:1,body:"new concrete failure",severity:"medium",verification:$v}]' <<<"$response")" ;;
esac
if [ "${PRIVATE_CASE:-normal}" = oversize ]; then
  response="$(jq '.new_findings=[{path:"a.txt",line:1,body:("x"*270000),severity:"high",verification:"confirmed"}]' <<<"$response")"
fi
if [ "${PRIVATE_CASE:-normal}" = moved ]; then
  echo 0000000000000000000000000000000000000000 >"$VIEW_FILE"
fi
if [ "${PRIVATE_CASE:-normal}" = moved-base ]; then
  echo 0000000000000000000000000000000000000000 >"$BASE_VIEW_FILE"
fi
jq -c '{type:"result",subtype:"success",is_error:false,permission_denials:[],result:"Private follow-up complete",structured_output:.}' <<<"$response"
CLAUDE
chmod +x "$fixture/council" "$HOME/.local/bin/gh" "$HOME/.local/bin/claude"
git init -q --bare "$fixture/origin.git"
git init -q -b main "$fixture/repo"
cd "$fixture/repo"
git remote add origin "$fixture/origin.git"
echo root >a.txt
git add a.txt; git commit -qm root
root_sha="$(git rev-parse HEAD)"
echo base >>a.txt
git commit -qam base; git push -q origin main
echo initial >>a.txt
git commit -qam initial
initial="$(git rev-parse HEAD)"
export TARGET="$initial"
git push -q origin HEAD:refs/pull/7/head
runner="$ROOT/claude/scopes/work/scripts/pr-review-watch/review-run.sh"
key="$PR_REVIEW_WATCH_STATE_DIR/runs/o_r_7"
report_dir="$PR_REVIEW_WATCH_STATE_DIR/reports"
run_review() {
  local rc=0
  "$runner" dryrun o/r 7 "$TARGET" - url "$report_dir/o_r-7-${TARGET:0:8}-dryrun.md" "$key" >"$fixture/output" 2>&1 || rc=$?
  [ "$rc" = "${1:-0}" ] || { cat "$fixture/output" >&2; echo "expected ${1:-0}, got $rc" >&2; exit 1; }
}
next_head() {
  echo "$1" >>a.txt; git commit -qam "$1"; TARGET="$(git rev-parse HEAD)"; export TARGET
  git push -q origin HEAD:refs/pull/7/head
}
FULL_CASE=extra run_review
[ -f "$key.dryrun-last" ] || { echo 'full dry-run did not establish a private baseline' >&2; exit 1; }
next_head first-fix
PRIVATE_CASE=retain run_review
[ "$(jq .findings "$report_dir/o_r-7-${TARGET:0:8}-findings.json")" = 1 ]
next_head second-fix
run_review
[ "$(jq .findings "$report_dir/o_r-7-${TARGET:0:8}-findings.json")" = 0 ]
[ "$(grep -c '^full$' "$CALLS")" = 1 ] || { echo 'autofix reran the full council' >&2; exit 1; }
[ "$(grep -c '^private$' "$CALLS")" = 2 ]
echo 'ok initial plus two corrections uses one full council and two private passes'
# A retryable failure preserves proof and performs no full-council fallback.
next_head transport-retry
cp "$key.dryrun-last" "$fixture/saved-receipt"
PRIVATE_CASE=transport run_review 1
cmp "$key.dryrun-last" "$fixture/saved-receipt"
[ ! -e "$report_dir/o_r-7-${TARGET:0:8}-findings.json" ]
run_review
[ "$(grep -c '^full$' "$CALLS")" = 1 ]
echo 'ok retry after three successful heads preserves the bounded private path'

# A complete, confirmed new defect stays a comment, with a non-clean count.
next_head new-defect
PRIVATE_CASE=new run_review
result_file="$report_dir/o_r-7-${TARGET:0:8}-findings.json"
jq -e '.basis=="incremental" and .findings==1 and .body=="" and .comments[0].body=="new concrete failure"' "$result_file" >/dev/null

for scenario in uncertain incomplete unverified; do
  before="$(grep -c '^full$' "$CALLS")"
  next_head "$scenario"
  PRIVATE_CASE="$scenario" run_review
  [ "$(grep -c '^full$' "$CALLS")" = "$((before+1))" ]
  [ "$(jq -r .basis "$report_dir/o_r-7-${TARGET:0:8}-findings.json")" = full ]
done
echo 'ok uncertainty escalates exactly once and cannot certify a private clean result'

for scenario in missing duplicate evidence wrongsha wrongsource oversize; do
  before="$(grep -c '^full$' "$CALLS")"
  next_head "$scenario"
  PRIVATE_CASE="$scenario" run_review 4
  [ ! -e "$key.dryrun-last" ]
  [ ! -e "$report_dir/o_r-7-${TARGET:0:8}-findings.json" ]
  [ "$(grep -c '^full$' "$CALLS")" = "$before" ]
  # The scheduler stops this head; a subsequent requested changed head recovers.
  next_head "recover-$scenario"
  run_review
  [ "$(grep -c '^full$' "$CALLS")" = "$((before+1))" ]
done
echo 'ok invalid, stale and oversized output stops without a fresh artifact; changed head recovers'

# Missing/malformed proof, changed content/account and symlinks take a full run.
for scenario in partial zero-body tampered missing-source missing-receipt symlink source-symlink multi big-receipt big-source permissions actor; do
  case "$scenario" in
    partial)
      rm -f "$key.dryrun-last"
      next_head partial-source
      FULL_CASE=partial run_review
      [ ! -e "$key.dryrun-last" ] ;;
    zero-body)
      source_file="$report_dir/o_r-7-${TARGET:0:8}-findings.json"
      jq '.findings=0|.comments=[]|.body="summary"' "$source_file" >"$fixture/edited"
      chmod 600 "$fixture/edited"
      mv "$fixture/edited" "$source_file"
      /bin/bash "$ROOT/claude/scopes/work/scripts/pr-review-watch/dryrun-followup.sh" record o/r 7 "$TARGET" me "$key" "$source_file"
      [ ! -e "$key.dryrun-last" ] ;;
    tampered) printf ' ' >>"$report_dir/o_r-7-${TARGET:0:8}-findings.json" ;;
    missing-source) rm "$report_dir/o_r-7-${TARGET:0:8}-findings.json" ;;
    missing-receipt) rm "$key.dryrun-last" ;;
    symlink) mv "$key.dryrun-last" "$fixture/linked-receipt"; ln -s "$fixture/linked-receipt" "$key.dryrun-last" ;;
    source-symlink)
      source_file="$report_dir/o_r-7-${TARGET:0:8}-findings.json"
      mv "$source_file" "$fixture/linked-source"; ln -s "$fixture/linked-source" "$source_file" ;;
    multi) cat "$key.dryrun-last" >>"$fixture/extra"; cat "$fixture/extra" >>"$key.dryrun-last" ;;
    big-receipt) perl -e 'print " " x 5000' >>"$key.dryrun-last" ;;
    big-source) perl -e 'print " " x 270000' >>"$report_dir/o_r-7-${TARGET:0:8}-findings.json" ;;
    permissions) chmod 666 "$key.dryrun-last" ;;
    actor) export ACTOR=someone-else ;;
  esac
  before="$(grep -c '^full$' "$CALLS")"
  next_head "fallback-$scenario"
  run_review
  [ "$(grep -c '^full$' "$CALLS")" = "$((before+1))" ]
  unset ACTOR
done
echo 'ok incomplete, foreign, corrupted and missing baselines fall back to the full council'

# Rewritten and merged histories cannot reuse private proof.
before="$(grep -c '^full$' "$CALLS")"
git checkout -q -b rewritten main
echo rewrite >>a.txt; git commit -qam rewrite
TARGET="$(git rev-parse HEAD)"; export TARGET
git push -q --force origin HEAD:refs/pull/7/head
run_review
[ "$(grep -c '^full$' "$CALLS")" = "$((before+1))" ]
git checkout -q -b side
echo side >b.txt; git add b.txt; git commit -qm side
git checkout -q rewritten
echo another >>a.txt; git commit -qam another
git merge -q --no-ff side -m merge
TARGET="$(git rev-parse HEAD)"; export TARGET
git push -q origin HEAD:refs/pull/7/head
run_review
[ "$(grep -c '^full$' "$CALLS")" = "$((before+2))" ]
echo 'ok rewrite and merge history require complete review'

# GitHub outages must not become an expensive full fallback or consume proof.
next_head github-failure
cp "$key.dryrun-last" "$fixture/receipt-before-outage"
before="$(grep -c '^full$' "$CALLS")"
FAKE_GH_FAIL=1 run_review 1
cmp "$fixture/receipt-before-outage" "$key.dryrun-last"
[ "$(grep -c '^full$' "$CALLS")" = "$before" ]
VIEW_TARGET="$initial" run_review 1
cmp "$fixture/receipt-before-outage" "$key.dryrun-last"
[ ! -e "$report_dir/o_r-7-${TARGET:0:8}-findings.json" ]
next_head restore-baseline
run_review
next_head move-during-review
cp "$key.dryrun-last" "$fixture/receipt-before-move"
PRIVATE_CASE=moved run_review 1
cmp "$fixture/receipt-before-move" "$key.dryrun-last"
[ ! -e "$report_dir/o_r-7-${TARGET:0:8}-findings.json" ]
rm "$VIEW_FILE"
echo 'ok unreadable or moved target produces no result and no full-council loop'

# A fully clean initial council still requires a private delta review next time.
next_head clean-initial
rm -f "$key.dryrun-last"
FULL_CASE=clean run_review
[ -f "$key.dryrun-last" ]
before="$(grep -c '^private$' "$CALLS")"
next_head after-clean
run_review
[ "$(grep -c '^private$' "$CALLS")" = "$((before+1))" ]
[ "$(jq .findings "$report_dir/o_r-7-${TARGET:0:8}-findings.json")" = 0 ]
echo 'ok a clean baseline still reviews the changed code'

# A retargeted base can expose code outside the original council's diff.
before="$(grep -c '^full$' "$CALLS")"
git branch release "$root_sha"
git push -q origin release
next_head retargeted-release
BASE_REF_NAME=release run_review
[ "$(grep -c '^full$' "$CALLS")" = "$((before+1))" ]
[ "$(jq -r .base_ref "$key.dryrun-last")" = release ]
# Returning to the former ref also changes review coverage and must be full.
next_head retargeted-main
run_review
[ "$(grep -c '^full$' "$CALLS")" = "$((before+2))" ]
previous="$TARGET"
git push -q origin "$previous:refs/heads/main"
git fetch -q origin main
next_head advanced-base
run_review
[ "$(grep -c '^full$' "$CALLS")" = "$((before+3))" ]
[ "$(jq -r .merge_base "$key.dryrun-last")" = "$previous" ]
echo 'ok retargeted or advanced review base requires a new complete council'
next_head move-base-during-review
cp "$key.dryrun-last" "$fixture/receipt-before-base-move"
PRIVATE_CASE=moved-base run_review 1
cmp "$fixture/receipt-before-base-move" "$key.dryrun-last"
[ ! -e "$report_dir/o_r-7-${TARGET:0:8}-findings.json" ]
rm "$BASE_VIEW_FILE"
next_head restore-after-base-move
PRIVATE_CASE=new run_review
source_head="$TARGET"
next_head keep-old-comment
PRIVATE_CASE=retain-comment run_review
jq -e --arg source "$source_head" '.findings>0 and .body=="" and all(.comments[];.body|contains($source))' "$report_dir/o_r-7-${TARGET:0:8}-findings.json" >/dev/null
echo 'ok moved base is rejected before publication and kept comments name their original head'

# A recreated clone may have current refs but none of the old review objects.
missing_source="$TARGET"
git checkout -q -b replacement origin/main
echo replacement >>a.txt
git commit -qam replacement
TARGET="$(git rev-parse HEAD)"; export TARGET
git push -q --force origin HEAD:refs/pull/7/head
git clone -q --no-local --single-branch --branch main "$fixture/origin.git" "$fixture/replacement"
cd "$fixture/replacement"
if git cat-file -e "$missing_source^{commit}" 2>/dev/null; then
  echo 'missing-object fixture unexpectedly contains the previous review head' >&2
  exit 1
fi
before="$(grep -c '^full$' "$CALLS")"
run_review
[ "$(grep -c '^full$' "$CALLS")" = "$((before+1))" ]
[ "$(jq -r .sha "$key.dryrun-last")" = "$TARGET" ]
echo 'ok a missing historical object in a recreated clone triggers one complete council'

# The actual CLI profile, rather than the fake model, prevents model-side writes.
node - "$ARGS" <<'JS'
const fs = require('node:fs');
const args = fs.readFileSync(process.argv[2], 'utf8').split('\n');
if (!args.includes('--tools') || args[args.indexOf('--tools') + 1] !== 'Read,Grep,Glob') throw Error('read tools not restricted');
if (!args.includes('--strict-mcp-config')) throw Error('MCP not isolated');
if (args.some(a => a === '--allowedTools' || a.startsWith('--allowedTools='))) throw Error('unexpected permission grant');
JS
[ ! -s "$WRITES" ]
for forbidden in registered council-done council-clean watermark approval-pending; do [ ! -e "$key.$forbidden" ]; done
echo 'ok zero gh writes, no posting authority and read-only model tool profile'
echo 'private smoke: all scenarios passed'
