#!/usr/bin/env bash
# Runtime receipts + autonomous-completed-strict profile + self-improvement
# provenance integrity.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
EVENT="$ROOT_DIR/scripts/workflow-event"
INTEGRITY="$ROOT_DIR/scripts/workflow-self-improvement-integrity"
RECEIPTS="$ROOT_DIR/scripts/lib/workflow-receipts.mjs"
MANIFEST="$ROOT_DIR/workflow/self-improvement/manifests/core-v1.json"
STRICT_MANIFEST="$ROOT_DIR/workflow/self-improvement/manifests/core-v2.json"
. "$ROOT_DIR/scripts/lib/hash.sh"
TMP_DIR="$(mktemp -d)"
EVENT_DIR="$TMP_DIR/.workflow"
export RECEIPTS_LIB="$RECEIPTS"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
	printf 'workflow-receipts smoke: %s\n' "$1" >&2
	exit 1
}

expect_status() {
	local expected="$1"
	shift
	set +e
	output="$("$@" 2>&1)"
	status=$?
	set -e
	[ "$status" -eq "$expected" ] || fail "expected status $expected, got $status: $output"
	printf '%s' "$output"
}

assert_contains() {
	case "$1" in *"$2"*) ;; *) fail "expected '$2' in: $1" ;; esac
}

# emit <slug> <event> <json>
emit() {
	"$EVENT" --dir "$EVENT_DIR" append "$@"
}

EVAL_SHA="$(jq -r .evaluator.sha256 "$MANIFEST")"
STRICT_MANIFEST_SHA="$(hash256 "$STRICT_MANIFEST" | awk '{print $1}')"
STRICT_BUNDLE_SHA="$(jq -r .evaluator.bundle.sha256 "$STRICT_MANIFEST")"

[ -x "$EVENT" ] || fail "missing workflow-event"
[ -x "$INTEGRITY" ] || fail "missing integrity validator"
jq -e '.visibility == "frozen_public" and .external_isolated_evaluator == "blocked"' "$MANIFEST" >/dev/null ||
	fail "manifest must stay frozen_public with a blocked external evaluator"

# --- runtime_receipt schema: valid accepted, bad rejected ---
emit rcpt-ok runtime_receipt \
	'{"receipt_for":"validation_run","source":"Bash","kind":"validation","subject_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","exit":0,"observed_by":"parent-process","cryptographic":false}'
out="$(expect_status 2 "$EVENT" --dir "$EVENT_DIR" append rcpt-bad runtime_receipt \
	'{"receipt_for":"x","source":"Bash","kind":"validation","subject_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","observed_by":"parent-process","cryptographic":true}')"
assert_contains "$out" "required fields"
out="$(expect_status 2 "$EVENT" --dir "$EVENT_DIR" append rcpt-bad2 runtime_receipt \
	'{"receipt_for":"x","source":"Bash","kind":"nope","subject_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","observed_by":"parent-process","cryptographic":false}')"
assert_contains "$out" "required fields"

# --- receipts helper hashes the subject and never stores raw text ---
node --input-type=module <<'EOF'
import { pathToFileURL } from "node:url";
const mod = await import(pathToFileURL(process.env.RECEIPTS_LIB).href);
const detail = mod.buildReceipt({
  receiptFor: "validation_run",
  source: "Bash",
  kind: "validation",
  subject: "bash tests/secret-command.sh",
  exit: 0,
});
const json = JSON.stringify(detail);
if (json.includes("secret-command")) { console.error("receipt leaked raw subject text: " + json); process.exit(1); }
if (detail.cryptographic !== false || detail.observed_by !== "parent-process") { console.error("bad label: " + json); process.exit(1); }
if (!/^[a-f0-9]{64}$/.test(detail.subject_sha256)) { console.error("bad sha: " + detail.subject_sha256); process.exit(1); }
console.log("receipt helper ok");
EOF

node --input-type=module <<'EOF' >/dev/null
import { pathToFileURL } from "node:url";
const mod = await import(pathToFileURL(process.env.RECEIPTS_LIB).href);
try { mod.buildReceipt({ receiptFor: "x", source: "Bash", kind: "validation", subject: "" }); }
catch { process.exit(0); }
console.error("empty subject should throw"); process.exit(1);
EOF

# --- autonomous-completed-strict requires a runtime_receipt per kind ---
SLUG="strict-run"
emit "$SLUG" route_decided '{"route":"implement","reason":"x"}'
emit "$SLUG" plan_created '{"path":"PLAN.md","status":"READY"}'
emit "$SLUG" adversary_completed '{"mode":"plan","verdict":"READY","accepted_findings":[],"rejected_findings":[]}'
emit "$SLUG" file_changed '{"path":"src/x.ts","change":"edit"}'
emit "$SLUG" validation_run '{"command":"bash tests/a.sh","exit":0}'
emit "$SLUG" simplification_completed '{"status":"passed","evidence":"diff"}'
emit "$SLUG" review_completed '{"status":"GO","evidence":"review"}'
emit "$SLUG" adversary_completed '{"mode":"code_diff","verdict":"GO","accepted_findings":[],"rejected_findings":[]}'
emit "$SLUG" outcome_metric '{"outcome":"success","success":true,"measured":false,"reason":"offline"}'
emit "$SLUG" archive_written '{"path":"docs/plan/x.md"}'
emit "$SLUG" runtime_receipt '{"receipt_for":"validation_run","source":"Bash","kind":"validation","subject_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","exit":0,"observed_by":"parent-process","cryptographic":false}'
emit "$SLUG" runtime_receipt '{"receipt_for":"review_completed","source":"host","kind":"review","subject_sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","observed_by":"parent-process","cryptographic":false}'
emit "$SLUG" runtime_receipt '{"receipt_for":"archive_written","source":"host","kind":"archive","subject_sha256":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","observed_by":"parent-process","cryptographic":false}'
emit "$SLUG" runtime_receipt '{"receipt_for":"completed","source":"host","kind":"completion","subject_sha256":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","observed_by":"parent-process","cryptographic":false}'
emit "$SLUG" plan_removed '{"path":"PLAN.md"}'
emit "$SLUG" completed '{"summary":"done"}'
out="$("$EVENT" --dir "$EVENT_DIR" validate "$SLUG" --profile autonomous-completed-strict)"
assert_contains "$out" "ok"

# Remove the review receipt => strict must fail, legacy autonomous-completed still ok
grep -v '"receipt_for":"review_completed"' "$EVENT_DIR/$SLUG/events.jsonl" >"$EVENT_DIR/$SLUG/events.tmp"
mv "$EVENT_DIR/$SLUG/events.tmp" "$EVENT_DIR/$SLUG/events.jsonl"
out="$(expect_status 1 "$EVENT" --dir "$EVENT_DIR" validate "$SLUG" --profile autonomous-completed-strict)"
assert_contains "$out" "missing runtime_receipt kind review"
"$EVENT" --dir "$EVENT_DIR" validate "$SLUG" --profile autonomous-completed >/dev/null ||
	fail "legacy autonomous-completed must remain readable without receipts"

# --- self-improvement integrity: rejects arbitrary population, missing fingerprint, grader drift ---
emit si-valid harness_validation_completed "{\"candidate\":\"c1\",\"verdict\":\"accepted\",\"reason\":\"gain\",\"held_in\":{\"baseline\":{\"population\":\"etabli-core-v1\",\"passed\":0,\"total\":2},\"candidate\":{\"population\":\"etabli-core-v1\",\"passed\":2,\"total\":2}},\"held_out\":{\"baseline\":{\"population\":\"etabli-core-v1\",\"passed\":4,\"total\":4},\"candidate\":{\"population\":\"etabli-core-v1\",\"passed\":4,\"total\":4}},\"checks\":[\"t\"],\"evidence\":[\"e\"],\"candidate_fingerprint\":\"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee\",\"evaluator_manifest_sha256\":\"$EVAL_SHA\"}"
out="$("$INTEGRITY" "$EVENT_DIR/si-valid/events.jsonl")"
assert_contains "$out" "ok"

emit si-bad-pop harness_validation_completed "{\"candidate\":\"c1\",\"verdict\":\"accepted\",\"reason\":\"gain\",\"held_in\":{\"baseline\":{\"population\":\"made-up-pop\",\"passed\":0,\"total\":2},\"candidate\":{\"population\":\"made-up-pop\",\"passed\":2,\"total\":2}},\"held_out\":{\"baseline\":{\"population\":\"made-up-pop\",\"passed\":4,\"total\":4},\"candidate\":{\"population\":\"made-up-pop\",\"passed\":4,\"total\":4}},\"checks\":[\"t\"],\"evidence\":[\"e\"],\"candidate_fingerprint\":\"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee\",\"evaluator_manifest_sha256\":\"$EVAL_SHA\"}"
out="$(expect_status 1 "$INTEGRITY" "$EVENT_DIR/si-bad-pop/events.jsonl")"
assert_contains "$out" "not registered"

emit si-no-fp harness_validation_completed "{\"candidate\":\"c1\",\"verdict\":\"accepted\",\"reason\":\"gain\",\"held_in\":{\"baseline\":{\"population\":\"etabli-core-v1\",\"passed\":0,\"total\":2},\"candidate\":{\"population\":\"etabli-core-v1\",\"passed\":2,\"total\":2}},\"held_out\":{\"baseline\":{\"population\":\"etabli-core-v1\",\"passed\":4,\"total\":4},\"candidate\":{\"population\":\"etabli-core-v1\",\"passed\":4,\"total\":4}},\"checks\":[\"t\"],\"evidence\":[\"e\"],\"evaluator_manifest_sha256\":\"$EVAL_SHA\"}"
out="$(expect_status 1 "$INTEGRITY" "$EVENT_DIR/si-no-fp/events.jsonl")"
assert_contains "$out" "candidate_fingerprint"

emit si-drift harness_validation_completed "{\"candidate\":\"c1\",\"verdict\":\"accepted\",\"reason\":\"gain\",\"held_in\":{\"baseline\":{\"population\":\"etabli-core-v1\",\"passed\":0,\"total\":2},\"candidate\":{\"population\":\"etabli-core-v1\",\"passed\":2,\"total\":2}},\"held_out\":{\"baseline\":{\"population\":\"etabli-core-v1\",\"passed\":4,\"total\":4},\"candidate\":{\"population\":\"etabli-core-v1\",\"passed\":4,\"total\":4}},\"checks\":[\"t\"],\"evidence\":[\"e\"],\"candidate_fingerprint\":\"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee\",\"evaluator_manifest_sha256\":\"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\"}"
out="$(expect_status 1 "$INTEGRITY" "$EVENT_DIR/si-drift/events.jsonl")"
assert_contains "$out" "non-comparable"

# Strict v2 binds the exact manifest bytes, evaluator bundle and comparator
# output produced by the public skill-eval command.
STRICT_EVAL_MANIFEST="$STRICT_MANIFEST"
STRICT_EVAL_MANIFEST_SHA="$STRICT_MANIFEST_SHA"
mkdir -p "$TMP_DIR/strict-artifact-a" "$TMP_DIR/strict-artifact-b" "$EVENT_DIR/si-strict"
printf 'baseline\n' >"$TMP_DIR/strict-artifact-a/SKILL.md"
printf 'candidate\n' >"$TMP_DIR/strict-artifact-b/SKILL.md"
STRICT_BASELINE_FP="$("$ROOT_DIR/scripts/skill-eval" fingerprint "$TMP_DIR/strict-artifact-a")"
STRICT_CANDIDATE_FP="$("$ROOT_DIR/scripts/skill-eval" fingerprint "$TMP_DIR/strict-artifact-b")"
BASELINE_OUTCOMES='[{"task_id":"review-go-forbidden-empty-deciding","passed":false},{"task_id":"review-isolation-sentinel","passed":true},{"task_id":"review-spec-drift","passed":true},{"task_id":"plan-draft-no-mutate","passed":true},{"task_id":"hunter-read-only","passed":true},{"task_id":"ready-implement-touches-only-plan-files","passed":true},{"task_id":"no-parent-logic-claim","passed":true},{"task_id":"review-go-clean-diff","passed":true}]'
CANDIDATE_OUTCOMES='[{"task_id":"review-go-forbidden-empty-deciding","passed":true},{"task_id":"review-isolation-sentinel","passed":true},{"task_id":"review-spec-drift","passed":true},{"task_id":"plan-draft-no-mutate","passed":true},{"task_id":"hunter-read-only","passed":true},{"task_id":"ready-implement-touches-only-plan-files","passed":true},{"task_id":"no-parent-logic-claim","passed":true},{"task_id":"review-go-clean-diff","passed":true}]'
jq -n --arg manifest_sha "$STRICT_EVAL_MANIFEST_SHA" --arg evaluator_sha "$(jq -r .evaluator.sha256 "$STRICT_EVAL_MANIFEST")" --arg bundle_sha "$STRICT_BUNDLE_SHA" --arg artifact_sha "$STRICT_BASELINE_FP" --argjson outcomes "$BASELINE_OUTCOMES" '{schema_version:2,manifest_id:"core-v2",manifest_sha256:$manifest_sha,evaluator_sha256:$evaluator_sha,evaluator_bundle_sha256:$bundle_sha,artifact_fingerprint:$artifact_sha,outcomes:$outcomes}' >"$TMP_DIR/strict-baseline.json"
jq -n --arg manifest_sha "$STRICT_EVAL_MANIFEST_SHA" --arg evaluator_sha "$(jq -r .evaluator.sha256 "$STRICT_EVAL_MANIFEST")" --arg bundle_sha "$STRICT_BUNDLE_SHA" --arg artifact_sha "$STRICT_CANDIDATE_FP" --argjson outcomes "$CANDIDATE_OUTCOMES" '{schema_version:2,manifest_id:"core-v2",manifest_sha256:$manifest_sha,evaluator_sha256:$evaluator_sha,evaluator_bundle_sha256:$bundle_sha,artifact_fingerprint:$artifact_sha,outcomes:$outcomes}' >"$TMP_DIR/strict-candidate.json"
"$ROOT_DIR/scripts/skill-eval" compare --manifest "$STRICT_EVAL_MANIFEST" --baseline "$TMP_DIR/strict-baseline.json" --candidate "$TMP_DIR/strict-candidate.json" --baseline-artifact "$TMP_DIR/strict-artifact-a" --candidate-artifact "$TMP_DIR/strict-artifact-b" --evaluator-root "$ROOT_DIR" --json >"$EVENT_DIR/si-strict/comparison.json"
COMPARISON_SHA="$(hash256 "$EVENT_DIR/si-strict/comparison.json" | awk '{print $1}')"
emit si-strict harness_validation_completed "{\"candidate\":\"c2\",\"verdict\":\"accepted\",\"reason\":\"gain\",\"objective\":{\"kind\":\"quality\",\"metric\":\"held_in_passed\",\"direction\":\"increase\",\"minimum_delta\":1},\"held_in\":{\"baseline\":{\"population\":\"etabli-harness-v1\",\"passed\":3,\"total\":4},\"candidate\":{\"population\":\"etabli-harness-v1\",\"passed\":4,\"total\":4}},\"held_out\":{\"baseline\":{\"population\":\"etabli-harness-v1\",\"passed\":2,\"total\":2},\"candidate\":{\"population\":\"etabli-harness-v1\",\"passed\":2,\"total\":2}},\"safety\":{\"baseline\":{\"population\":\"etabli-harness-v1\",\"passed\":2,\"total\":2},\"candidate\":{\"population\":\"etabli-harness-v1\",\"passed\":2,\"total\":2}},\"checks\":[\"strict bundle\",\"public comparator\"],\"evidence\":[\"comparison.json\"],\"baseline_fingerprint\":\"$STRICT_BASELINE_FP\",\"candidate_fingerprint\":\"$STRICT_CANDIDATE_FP\",\"evaluator_manifest_sha256\":\"$STRICT_EVAL_MANIFEST_SHA\",\"evaluator_bundle_sha256\":\"$STRICT_BUNDLE_SHA\",\"comparison_path\":\"comparison.json\",\"comparison_sha256\":\"$COMPARISON_SHA\"}"
out="$($INTEGRITY --manifest "$STRICT_EVAL_MANIFEST" "$EVENT_DIR/si-strict/events.jsonl")"
assert_contains "$out" "manifest core-v2"

test_objective_chain() {
	local kind="$1" metric="$2" direction="$3" delta="$4" baseline_value="$5" candidate_value="$6"
	local slug="si-objective-$kind" manifest="$TMP_DIR/$kind-manifest.json"
	local manifest_sha manifest_id evaluator_sha outcomes baseline candidate comparison comparison_sha detail
	mkdir -p "$EVENT_DIR/$slug"
	jq --arg kind "$kind" --arg metric "$metric" --arg direction "$direction" --argjson delta "$delta" \
		'.manifest_id = ("objective-" + $kind) | .objective = {kind:$kind,metric:$metric,direction:$direction,minimum_delta:$delta,measurement_population:"objective-runs-v1"}' \
		"$STRICT_EVAL_MANIFEST" >"$manifest"
	manifest_sha="$(hash256 "$manifest" | awk '{print $1}')"
	manifest_id="$(jq -r .manifest_id "$manifest")"
	evaluator_sha="$(jq -r .evaluator.sha256 "$manifest")"
	outcomes="$(jq -c '[.tasks[] | {task_id:.id,passed:true}]' "$manifest")"
	baseline="$TMP_DIR/$kind-baseline.json"
	candidate="$TMP_DIR/$kind-candidate.json"
	jq -n --arg manifest_id "$manifest_id" --arg manifest_sha "$manifest_sha" --arg evaluator_sha "$evaluator_sha" --arg bundle_sha "$STRICT_BUNDLE_SHA" --arg artifact_sha "$STRICT_BASELINE_FP" --arg population "objective-runs-v1" --arg metric "$metric" --argjson value "$baseline_value" --argjson outcomes "$outcomes" \
		'{schema_version:2,manifest_id:$manifest_id,manifest_sha256:$manifest_sha,evaluator_sha256:$evaluator_sha,evaluator_bundle_sha256:$bundle_sha,artifact_fingerprint:$artifact_sha,outcomes:$outcomes,measurement:{population:$population,metric:$metric,value:$value,sample_count:5}}' >"$baseline"
	jq -n --arg manifest_id "$manifest_id" --arg manifest_sha "$manifest_sha" --arg evaluator_sha "$evaluator_sha" --arg bundle_sha "$STRICT_BUNDLE_SHA" --arg artifact_sha "$STRICT_CANDIDATE_FP" --arg population "objective-runs-v1" --arg metric "$metric" --argjson value "$candidate_value" --argjson outcomes "$outcomes" \
		'{schema_version:2,manifest_id:$manifest_id,manifest_sha256:$manifest_sha,evaluator_sha256:$evaluator_sha,evaluator_bundle_sha256:$bundle_sha,artifact_fingerprint:$artifact_sha,outcomes:$outcomes,measurement:{population:$population,metric:$metric,value:$value,sample_count:5}}' >"$candidate"
	comparison="$EVENT_DIR/$slug/comparison.json"
	"$ROOT_DIR/scripts/skill-eval" compare --manifest "$manifest" --baseline "$baseline" --candidate "$candidate" --baseline-artifact "$TMP_DIR/strict-artifact-a" --candidate-artifact "$TMP_DIR/strict-artifact-b" --evaluator-root "$ROOT_DIR" --json >"$comparison"
	comparison_sha="$(hash256 "$comparison" | awk '{print $1}')"
	detail="$(jq -c --arg population "etabli-harness-v1" --arg manifest_sha "$manifest_sha" --arg comparison_sha "$comparison_sha" '
		{candidate:("objective-" + .objective.kind),verdict:.verdict,reason:"objective met",objective:.objective,
		 held_in:{baseline:{population:$population,passed:.baseline.splits.held_in.passed,total:.baseline.splits.held_in.total},candidate:{population:$population,passed:.candidate.splits.held_in.passed,total:.candidate.splits.held_in.total}},
		 held_out:{baseline:{population:$population,passed:.baseline.splits.held_out.passed,total:.baseline.splits.held_out.total},candidate:{population:$population,passed:.candidate.splits.held_out.passed,total:.candidate.splits.held_out.total}},
		 safety:{baseline:{population:$population,passed:.baseline.splits.safety.passed,total:.baseline.splits.safety.total},candidate:{population:$population,passed:.candidate.splits.safety.passed,total:.candidate.splits.safety.total}},
		 measurement:{baseline:.baseline.measurement,candidate:.candidate.measurement},checks:["objective comparator"],evidence:["comparison.json"],
		 baseline_fingerprint:.baseline.artifact_fingerprint,candidate_fingerprint:.candidate.artifact_fingerprint,evaluator_manifest_sha256:$manifest_sha,evaluator_bundle_sha256:.evaluator_bundle_sha256,comparison_path:"comparison.json",comparison_sha256:$comparison_sha}
	' "$comparison")"
	emit "$slug" harness_validation_completed "$detail"
	out="$($INTEGRITY --manifest "$manifest" "$EVENT_DIR/$slug/events.jsonl")"
	assert_contains "$out" "manifest objective-$kind"
}

test_objective_chain efficiency total_tokens decrease 10 100 80
test_objective_chain reliability success_rate increase 0.1 0.6 0.8

jq -c '
  if .event == "harness_validation_completed" then
    .detail.objective = {
      minimum_delta: .detail.objective.minimum_delta,
      measurement_population: .detail.objective.measurement_population,
      direction: .detail.objective.direction,
      metric: .detail.objective.metric,
      kind: .detail.objective.kind
    }
    | .detail.measurement.baseline = {
        sample_count: .detail.measurement.baseline.sample_count,
        value: .detail.measurement.baseline.value,
        metric: .detail.measurement.baseline.metric,
        population: .detail.measurement.baseline.population
      }
    | .detail.measurement.candidate = {
        value: .detail.measurement.candidate.value,
        population: .detail.measurement.candidate.population,
        sample_count: .detail.measurement.candidate.sample_count,
        metric: .detail.measurement.candidate.metric
      }
  else . end
' "$EVENT_DIR/si-objective-efficiency/events.jsonl" >"$EVENT_DIR/si-objective-efficiency/events.reordered"
mv "$EVENT_DIR/si-objective-efficiency/events.reordered" "$EVENT_DIR/si-objective-efficiency/events.jsonl"
out="$($INTEGRITY --manifest "$TMP_DIR/efficiency-manifest.json" "$EVENT_DIR/si-objective-efficiency/events.jsonl")"
assert_contains "$out" "manifest objective-efficiency"

# The strict terminal profile must invoke the comparator-chain validator, not
# merely check that provenance fields are present. Build a complete strict
# ledger, validate it, then tamper with the bound comparison output.
STRICT_CHAIN_SLUG="si-strict-completed"
mkdir -p "$EVENT_DIR/$STRICT_CHAIN_SLUG"
cp "$EVENT_DIR/si-strict/comparison.json" "$EVENT_DIR/$STRICT_CHAIN_SLUG/comparison.json"
STRICT_CHAIN_SHA="$(hash256 "$EVENT_DIR/$STRICT_CHAIN_SLUG/comparison.json" | awk '{print $1}')"
emit "$STRICT_CHAIN_SLUG" route_decided '{"route":"implement","reason":"strict chain"}'
emit "$STRICT_CHAIN_SLUG" plan_created '{"path":"PLAN.md","status":"READY"}'
emit "$STRICT_CHAIN_SLUG" adversary_completed '{"mode":"plan","verdict":"READY","accepted_findings":[],"rejected_findings":[]}'
emit "$STRICT_CHAIN_SLUG" file_changed '{"path":"src/x.ts","change":"edit"}'
emit "$STRICT_CHAIN_SLUG" validation_run '{"command":"bash tests/a.sh","exit":0}'
emit "$STRICT_CHAIN_SLUG" simplification_completed '{"status":"passed","evidence":"diff"}'
emit "$STRICT_CHAIN_SLUG" review_completed '{"status":"GO","evidence":"review"}'
emit "$STRICT_CHAIN_SLUG" adversary_completed '{"mode":"code_diff","verdict":"GO","accepted_findings":[],"rejected_findings":[]}'
emit "$STRICT_CHAIN_SLUG" outcome_metric '{"outcome":"success","success":true,"measured":false,"reason":"offline"}'
jq -c --arg run "$STRICT_CHAIN_SLUG" --arg path "comparison.json" --arg sha "$STRICT_CHAIN_SHA" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
	'select(.event == "harness_validation_completed") | .run = $run | .ts = $ts | .detail.comparison_path = $path | .detail.comparison_sha256 = $sha' \
	"$EVENT_DIR/si-strict/events.jsonl" >>"$EVENT_DIR/$STRICT_CHAIN_SLUG/events.jsonl"
emit "$STRICT_CHAIN_SLUG" runtime_receipt '{"receipt_for":"validation_run","source":"Bash","kind":"validation","subject_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","exit":0,"observed_by":"parent-process","cryptographic":false}'
emit "$STRICT_CHAIN_SLUG" runtime_receipt '{"receipt_for":"review_completed","source":"host","kind":"review","subject_sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","observed_by":"parent-process","cryptographic":false}'
emit "$STRICT_CHAIN_SLUG" runtime_receipt '{"receipt_for":"archive_written","source":"host","kind":"archive","subject_sha256":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","observed_by":"parent-process","cryptographic":false}'
emit "$STRICT_CHAIN_SLUG" runtime_receipt '{"receipt_for":"completed","source":"host","kind":"completion","subject_sha256":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","observed_by":"parent-process","cryptographic":false}'
emit "$STRICT_CHAIN_SLUG" archive_written '{"path":"docs/plan/x.md"}'
emit "$STRICT_CHAIN_SLUG" plan_removed '{"path":"PLAN.md"}'
emit "$STRICT_CHAIN_SLUG" completed '{"summary":"done"}'
out="$($EVENT --dir "$EVENT_DIR" validate "$STRICT_CHAIN_SLUG" --profile autonomous-completed-strict)"
assert_contains "$out" "ok"

# A generic scaffold does not carry Etabli's project-specific evaluator. Its
# strict profile must fail closed for comparative events rather than silently
# accepting the weaker structural checks. Exercise the real deployment path.
DEPLOYED_PROJECT="$TMP_DIR/deployed-project"
"$ROOT_DIR/scripts/deploy-workflow" "$DEPLOYED_PROJECT" >/dev/null
out="$(expect_status 1 "$DEPLOYED_PROJECT/scripts/workflow-event" --dir "$EVENT_DIR" validate "$STRICT_CHAIN_SLUG" --profile autonomous-completed-strict)"
assert_contains "$out" "cannot verify the comparator chain"

jq '.verdict = "rejected"' "$EVENT_DIR/$STRICT_CHAIN_SLUG/comparison.json" >"$TMP_DIR/tampered-comparison.json"
mv "$TMP_DIR/tampered-comparison.json" "$EVENT_DIR/$STRICT_CHAIN_SLUG/comparison.json"
out="$(expect_status 1 "$EVENT" --dir "$EVENT_DIR" validate "$STRICT_CHAIN_SLUG" --profile autonomous-completed-strict)"
assert_contains "$out" "verified self-improvement comparator chain"

# Substituting a task ID must fail even when the altered comparator is rehashed.
mkdir -p "$EVENT_DIR/si-strict-substituted"
jq '.baseline.splits.safety.outcomes[0].task_id = "unknown-safety-task"' \
	"$EVENT_DIR/si-strict/comparison.json" >"$EVENT_DIR/si-strict-substituted/comparison.json"
SUBSTITUTED_SHA="$(hash256 "$EVENT_DIR/si-strict-substituted/comparison.json" | awk '{print $1}')"
jq -c --arg path "../si-strict-substituted/comparison.json" --arg sha "$SUBSTITUTED_SHA" \
	'.detail.comparison_path = $path | .detail.comparison_sha256 = $sha' \
	"$EVENT_DIR/si-strict/events.jsonl" >"$EVENT_DIR/si-strict-substituted/events.jsonl"
out="$(expect_status 1 "$INTEGRITY" --manifest "$STRICT_EVAL_MANIFEST" "$EVENT_DIR/si-strict-substituted/events.jsonl")"
assert_contains "$out" "exactly match the strict manifest tasks"

# A safety split must use one comparable population on both sides.
mkdir -p "$EVENT_DIR/si-strict-population-mismatch"
jq -c '.run = "si-strict-population-mismatch" | .detail.safety.candidate.population = "etabli-core-v1"' \
	"$EVENT_DIR/si-strict/events.jsonl" >"$EVENT_DIR/si-strict-population-mismatch/events.jsonl"
out="$(expect_status 1 "$EVENT" --dir "$EVENT_DIR" validate si-strict-population-mismatch --profile structural)"
assert_contains "$out" "invalid detail"
out="$(expect_status 1 "$INTEGRITY" --manifest "$STRICT_EVAL_MANIFEST" "$EVENT_DIR/si-strict-population-mismatch/events.jsonl")"
assert_contains "$out" "populations must match"

# A strict decision cannot be certified when its comparator artifact disappears.
mv "$EVENT_DIR/si-strict/comparison.json" "$TMP_DIR/comparison.saved"
out="$(expect_status 1 "$INTEGRITY" --manifest "$STRICT_EVAL_MANIFEST" "$EVENT_DIR/si-strict/events.jsonl")"
assert_contains "$out" "cannot read or parse comparison output"
mv "$TMP_DIR/comparison.saved" "$EVENT_DIR/si-strict/comparison.json"

# A stale strict bundle declaration fails before any event can be certified.
jq '.evaluator.bundle.sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' "$STRICT_EVAL_MANIFEST" >"$TMP_DIR/core-v2-stale.json"
out="$(expect_status 1 "$INTEGRITY" --manifest "$TMP_DIR/core-v2-stale.json" "$EVENT_DIR/si-strict/events.jsonl")"
assert_contains "$out" "evaluator bundle"
jq '.strict = false' "$STRICT_EVAL_MANIFEST" >"$TMP_DIR/core-v2-legacy-fallback.json"
out="$(expect_status 1 "$INTEGRITY" --manifest "$TMP_DIR/core-v2-legacy-fallback.json" "$EVENT_DIR/si-strict/events.jsonl")"
assert_contains "$out" "cannot fall back"

# Legacy ledger without harness_validation_completed validates cleanly
out="$("$INTEGRITY" "$EVENT_DIR/$SLUG/events.jsonl")"
assert_contains "$out" "0 harness validation"

printf 'workflow-receipts smoke test: ok\n'
