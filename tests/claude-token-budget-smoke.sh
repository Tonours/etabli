#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
BENCH="$ROOT_DIR/scripts/claude-agent-benchmark"
VERIFY="$ROOT_DIR/scripts/claude-token-budget"
MANIFEST="$ROOT_DIR/claude/benchmarks/token-budget/manifest.v2.json"
ROLLUP="$ROOT_DIR/scripts/lib/claude-usage-rollup.mjs"
BENCH_LIB="$ROOT_DIR/scripts/lib/claude-agent-benchmark.mjs"
VERIFY_LIB="$ROOT_DIR/scripts/lib/claude-token-budget-verify.mjs"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
	printf 'claude-token-budget smoke: %s\n' "$1" >&2
	exit 1
}

chmod +x "$BENCH" "$VERIFY"

"$BENCH" dry-run --manifest "$MANIFEST" | grep -Fq 'nominal processes:   115' ||
	fail "dry-run nominal process count"
"$BENCH" inventory --manifest "$MANIFEST" --json | jq -e '
	.summary.total == 115 and
	.summary.counted_in_kpi == 72 and
	.summary.by_stage.pilot == 1 and
	.summary.by_stage.calibration == 36 and
	.summary.by_stage.cold_diag == 2 and
	.summary.by_stage.warmup == 4 and
	.summary.by_stage.measure == 72 and
	(.processes | length) == 115 and
	(.pair_orders | length) == 12 and
	.pair_orders[0].rep_orders[0].order == ["baseline", "candidate"] and
	.pair_orders[5].rep_orders[2].order == ["baseline", "candidate"] and
	.pair_orders[6].rep_orders[0].order == ["candidate", "baseline"]' >/dev/null ||
	fail "inventory shape"

node --input-type=module <<NODE
import { pathToFileURL } from "node:url";
const r = await import(pathToFileURL("$ROLLUP").href);
const assert = (cond, msg) => { if (!cond) throw new Error(msg); };

const totals = r.componentTotals({
	input_tokens: 10, output_tokens: 5,
	cache_read_input_tokens: 100, cache_creation_input_tokens: 3,
});
assert(totals.processed_total_tokens === 118, "component formula");

const entries = [
	{ requestId: "req-1", uuid: "m1", type: "assistant",
		message: { id: "m1", usage: { input_tokens: 10, output_tokens: 5 } } },
	{ requestId: "req-1", uuid: "m1", type: "assistant",
		message: { id: "m1", usage: { input_tokens: 12, output_tokens: 8,
			cache_read_input_tokens: 40 } } },
	{ requestId: "req-1", uuid: "m1", type: "assistant",
		message: { id: "m1", usage: { input_tokens: 12, output_tokens: 7,
			cache_read_input_tokens: 44 } } },
	{ isSidechain: true, requestId: "req-2", uuid: "s1", type: "assistant",
		message: { id: "s1", usage: { input_tokens: 30, output_tokens: 10 } } },
	{ type: "assistant", usage: { input_tokens: 7, output_tokens: 1 } },
];
const roll = r.rollupTranscript(entries);
assert(roll.groups.length === 3, "duplicate entries collapse into one group per id, got " + roll.groups.length);
const main = roll.totals_by_class.main;
assert(main.input_tokens === 12 && main.output_tokens === 8 && main.cache_read_tokens === 44,
	"per-group max per component, not sum: " + JSON.stringify(main));
assert(roll.totals_by_class.subagent.input_tokens === 30, "sidechain classified subagent");
assert(roll.totals_by_class.auxiliary.input_tokens === 7, "unattributed classified auxiliary");
assert(roll.processed_total_tokens === (12 + 8 + 44) + (30 + 10) + (7 + 1), "grand total");

const e2e = r.componentTotals({ input_tokens: 60, output_tokens: 44 });
const rec = r.reconcileWithE2E(roll, e2e, { tolerance: 0.01 });
assert(rec.within_tolerance === true, "residual under tolerance");
const bad = r.reconcileWithE2E(roll, r.componentTotals({ input_tokens: 200, output_tokens: 100 }), {});
assert(bad.within_tolerance === false, "large residual flagged");

const record = r.usageFromHeadlessRecord({
	result: { usage: { input_tokens: 100, output_tokens: 50,
		cache_read_input_tokens: 900, cache_creation_input_tokens: 10 } },
});
assert(record.processed_total_tokens === 1060, "headless record authority");
assert(r.usageFromHeadlessRecord({ result: {} }) === null, "empty record yields null");

const costStates = [
	{ session_id: "s", usage: { input_tokens: 10, output_tokens: 5 } },
	{ session_id: "s", usage: { input_tokens: 100, output_tokens: 50 } },
	{ session_id: "other", usage: { input_tokens: 9999, output_tokens: 9999 } },
];
const fromCosts = r.usageFromCostStates(costStates, "s");
assert(fromCosts.input_tokens === 100, "last cumulative cost-state wins, never a sum");

const mismatch = r.usageFromHeadlessRecord({
	result: {
		usage: { input_tokens: 100, output_tokens: 50 },
		modelUsage: { m1: { usage: { input_tokens: 90, output_tokens: 40 } },
			m2: { usage: { input_tokens: 20, output_tokens: 10 } } },
	},
});
assert(mismatch.model_usage_mismatch, "modelUsage disagreement is surfaced");
const agreeing = r.usageFromHeadlessRecord({
	result: {
		usage: { input_tokens: 100, output_tokens: 50 },
		modelUsage: { m1: { usage: { input_tokens: 80, output_tokens: 40 } },
			m2: { usage: { input_tokens: 20, output_tokens: 10 } } },
	},
});
assert(!agreeing.model_usage_mismatch, "agreeing modelUsage raises no flag");
const realShape = r.usageFromHeadlessRecord({
	result: {
		usage: { input_tokens: 6, output_tokens: 553,
			cache_read_input_tokens: 116594, cache_creation_input_tokens: 43743 },
		modelUsage: {
			"claude-opus-5[1m]": {
				inputTokens: 6, outputTokens: 553,
				cacheReadInputTokens: 116594, cacheCreationInputTokens: 43743,
				thinkingTokens: 0, contextWindow: 200000, costUSD: 0.5,
				canonicalModel: "claude-opus-5", provider: "anthropic",
			},
		},
	},
});
assert(realShape.processed_total_tokens === 160896, "result usage authority");
assert(!realShape.model_usage_mismatch, "camelCase modelUsage agrees with result usage");
const camel = r.componentTotals({ inputTokens: 10, outputTokens: 5,
	cacheReadInputTokens: 100, cacheCreationInputTokens: 3 });
assert(camel.processed_total_tokens === 118, "camelCase usage keys");
console.log("rollup units ok");
NODE

node --input-type=module <<NODE
import { pathToFileURL } from "node:url";
import { writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";
const b = await import(pathToFileURL("$BENCH_LIB").href);
const assert = (cond, msg) => { if (!cond) throw new Error(msg); };

const stateFile = join("$TMP", "state", "paid-processes.json");
mkdirSync(join("$TMP", "state"), { recursive: true });
writeFileSync(stateFile, JSON.stringify({ launched: 120, events: [] }));
let refused = null;
try {
	b.registerPaidProcesses(stateFile, 9, 128, { stage: "test" });
} catch (error) {
	refused = error;
}
assert(refused instanceof b.BudgetExceeded, "cap refusal is BudgetExceeded");
assert(refused.message.includes("129"), "refusal names the refused process");
const next = b.registerPaidProcesses(stateFile, 8, 128, { stage: "test" });
assert(next.launched === 128, "exactly at cap is allowed");
let refusedAgain = null;
try {
	b.registerPaidProcesses(stateFile, 1, 128, { stage: "test" });
} catch (error) {
	refusedAgain = error;
}
assert(refusedAgain instanceof b.BudgetExceeded, "129th process is refused");
const inv = b.buildInventory(b.loadManifest("$MANIFEST"));
assert(inv.length === 115, "nominal inventory 115");
console.log("budget guard ok");
NODE

node --input-type=module <<NODE
import { pathToFileURL } from "node:url";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";
const bench = await import(pathToFileURL("$BENCH_LIB").href);
const verify = await import(pathToFileURL("$VERIFY_LIB").href);
const assert = (cond, msg) => { if (!cond) throw new Error(msg); };

const manifest = bench.loadManifest("$MANIFEST");
const testManifest = { ...manifest, selected_candidate: "candidate_a" };

const sample = (scenario, arm, rep, tBase, tCand) => {
	const route = scenario.split("-")[0];
	const t = arm === "baseline" ? tBase : tCand;
	return {
		stage: "measure", scenario, arm, rep, route,
		model_id: "claude-test-model", effort: "medium",
		infra_error: false, superseded: false,
		record: { result: { usage: { input_tokens: t - 20, output_tokens: 10,
			cache_read_input_tokens: 10, cache_creation_input_tokens: 0 } } },
		otel: { processed_total_tokens: t },
		oracle: { passed: true, cap_hit: false },
	};
};

const buildDir = (mutate) => {
	const dir = join("$TMP", "samples-" + Math.random().toString(36).slice(2));
	mkdirSync(dir, { recursive: true });
	for (const [index, scenario] of manifest.scenario_order.entries()) {
		const base = 1000 + index * 10;
		for (let rep = 1; rep <= 3; rep += 1) {
			writeFileSync(join(dir, \`\${scenario}-baseline-\${rep}.json\`),
				JSON.stringify(sample(scenario, "baseline", rep, base, Math.round(base * 0.4))));
			writeFileSync(join(dir, \`\${scenario}-cand-\${rep}.json\`),
				JSON.stringify(sample(scenario, "candidate_a", rep, base, Math.round(base * 0.4))));
		}
	}
	mutate?.(dir);
	return dir;
};

const green = verify.verifyFromFiles(testManifest, buildDir());
assert(green.passed === true, "green samples pass: " + JSON.stringify(green.problems));
assert(green.pairs_included === 36, "36 pairs");
assert(green.ratio !== null && green.ratio <= 0.5, "ratio computed");
assert(green.bootstrap_upper_bound !== null && green.bootstrap_upper_bound <= 0.5,
	"bootstrap bound computed and under target");

const { selected_candidate: _selected, ...manifestWithoutSelection } = manifest;
const noSelection = verify.verifyFromFiles(manifestWithoutSelection, buildDir());
assert(noSelection.passed === false, "verify without selected_candidate fails closed");
assert(noSelection.problems.some((p) => p.includes("selected_candidate")), "failure names the remediation");

const missingOracle = verify.verifyFromFiles(testManifest, buildDir((dir) => {
	const name = \`\${manifest.scenario_order[0]}-cand-1.json\`;
	const s = JSON.parse(readFileSync(join(dir, name), "utf8"));
	s.oracle.passed = false;
	writeFileSync(join(dir, name), JSON.stringify(s));
}));
assert(missingOracle.passed === false, "oracle failure fails the gate");
assert(missingOracle.problems.some((p) => p.includes("oracle")), "oracle problem named");

const otelDrift = verify.verifyFromFiles(testManifest, buildDir((dir) => {
	const name = \`\${manifest.scenario_order[1]}-baseline-2.json\`;
	const s = JSON.parse(readFileSync(join(dir, name), "utf8"));
	s.otel.processed_total_tokens = s.otel.processed_total_tokens + 50;
	writeFileSync(join(dir, name), JSON.stringify(s));
}));
assert(otelDrift.passed === false, "otel drift over 1% fails");
assert(otelDrift.problems.some((p) => p.includes("OTel")), "otel problem named");

const infraPair = verify.verifyFromFiles(testManifest, buildDir((dir) => {
	const name = \`\${manifest.scenario_order[2]}-cand-3.json\`;
	const s = JSON.parse(readFileSync(join(dir, name), "utf8"));
	s.infra_error = true;
	writeFileSync(join(dir, name), JSON.stringify(s));
}));
assert(infraPair.passed === false, "infra error without replay fails the structure gate");
assert(infraPair.excluded_infra_pairs.length === 1, "pair excluded whole");

const supersededReplay = verify.verifyFromFiles(testManifest, buildDir((dir) => {
	const bad = \`\${manifest.scenario_order[3]}-cand-2.json\`;
	const s = JSON.parse(readFileSync(join(dir, bad), "utf8"));
	s.superseded = true;
	writeFileSync(join(dir, bad), JSON.stringify(s));
	const fixed = \`\${manifest.scenario_order[3]}-cand-2-replay.json\`;
	writeFileSync(join(dir, fixed), JSON.stringify(
		sample(manifest.scenario_order[3], "candidate_a", 2, 1030, 412)));
}));
assert(supersededReplay.passed === true, "superseded run replaced by replay passes");

const dup = verify.verifyFromFiles(testManifest, buildDir((dir) => {
	const name = \`\${manifest.scenario_order[4]}-baseline-1.json\`;
	const s = JSON.parse(readFileSync(join(dir, name), "utf8"));
	writeFileSync(join(dir, "dup.json"), JSON.stringify(s));
}));
assert(dup.passed === false && dup.problems.some((p) => p.includes("duplicate")),
	"duplicates rejected with remediation");
console.log("verify gates ok");
NODE

mkdir -p "$TMP/cli-samples"
node -e '
const { readFileSync, writeFileSync } = require("node:fs");
const { selected_candidate, ...rest } = JSON.parse(readFileSync(process.argv[1], "utf8"));
writeFileSync(process.argv[2], JSON.stringify(rest));
' "$MANIFEST" "$TMP/manifest-no-selection.json"
if "$VERIFY" verify --manifest "$TMP/manifest-no-selection.json" "$TMP/cli-samples" >"$TMP/cli.out" 2>"$TMP/cli.err"; then
	fail "cli verify must fail on empty samples"
fi
grep -Fq 'selected_candidate' "$TMP/cli.err" || fail "cli failure names selected_candidate remediation"

if "$VERIFY" verify --manifest "$MANIFEST" "$TMP/cli-samples" >"$TMP/cli-selected.out" 2>"$TMP/cli-selected.err"; then
	fail "cli verify must fail on empty samples even with a selected candidate"
fi

printf 'claude-token-budget smoke test: ok\n'
