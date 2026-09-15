#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
EVENT="$ROOT_DIR/scripts/workflow-event"
OM="$ROOT_DIR/scripts/workflow-outcome-metric"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
DIR="$TMP/.workflow"

fail() {
  printf 'workflow-outcome-metric smoke: %s\n' "$1" >&2
  exit 1
}

chmod +x "$OM"

"$EVENT" --dir "$DIR" append m1-prod route_decided '{"route":"plan-implement","reason":"producer"}'
"$EVENT" --dir "$DIR" append m1-prod multi_execution_completed '{"participants":[{"id":"agent-scout","model":"opencode-go/deepseek-v4-flash","family":"opencode-go"}],"independent_first_passes":true,"disagreement":false,"adjudicator":null,"verdict":"accepted","usage":{"measured":true,"input_tokens":30,"output_tokens":10,"total_tokens":40,"elapsed_ms":100},"fallback_status":"none"}'

json="$("$OM" --dir "$DIR" --parent-input 70 --parent-output 30 --parent-total 100 --runtime pi/test m1-prod)"
printf '%s\n' "$json" | jq -e '.detail.measured == true' >/dev/null || fail "expected measured"
printf '%s\n' "$json" | jq -e '.detail.total_tokens == 140' >/dev/null || fail "expected parent+sidecar total"
printf '%s\n' "$json" | jq -e '.detail.participant_usage | length == 2' >/dev/null || fail "expected 2 participants"
printf '%s\n' "$json" | jq -e '(.detail.participant_usage | map(.total_tokens) | add) == .detail.total_tokens' >/dev/null || fail "sum mismatch"
printf '%s\n' "$json" | jq -e '.detail.batch_wall_clock_ms > 0' >/dev/null || fail "expected batch window"

"$OM" --dir "$DIR" --apply --parent-input 70 --parent-output 30 --parent-total 100 m1-prod >/tmp/om-apply.json
"$EVENT" --dir "$DIR" validate m1-prod | grep -Fq 'ok' || fail "ledger invalid after apply"
jq -e 'select(.event=="outcome_metric" and .detail.measured==true and .detail.total_tokens==140)' "$DIR/m1-prod/events.jsonl" >/dev/null ||
  fail "measured outcome_metric missing after apply"

# second apply is a no-op (still exit 0)
"$OM" --dir "$DIR" --apply --parent-input 1 --parent-output 1 m1-prod >/tmp/om-apply2.json
count="$(jq -s '[.[]|select(.event=="outcome_metric")]|length' "$DIR/m1-prod/events.jsonl")"
[ "$count" -eq 1 ] || fail "expected single outcome_metric, got $count"

# node unit checks for builder edge cases
node --input-type=module <<NODE
import { pathToFileURL } from "node:url"
const b = await import(pathToFileURL("$ROOT_DIR/scripts/lib/outcome-metric-builder.mjs").href)
const u = b.usageFromAssistantMessages([
  { role: "assistant", usage: { input: 10, output: 5, totalTokens: 15 } },
  { role: "user" },
  { role: "assistant", usage: { input: 3, output: 2, totalTokens: 5 } },
])
if (!u || u.total_tokens !== 20) throw new Error("usageFromAssistantMessages failed")
const empty = b.buildOutcomeMetricDetail({})
if (empty.measured !== false) throw new Error("empty should be unmeasured")
// Usage schema v2: cache components tracked without changing total_tokens.
const u2 = b.usageFromAssistantMessages([
  { role: "assistant", usage: { input: 10, output: 5, totalTokens: 15, cacheRead: 100, cacheCreation: 3 } },
])
if (!u2 || u2.cache_read_tokens !== 100 || u2.cache_creation_tokens !== 3)
	throw new Error("cache fields failed: " + JSON.stringify(u2))
if (u2.total_tokens !== 15) throw new Error("total_tokens semantics changed")
const d2 = b.buildOutcomeMetricDetail({
  parent: { input_tokens: 10, output_tokens: 5, total_tokens: 15, cache_read_tokens: 100, cache_creation_tokens: 3 },
})
if (d2.measured !== true || d2.usage_schema_version !== 2)
	throw new Error("usage_schema_version failed: " + JSON.stringify(d2))
if (d2.cache_read_tokens !== 100 || d2.cache_creation_tokens !== 3)
	throw new Error("cache detail failed")
if (d2.processed_total_tokens !== 118) throw new Error("processed_total_tokens failed")
if (d2.total_tokens !== 15) throw new Error("total_tokens changed")
const d3 = b.buildOutcomeMetricDetail({ parent: { input_tokens: 1, output_tokens: 1, total_tokens: 2 } })
if (d3.usage_schema_version !== 2 || d3.processed_total_tokens !== 2 || d3.cache_read_tokens !== 0)
	throw new Error("v2 defaults failed: " + JSON.stringify(d3))
console.log("builder unit ok")
NODE

# emit helper with active ledger
node --input-type=module <<NODE
import { mkdirSync, writeFileSync } from "node:fs"
import { join } from "node:path"
import { pathToFileURL } from "node:url"
const cwd = "$TMP/emit-cwd"
const ledgerDir = join(cwd, ".workflow", "emit-run")
mkdirSync(ledgerDir, { recursive: true })
const line = (event, detail) => JSON.stringify({
  schema_version: 2,
  ts: new Date().toISOString().replace(/\\.\\d{3}Z$/, "Z"),
  event,
  run: "emit-run",
  detail,
})
writeFileSync(join(ledgerDir, "events.jsonl"), [
  line("route_decided", { route: "answer", reason: "t" }),
  line("multi_execution_completed", {
    participants: [{ id: "agent-scout", model: "opencode-go/deepseek-v4-flash", family: "opencode-go" }],
    independent_first_passes: true,
    disagreement: false,
    adjudicator: null,
    verdict: "accepted",
    usage: { measured: true, input_tokens: 4, output_tokens: 1, total_tokens: 5, elapsed_ms: 1 },
    fallback_status: "none",
  }),
].join("\\n") + "\\n")
const { maybeEmitOutcomeMetric } = await import(pathToFileURL("$ROOT_DIR/scripts/lib/outcome-metric-emit.mjs").href)
const r = maybeEmitOutcomeMetric(cwd, {
  parentUsage: { input_tokens: 6, output_tokens: 4, total_tokens: 10 },
  runtime: "pi/test",
})
if (!r.emitted) throw new Error("expected emit: " + JSON.stringify(r))
const r2 = maybeEmitOutcomeMetric(cwd, {
  parentUsage: { input_tokens: 1, output_tokens: 1, total_tokens: 2 },
})
if (r2.emitted || r2.reason !== "already_measured") throw new Error("dedupe failed: " + JSON.stringify(r2))
console.log("emit helper ok")
NODE

# task_grader demotion without grader_success
node --input-type=module <<NODE
import { pathToFileURL } from "node:url"
const b = await import(pathToFileURL("$ROOT_DIR/scripts/lib/outcome-metric-builder.mjs").href)
const d = b.buildOutcomeMetricDetail({
  parent: { input_tokens: 1, output_tokens: 1, total_tokens: 2 },
  success_kind: "task_grader",
})
if (d.success_kind !== "run_terminal") throw new Error("expected demotion")
const d2 = b.buildOutcomeMetricDetail({
  parent: { input_tokens: 1, output_tokens: 1, total_tokens: 2 },
  success_kind: "task_grader",
  grader_success: true,
})
if (d2.success_kind !== "task_grader") throw new Error("expected task_grader")
console.log("task_grader demotion ok")
NODE

printf 'workflow-outcome-metric smoke test: ok\n'
