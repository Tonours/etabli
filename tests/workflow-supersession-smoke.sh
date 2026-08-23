#!/usr/bin/env bash
# Supersession guard: rejected candidates cannot be re-proposed without rationale.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CHECK="$ROOT_DIR/scripts/workflow-supersession-check"
EVENT="$ROOT_DIR/scripts/workflow-event"
TMP_DIR="$(mktemp -d)"
EVENT_DIR="$TMP_DIR/.workflow"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
	printf 'workflow-supersession smoke: %s\n' "$1" >&2
	exit 1
}

emit() { "$EVENT" --dir "$EVENT_DIR" append "$@"; }

[ -x "$CHECK" ] || fail "missing supersession-check"

# A proposal that supersedes an earlier rejection with rationale is accepted.
emit ss-ok harness_proposal '{"candidate":"split-review-guard","editable_surfaces":["a.ts"],"preserve":["b"],"held_in":["x"],"held_out":["y"]}'
emit ss-ok harness_validation_completed '{"candidate":"split-review-guard","verdict":"rejected","reason":"regression","held_in":{"baseline":{"population":"etabli-core-v1","passed":0,"total":2},"candidate":{"population":"etabli-core-v1","passed":1,"total":2}},"held_out":{"baseline":{"population":"etabli-core-v1","passed":4,"total":4},"candidate":{"population":"etabli-core-v1","passed":3,"total":4}},"checks":["t"],"evidence":["e"]}'
emit ss-ok harness_candidate_rejected '{"candidate":"split-review-guard","reason":"held-out regression","regressions":["y"],"evidence":["e"]}'
emit ss-ok harness_proposal '{"candidate":"split-review-guard","editable_surfaces":["a.ts"],"preserve":["b"],"held_in":["x"],"held_out":["y"],"supersedes":["split-review-guard"]}'
out="$("$CHECK" "$EVENT_DIR/ss-ok/events.jsonl")"
case "$out" in *ok) ;; *) fail "superseded re-proposal was rejected: $out" ;; esac

# A re-proposal WITHOUT supersedes is rejected.
emit ss-bad harness_candidate_rejected '{"candidate":"broad-keyword","reason":"regression","regressions":["y"],"evidence":["e"]}'
emit ss-bad harness_proposal '{"candidate":"broad-keyword","editable_surfaces":["a.ts"],"preserve":["b"],"held_in":["x"],"held_out":["y"]}'
if "$CHECK" "$EVENT_DIR/ss-bad/events.jsonl" >/dev/null 2>&1; then
	fail "re-proposal without supersedes was accepted"
fi

# Legacy ledger with no rejections validates cleanly.
emit ss-clean harness_proposal '{"candidate":"fresh","editable_surfaces":["a.ts"],"preserve":["b"],"held_in":["x"],"held_out":["y"]}'
out="$("$CHECK" "$EVENT_DIR/ss-clean/events.jsonl")"
case "$out" in *ok) ;; *) fail "clean ledger rejected: $out" ;; esac

# The additive supersedes field is accepted by the event schema.
out="$("$EVENT" --dir "$EVENT_DIR" validate ss-ok)" 2>&1
case "$out" in *"events, ok"*) ;; *) fail "ledger with supersedes did not validate: $out" ;; esac

printf 'workflow-supersession smoke test: ok\n'
