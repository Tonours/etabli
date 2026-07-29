#!/usr/bin/env bash
# G8/G9: offline sealed comparative harness_validation for leap G3 P0.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TMP="$(mktemp -d)"
EVENT_DIR="$TMP/.workflow"
trap 'rm -rf "$TMP"' EXIT

fail() {
  printf 'leap-harness-validation smoke: %s\n' "$1" >&2
  exit 1
}

DETAIL='{
  "candidate": "leap-g3-no-progress-mutate-deny",
  "verdict": "accepted",
  "reason": "held-in gain without held-out regression on sealed offline sample for no_progress mutate-deny",
  "held_in": {
    "baseline": {"population": "etabli-leap-offline-v1", "passed": 0, "total": 2},
    "candidate": {"population": "etabli-leap-offline-v1", "passed": 2, "total": 2}
  },
  "held_out": {
    "baseline": {"population": "etabli-leap-offline-holdout-v1", "passed": 1, "total": 1},
    "candidate": {"population": "etabli-leap-offline-holdout-v1", "passed": 1, "total": 1}
  },
  "checks": ["bash tests/no-progress-mutate-deny-smoke.sh", "scripts/verify-agentic-infra core"],
  "evidence": ["scripts/lib/no-progress-guard.mjs", "tests/no-progress-mutate-deny-smoke.sh", "docs/plan/20260729-etabli-leap-no-progress-mutate-deny.md"]
}'

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append leap-g3-p0 harness_proposal \
  '{"candidate":"leap-g3-no-progress-mutate-deny","editable_surfaces":["claude/hooks/workflow-router-lib.mjs","scripts/lib/no-progress-guard.mjs"],"preserve":["READY gate","check-freeze","ops-stop"],"held_in":["no_progress soft mid-session"],"held_out":["router-eval","plan-check-freeze"]}'

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append leap-g3-p0 harness_validation_completed "$DETAIL"

"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" validate leap-g3-p0 --profile structural

json="$("$ROOT_DIR/scripts/workflow-metrics" --dir "$EVENT_DIR" --json)"
printf '%s\n' "$json" | jq -e '
  .harness.accepted_candidates == 1 and
  (.harness.candidates[] | select(.candidate == "leap-g3-no-progress-mutate-deny") |
    .verdict == "accepted" and .held_in_delta_pp == 100 and .held_out_delta_pp == 0)
' >/dev/null || fail "metrics harness acceptance: $json"

# Reject fake accepted without held-in gain
set +e
"$ROOT_DIR/scripts/workflow-event" --dir "$EVENT_DIR" append leap-bad harness_validation_completed \
  '{"candidate":"bad","verdict":"accepted","reason":"cheat","held_in":{"baseline":{"population":"p","passed":1,"total":1},"candidate":{"population":"p","passed":1,"total":1}},"held_out":{"baseline":{"population":"h","passed":1,"total":1},"candidate":{"population":"h","passed":1,"total":1}},"checks":["x"],"evidence":["y"]}' \
  2>"$TMP/bad.err"
bad=$?
set -e
[ "$bad" -ne 0 ] || fail "accepted without held-in gain must fail schema"

printf 'leap-harness-validation smoke test: ok\n'
