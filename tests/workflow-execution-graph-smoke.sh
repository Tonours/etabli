#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
EVENT="$ROOT_DIR/scripts/workflow-event"
GRAPH="$ROOT_DIR/scripts/workflow-execution-graph"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DIR="$TMP/.workflow"

fail() {
	printf 'workflow-execution-graph smoke: %s\n' "$1" >&2
	exit 1
}

[ -x "$GRAPH" ] || chmod +x "$GRAPH"

"$EVENT" --dir "$DIR" append g1 route_decided '{"route":"plan-implement","reason":"graph"}'
"$EVENT" --dir "$DIR" append g1 plan_created '{"path":"PLAN.md","status":"READY"}'
"$EVENT" --dir "$DIR" append g1 file_changed '{"path":"x","change":"y"}'
"$EVENT" --dir "$DIR" append g1 validation_run '{"command":"true","exit":0}'
"$EVENT" --dir "$DIR" append g1 completed '{"summary":"done"}'

json="$("$GRAPH" --dir "$DIR" g1)"
printf '%s\n' "$json" | jq -e '.derived == true and .node_count == 5 and .edge_count == 4' >/dev/null || fail "unexpected graph shape"
printf '%s\n' "$json" | jq -e '.nodes[0].type == "Route" and .nodes[1].type == "PlanSlice"' >/dev/null || fail "node types"
printf '%s\n' "$json" | jq -e '.edges[2].edge == "validates" or .edges[3].edge == "requires"' >/dev/null || fail "edges"
printf '%s\n' "$json" | jq -e '.source_of_truth | endswith("events.jsonl")' >/dev/null || fail "source fingerprint"
printf '%s\n' "$json" | jq -e '.invariants.derived_only == true and .invariants.acyclic_claimed == false' >/dev/null || fail "invariants"

text="$("$GRAPH" --dir "$DIR" --text g1)"
case "$text" in
*nodes=5*edges=4*) ;;
*) fail "text output missing counts: $text" ;;
esac

printf 'workflow-execution-graph smoke test: ok\n'
