#!/usr/bin/env bash
# Runtime receipts + autonomous-completed-strict profile + self-improvement
# provenance integrity.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
EVENT="$ROOT_DIR/scripts/workflow-event"
INTEGRITY="$ROOT_DIR/scripts/workflow-self-improvement-integrity"
RECEIPTS="$ROOT_DIR/scripts/lib/workflow-receipts.mjs"
MANIFEST="$ROOT_DIR/workflow/self-improvement/manifests/core-v1.json"
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
emit si-valid harness_validation_completed "{\"candidate\":\"c1\",\"verdict\":\"accepted\",\"reason\":\"gain\",\"held_in\":{\"baseline\":{\"population\":\"etabli--initial-v1\",\"passed\":0,\"total\":2},\"candidate\":{\"population\":\"etabli--initial-v1\",\"passed\":2,\"total\":2}},\"held_out\":{\"baseline\":{\"population\":\"etabli--initial-v1\",\"passed\":4,\"total\":4},\"candidate\":{\"population\":\"etabli--initial-v1\",\"passed\":4,\"total\":4}},\"checks\":[\"t\"],\"evidence\":[\"e\"],\"candidate_fingerprint\":\"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee\",\"evaluator_manifest_sha256\":\"$EVAL_SHA\"}"
out="$("$INTEGRITY" "$EVENT_DIR/si-valid/events.jsonl")"
assert_contains "$out" "ok"

emit si-bad-pop harness_validation_completed "{\"candidate\":\"c1\",\"verdict\":\"accepted\",\"reason\":\"gain\",\"held_in\":{\"baseline\":{\"population\":\"made-up-pop\",\"passed\":0,\"total\":2},\"candidate\":{\"population\":\"made-up-pop\",\"passed\":2,\"total\":2}},\"held_out\":{\"baseline\":{\"population\":\"made-up-pop\",\"passed\":4,\"total\":4},\"candidate\":{\"population\":\"made-up-pop\",\"passed\":4,\"total\":4}},\"checks\":[\"t\"],\"evidence\":[\"e\"],\"candidate_fingerprint\":\"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee\",\"evaluator_manifest_sha256\":\"$EVAL_SHA\"}"
out="$(expect_status 1 "$INTEGRITY" "$EVENT_DIR/si-bad-pop/events.jsonl")"
assert_contains "$out" "not registered"

emit si-no-fp harness_validation_completed "{\"candidate\":\"c1\",\"verdict\":\"accepted\",\"reason\":\"gain\",\"held_in\":{\"baseline\":{\"population\":\"etabli--initial-v1\",\"passed\":0,\"total\":2},\"candidate\":{\"population\":\"etabli--initial-v1\",\"passed\":2,\"total\":2}},\"held_out\":{\"baseline\":{\"population\":\"etabli--initial-v1\",\"passed\":4,\"total\":4},\"candidate\":{\"population\":\"etabli--initial-v1\",\"passed\":4,\"total\":4}},\"checks\":[\"t\"],\"evidence\":[\"e\"],\"evaluator_manifest_sha256\":\"$EVAL_SHA\"}"
out="$(expect_status 1 "$INTEGRITY" "$EVENT_DIR/si-no-fp/events.jsonl")"
assert_contains "$out" "candidate_fingerprint"

emit si-drift harness_validation_completed "{\"candidate\":\"c1\",\"verdict\":\"accepted\",\"reason\":\"gain\",\"held_in\":{\"baseline\":{\"population\":\"etabli--initial-v1\",\"passed\":0,\"total\":2},\"candidate\":{\"population\":\"etabli--initial-v1\",\"passed\":2,\"total\":2}},\"held_out\":{\"baseline\":{\"population\":\"etabli--initial-v1\",\"passed\":4,\"total\":4},\"candidate\":{\"population\":\"etabli--initial-v1\",\"passed\":4,\"total\":4}},\"checks\":[\"t\"],\"evidence\":[\"e\"],\"candidate_fingerprint\":\"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee\",\"evaluator_manifest_sha256\":\"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff\"}"
out="$(expect_status 1 "$INTEGRITY" "$EVENT_DIR/si-drift/events.jsonl")"
assert_contains "$out" "non-comparable"

# Legacy ledger without harness_validation_completed validates cleanly
out="$("$INTEGRITY" "$EVENT_DIR/$SLUG/events.jsonl")"
assert_contains "$out" "0 harness validation"

printf 'workflow-receipts smoke test: ok\n'
