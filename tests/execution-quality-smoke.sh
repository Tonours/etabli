#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASK_TMP="$(mktemp -d)"
trap 'rm -rf "$TASK_TMP"' EXIT
. "$ROOT_DIR/scripts/lib/hash.sh"
mkdir -p "$TASK_TMP/docs/plan"
cp "$ROOT_DIR/tests/fixtures/execution-quality/ready-plan.md" "$TASK_TMP/PLAN.md"
ledger="$TASK_TMP/.workflow/eq/events.jsonl"
pointer="$TASK_TMP/.workflow/active-run.json"
event() { WORKFLOW_EVENT_PROJECT_ROOT="$TASK_TMP" "$ROOT_DIR/scripts/workflow-event" --dir "$TASK_TMP/.workflow" "$@"; }
contract_hash() { node "$ROOT_DIR/scripts/plan-review-check" --hash "$TASK_TMP/PLAN.md"; }
unchanged() { cmp "$ledger" "$TASK_TMP/ledger.before"; cmp "$pointer" "$TASK_TMP/pointer.before"; }
refused() {
 local rc=0
 event "$@" >"$TASK_TMP/refused.stdout" 2>"$TASK_TMP/refused.stderr" || rc=$?
 [ "$rc" -eq 1 ] || { cat "$TASK_TMP/refused.stderr" >&2; exit 1; }
 unchanged
}
PROV='{"requested":{"family":"fixture","model":"fixture","provider":"fixture"},"effective":{"family":"fixture","model":"fixture","provider":"fixture"},"runner":"fixture","run_id":"eq"}'
review() { jq -nc --arg hash "$1" --arg verdict "$2" --argjson p "$PROV" '{mode:"plan",verdict:$verdict,plan_contract_sha256:$hash,accepted_findings:[],rejected_findings:[],model_provenance:$p}'; }
event append eq route_decided '{"route":"plan-implement","reason":"bound fixture"}'
event append eq plan_created '{"path":"PLAN.md","status":"READY"}'
event activate eq >/dev/null
reviewed="$(contract_hash)"
jq -s -e --arg hash "$reviewed" '[.[] | select(.event=="plan_created")] | last | .detail.plan_contract_sha256==$hash' "$ledger" >/dev/null
cp "$ledger" "$TASK_TMP/ledger.before"; cp "$pointer" "$TASK_TMP/pointer.before"
missing="$(review "$reviewed" READY | jq -c 'del(.plan_contract_sha256)')"
refused append eq adversary_completed "$missing"
grep -Fq 'missing or stale plan_contract_sha256' "$TASK_TMP/refused.stderr"
printf '\n## Additional decision\n- Require neighboring caller cases.\n' >>"$TASK_TMP/PLAN.md"
[ "$(contract_hash)" != "$reviewed" ]
refused append eq adversary_completed "$(review "$reviewed" READY)"
current="$(contract_hash)"
# One newly bound plan traverses the isolated runner -> writer.
run_dir="$TASK_TMP/.workflow/eq"
mkdir -p "$TASK_TMP/bin"
printf 'Review this fixture plan and return a canonical verdict.\n' >"$run_dir/prompt.md"
cp "$TASK_TMP/PLAN.md" "$run_dir/plan.patch"
printf '#!/usr/bin/env bash\nprintf "Verdict: READY\\n"\n' >"$TASK_TMP/bin/pi"
chmod +x "$TASK_TMP/bin/pi"
PATH="$TASK_TMP/bin:$PATH" bash "$ROOT_DIR/scripts/pi-review-hunter" --prompt-file "$run_dir/prompt.md" --patch "$run_dir/plan.patch" --timeout 60 >"$run_dir/verdict.txt"
grep -Fxq 'Verdict: READY' "$run_dir/verdict.txt"
captured="$(jq -nc --arg hash "$current" --rawfile v "$run_dir/verdict.txt" --argjson p "$PROV" '{mode:"plan",verdict:($v|sub("^Verdict: ";"")|rtrimstr("\n")),plan_contract_sha256:$hash,accepted_findings:[],rejected_findings:[],model_provenance:($p+{runner:"fixture-pi",run_id:"eq-plan"})}')"
event append eq adversary_completed "$captured"
event append eq adversary_completed "$(review "$current" CHALLENGED)"
event append eq adversary_completed "$(review "$current" READY)"
printf 'export const fixture = true;\n' >"$TASK_TMP/app.mjs"
node --check "$TASK_TMP/app.mjs"
event append eq file_changed '{"path":"app.mjs","change":"fixture implementation"}'
printf '# Ordinary note\n' >"$TASK_TMP/docs/plain.md"
event append eq file_changed '{"path":"docs/plain.md","change":"ordinary document"}'
# File-change observations survive unavailable plan identity, including notes
# and historical archives under the archive directory.
cp "$TASK_TMP/PLAN.md" "$TASK_TMP/plan.before-observation"
printf '# Ordinary archive-directory note\n' >"$TASK_TMP/docs/plan/observed.md"
event append eq file_changed '{"path":"docs/plan/observed.md","change":"ordinary document with valid plan"}'
for damaged in utf8 nul symlink; do
 rm -f "$TASK_TMP/PLAN.md"
 case "$damaged" in
  utf8) printf '\377' >"$TASK_TMP/PLAN.md" ;;
  nul) printf '\0' >"$TASK_TMP/PLAN.md" ;;
  symlink) ln -s "$TASK_TMP/plan.before-observation" "$TASK_TMP/PLAN.md" ;;
 esac
 for observed in docs/plain.md docs/plan/observed.md; do
  event append eq file_changed "$(jq -nc --arg path "$observed" --arg mode "$damaged" '{path:$path,change:("observation with unavailable plan: " + $mode)}')" >"$TASK_TMP/observation.stdout" 2>"$TASK_TMP/observation.stderr"
 done
done
rm -f "$TASK_TMP/PLAN.md"
printf '\377' >"$TASK_TMP/PLAN.md"
printf '# Implemented: historical record\n\n- Source plan: `PLAN.md`\n- Source plan SHA-256: `%064d`\n- Status: IMPLEMENTED\n' 0 >"$TASK_TMP/docs/plan/historical.md"
event append eq file_changed '{"path":"docs/plan/historical.md","change":"historical document while plan unavailable"}' >"$TASK_TMP/observation.stdout" 2>"$TASK_TMP/observation.stderr"
mv -f "$TASK_TMP/plan.before-observation" "$TASK_TMP/PLAN.md"
[ "$(contract_hash)" = "$current" ]
event append eq validation_run '{"command":"node --check app.mjs","exit":0}'
event append eq simplification_completed '{"status":"clean","evidence":"fixture diff"}'
event append eq quality_completed '{"status":"pass","evidence":"fixture diff"}'
event append eq adversary_completed "$(jq -nc --argjson p "$PROV" '{mode:"code_diff",verdict:"GO",accepted_findings:[],rejected_findings:[],model_provenance:$p}')"
event append eq review_completed '{"status":"GO","evidence":"fixture","review_round":"T1","round_outcome":"clean"}'
source_hash="$(hash256 "$TASK_TMP/PLAN.md" | awk '{print $1}')"
printf '# Implemented: fixture\n\n- Source plan: `PLAN.md`\n- Source plan SHA-256: `%s`\n- Status: IMPLEMENTED\n' "$source_hash" >"$TASK_TMP/docs/plan/fixture.md"
cp "$ledger" "$TASK_TMP/ledger.before"; cp "$pointer" "$TASK_TMP/pointer.before"
refused append eq file_changed '{"path":"docs/plan/fixture.md","change":"archive"}'
grep -Fq 'use archive_written' "$TASK_TMP/refused.stderr"
event append eq archive_written '{"path":"docs/plan/fixture.md"}'
(cd "$TASK_TMP"; node "$ROOT_DIR/scripts/plan-cleanup" --archive docs/plan/fixture.md >/dev/null)
event append eq plan_removed '{"path":"PLAN.md"}'
event append eq completed '{"summary":"bound fixture closed"}'
event validate eq --profile autonomous-completed >/dev/null
[ ! -e "$TASK_TMP/PLAN.md" ] && [ ! -e "$pointer" ]
jq -s -e '([.[] | select(.event=="review_completed") | .detail.review_round]==["T1"]) and ([.[] | select(.event=="file_changed")] | length==10) and ([.[] | select(.event=="file_changed") | .detail.path] | unique)==(["app.mjs","docs/plain.md","docs/plan/observed.md","docs/plan/historical.md"] | sort) and (.[-3:] | map(.event)==["archive_written","plan_removed","completed"])' "$ledger" >/dev/null
printf 'execution quality smoke: writer, archive and terminal chain passed (fixtures)\n'
