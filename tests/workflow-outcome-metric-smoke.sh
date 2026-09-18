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

# A quality-only measured event does not suppress the first valid native usage.
"$EVENT" --dir "$DIR" append m1-quality route_decided '{"route":"answer","reason":"quality fixture"}'
"$EVENT" --dir "$DIR" append m1-quality outcome_metric '{"outcome":"quality-pass","success":true,"measured":true,"tests_passed":1}'
"$OM" --dir "$DIR" --apply --parent-input 2 --parent-output 3 --parent-total 5 m1-quality >/tmp/om-quality.json
qcount="$(jq -s '[.[]|select(.event=="outcome_metric")]|length' "$DIR/m1-quality/events.jsonl")"
[ "$qcount" -eq 2 ] || fail "quality-only event suppressed native usage"
jq -e 'select(.event=="outcome_metric" and .detail.total_tokens==5)' "$DIR/m1-quality/events.jsonl" >/dev/null ||
	fail "native usage was not appended after quality-only event"

out="$("$EVENT" --dir "$DIR" append m1-null outcome_metric '{"outcome":"bad","success":true,"measured":true,"input_tokens":null,"output_tokens":null,"total_tokens":null,"tool_calls":null,"elapsed_ms":null}' 2>&1 || true)"
case "$out" in
	*"invalid json detail"*) ;;
	*) fail "explicit null usage tuple must be rejected: $out" ;;
esac

# Measurement populations use the same complete usage tuple as native coverage;
# a measured flag plus total_tokens alone must not certify a target.
MEASUREMENT_BOUNDARY_ROOT="$TMP/measurement-boundary" node --input-type=module <<'NODE'
import { createHash } from "node:crypto"
import { mkdirSync, writeFileSync } from "node:fs"
import { join } from "node:path"
const root = process.env.MEASUREMENT_BOUNDARY_ROOT
const targetDir = join(root, "partial-run")
const populationDir = join(root, "population-run")
mkdirSync(targetDir, { recursive: true })
mkdirSync(populationDir, { recursive: true })
const line = (event, detail) => JSON.stringify({ ts: "2026-09-14T00:00:00Z", event, run: "partial-run", detail })
const outcome = line("outcome_metric", { outcome: "quality", success: true, measured: true, total_tokens: 5 })
const terminal = line("completed", { summary: "partial" })
const raw = [outcome, terminal].join(String.fromCharCode(10)) + String.fromCharCode(10)
writeFileSync(join(targetDir, "events.jsonl"), raw)
const sha = (value) => createHash("sha256").update(value).digest("hex")
const stable = (value) => Array.isArray(value) ? `[${value.map(stable).join(",")}]` : value && typeof value === "object" ? `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stable(value[key])}`).join(",")}}` : JSON.stringify(value)
const target = {
  target_run: "partial-run",
  target_ledger_sha256: sha(raw),
  target_terminal: "completed",
  target_terminal_event_sha256: sha(terminal),
  target_outcome_event_sha256: sha(outcome),
  baseline_measured: true,
  baseline_usage_measured: true,
}
const targets = [target]
const manifest = sha(stable(targets))
const population = {
  population_id: `terminal-runs-v1-${manifest.slice(0, 16)}`,
  manifest_sha256: manifest,
  terminal_runs: 1,
  targets,
}
const populationLine = JSON.stringify({ ts: "2026-09-14T00:01:00Z", event: "outcome_measurement_population", run: "population-run", detail: population })
writeFileSync(join(populationDir, "events.jsonl"), populationLine + String.fromCharCode(10))
NODE
if "$ROOT_DIR/scripts/workflow-measurement-integrity" "$TMP/measurement-boundary" "$TMP/measurement-boundary/population-run/events.jsonl" >/tmp/measurement-boundary.out 2>&1; then
	fail "partial usage tuple must not certify a population target"
fi
grep -Fq 'baseline_usage_measured' /tmp/measurement-boundary.out ||
	fail "population target mismatch did not identify usage provenance"

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
const qualityOnly = [{ event: "outcome_metric", detail: { measured: true, tests_passed: 10 } }]
if (b.hasMeasuredOutcomeMetric(qualityOnly)) throw new Error("quality-only metric counted as usage")
const partialUsage = [{ event: "outcome_metric", detail: { measured: true, input_tokens: 2, output_tokens: 3, total_tokens: 5 } }]
if (b.hasMeasuredUsage(partialUsage)) throw new Error("partial usage was counted as valid")
const usageMetric = [{ event: "outcome_metric", detail: { measured: true, input_tokens: 2, output_tokens: 3, total_tokens: 5, tool_calls: 0, elapsed_ms: 0 } }]
if (!b.hasMeasuredUsage(usageMetric)) throw new Error("valid usage was not detected")
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
