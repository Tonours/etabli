#!/usr/bin/env bash
# C6: autonomous-completed profile fails incomplete ledgers and passes complete ones.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
EVENT="$ROOT_DIR/scripts/workflow-event"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DIR="$TMP/.workflow"

fail() {
  printf 'autonomous ledger hygiene smoke: %s\n' "$1" >&2
  exit 1
}

[ -x "$EVENT" ] || fail "workflow-event missing"

# Incomplete autonomous ledger (missing required events) must fail
"$EVENT" --dir "$DIR" append incomplete-auto route_decided '{"route":"plan-implement","reason":"test"}'
"$EVENT" --dir "$DIR" append incomplete-auto completed '{"summary":"too early"}'
set +e
out="$("$EVENT" --dir "$DIR" validate incomplete-auto --profile autonomous-completed 2>&1)"
status=$?
set -e
[ "$status" -ne 0 ] || fail "incomplete autonomous ledger should fail profile validation"
printf '%s\n' "$out" | grep -Eqi 'missing|requires|profile' || fail "expected profile failure message: $out"

# Complete minimal autonomous ledger should pass
"$EVENT" --dir "$DIR" append complete-auto route_decided '{"route":"plan-implement","reason":"hygiene"}'
"$EVENT" --dir "$DIR" append complete-auto plan_created '{"path":"PLAN.md","status":"READY"}'
"$EVENT" --dir "$DIR" append complete-auto adversary_completed '{"mode":"plan","verdict":"pass","accepted_findings":[],"rejected_findings":[]}'
"$EVENT" --dir "$DIR" append complete-auto file_changed '{"path":"scripts/x","change":"added"}'
"$EVENT" --dir "$DIR" append complete-auto validation_run '{"command":"true","exit":0}'
"$EVENT" --dir "$DIR" append complete-auto adversary_completed '{"mode":"code_diff","verdict":"pass","accepted_findings":[],"rejected_findings":[]}'
"$EVENT" --dir "$DIR" append complete-auto simplification_completed '{"status":"ok","evidence":"none"}'
"$EVENT" --dir "$DIR" append complete-auto review_completed '{"status":"pass","evidence":"fresh-context GO"}'
"$EVENT" --dir "$DIR" append complete-auto outcome_metric '{"outcome":"success","success":true,"measured":false,"reason":"deterministic_offline","success_kind":"task_grader","grader_success":true}'
"$EVENT" --dir "$DIR" append complete-auto archive_written '{"path":"docs/plan/example.md"}'
"$EVENT" --dir "$DIR" append complete-auto plan_removed '{"path":"PLAN.md"}'
"$EVENT" --dir "$DIR" append complete-auto completed '{"summary":"autonomous hygiene complete"}'
"$EVENT" --dir "$DIR" validate complete-auto --profile autonomous-completed >/dev/null

# Pin: implementation-loop / ship mention autonomous ledger
grep -Fq 'events.jsonl' "$ROOT_DIR/workflow/skills/implementation-loop.md" ||
  fail "implementation-loop must mention event ledger"
grep -Fq 'autonomous' "$ROOT_DIR/workflow/skills/ship.md" ||
  fail "ship skill must mention autonomous rules"

printf 'autonomous ledger hygiene smoke test: ok\n'
