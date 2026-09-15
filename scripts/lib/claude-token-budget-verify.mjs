import { readdirSync, readFileSync } from "node:fs";
import { basename, join } from "node:path";
import {
	usageFromHeadlessRecord,
	usageFromCostStates,
} from "./claude-usage-rollup.mjs";

const GATE_TARGET = 0.5;
const OTEL_TOLERANCE = 0.01;

function mulberry32(seed) {
	let a = seed >>> 0;
	return () => {
		a |= 0;
		a = (a + 0x6d2b79f5) | 0;
		let t = Math.imul(a ^ (a >>> 15), 1 | a);
		t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}

export function loadSamples(samplesDir) {
	const samples = [];
	for (const name of readdirSync(samplesDir).sort()) {
		if (!name.endsWith(".json")) continue;
		let parsed;
		try {
			parsed = JSON.parse(readFileSync(join(samplesDir, name), "utf8"));
		} catch (error) {
			throw new Error(
				`unreadable sample ${join(samplesDir, name)}: ${error instanceof Error ? error.message : String(error)} — fix or remove the sample file, then rerun verify`,
			);
		}
		samples.push({ file: basename(name), ...parsed });
	}
	return samples;
}

export function runTokens(sample) {
	const fromRecord = usageFromHeadlessRecord(sample.record);
	if (fromRecord) return fromRecord;
	const fromCostStates = usageFromCostStates(
		sample.cost_states ?? [],
		sample.session_id ?? "",
	);
	if (fromCostStates) return fromCostStates;
	return null;
}

function sampleKey(sample) {
	return `${sample.scenario}/${sample.arm}/${sample.rep}`;
}

export function pairSamples(manifest, samples) {
	const problems = [];
	const selected = manifest.selected_candidate;
	if (!selected || !manifest.arms[selected]) {
		problems.push(
			`manifest.selected_candidate is "${selected ?? "null"}" — set it to the calibration winner (candidate_a or candidate_b) in manifest.v2.json before verifying holdout results`,
		);
		return {
			problems,
			pairs: [],
			excludedInfraPairs: [],
			superseded: [],
			orphans: samples.map(sampleKey),
		};
	}
	const validArms = new Set(["baseline", selected]);
	const byKey = new Map();
	const excludedInfraPairs = [];
	const superseded = [];
	for (const sample of samples) {
		if (sample.stage !== "measure") {
			problems.push(
				`${sampleKey(sample)}: stage must be "measure" (calibration runs never enter the proof)`,
			);
			continue;
		}
		if (!manifest.scenario_order.includes(sample.scenario)) {
			problems.push(
				`${sampleKey(sample)}: unknown scenario "${sample.scenario}" — scenario must be one of manifest.scenario_order (holdout must stay frozen)`,
			);
			continue;
		}
		if (!validArms.has(sample.arm)) {
			problems.push(
				`${sampleKey(sample)}: arm "${sample.arm}" is not measured on the holdout (expected baseline or ${selected})`,
			);
			continue;
		}
		if (sample.superseded === true) {
			superseded.push(sampleKey(sample));
			continue;
		}
		const key = sampleKey(sample);
		if (byKey.has(key)) {
			problems.push(
				`${key}: duplicate sample (${byKey.get(key).file} and ${sample.file}) — mark replaced runs with "superseded": true`,
			);
			continue;
		}
		byKey.set(key, sample);
	}
	const pairs = [];
	for (const scenario of manifest.scenario_order) {
		for (let rep = 1; rep <= 3; rep += 1) {
			const baseline = byKey.get(`${scenario}/baseline/${rep}`);
			const candidate = byKey.get(`${scenario}/${selected}/${rep}`);
			if (!baseline || !candidate) {
				problems.push(
					`${scenario}/rep${rep}: incomplete pair (${baseline ? "baseline ok" : "baseline missing"}, ${candidate ? "candidate ok" : "candidate missing"}) — replay the pair (max ${manifest.budget.max_replay_pairs} pairs) or add the missing sample`,
				);
				continue;
			}
			if (baseline.infra_error === true || candidate.infra_error === true) {
				excludedInfraPairs.push(`${scenario}/rep${rep}`);
				problems.push(
					`${scenario}/rep${rep}: infrastructure error excludes the whole pair — replay both sides within the replay budget, then mark the failed pair superseded`,
				);
				continue;
			}
			pairs.push({ scenario, rep, baseline, candidate });
		}
	}
	return { problems, pairs, excludedInfraPairs, superseded };
}

function oracleProblems(manifest, pairs) {
	const problems = [];
	const byScenario = {};
	for (const pair of pairs) {
		byScenario[pair.scenario] ??= { baseline: [], candidate: [] };
		for (const side of ["baseline", "candidate"]) {
			const run = pair[side];
			const oracle = run.oracle ?? {};
			byScenario[pair.scenario][side].push(oracle);
			if (oracle.cap_hit === true) {
				problems.push(
					`${sampleKey(run)}: cap_hit=true — raise the agent maxTurns only via a new frozen manifest, never mid-proof`,
				);
			}
		}
	}
	for (const [scenario, sides] of Object.entries(byScenario)) {
		for (const side of ["baseline", "candidate"]) {
			const passed = sides[side].filter((o) => o.passed === true).length;
			if (passed !== 3) {
				problems.push(
					`${scenario}/${side}: oracle ${passed}/3 — the ${manifest.selected_candidate ?? "candidate"} must pass ${side === "candidate" ? "3/3" : "no worse than baseline"}; rerun the route with a stronger effort arm or declare CHALLENGED`,
				);
			}
		}
	}
	return problems;
}

function conformanceProblems(pairs) {
	const problems = [];
	for (const pair of pairs) {
		const route = String(pair.scenario).split("/")[0].split("-")[0];
		for (const side of ["baseline", "candidate"]) {
			const run = pair[side];
			if (!run.route) {
				problems.push(
					`${sampleKey(run)}: missing route — record the calibration route per run`,
				);
			} else if (run.route !== route && run.route !== pair.scenario) {
				problems.push(
					`${sampleKey(run)}: route "${run.route}" does not match scenario "${pair.scenario}" — fix the sample or rerun`,
				);
			}
			if (!run.model_id || !run.effort) {
				problems.push(
					`${sampleKey(run)}: missing model_id/effort — record the resolved runtime model and effort per run (probe requirement)`,
				);
			}
		}
	}
	return problems;
}

function otelProblems(pairs) {
	const problems = [];
	for (const pair of pairs) {
		for (const side of ["baseline", "candidate"]) {
			const run = pair[side];
			const tokens = runTokens(run);
			if (!tokens) {
				problems.push(
					`${sampleKey(run)}: no usable usage (record without usage and no cumulative cost-state) — attach the final headless record`,
				);
				continue;
			}
			if (run.otel?.processed_total_tokens != null) {
				const ratio =
					Math.abs(run.otel.processed_total_tokens - tokens.processed_total_tokens) /
					tokens.processed_total_tokens;
				if (ratio > OTEL_TOLERANCE) {
					problems.push(
						`${sampleKey(run)}: OTel reconciliation ${(ratio * 100).toFixed(2)}% > 1% — deduplicate transcript events by requestId/message id or fix the OTel attribution`,
					);
				}
			}
		}
	}
	return problems;
}

function ratioReport(pairs) {
	let baselineSum = 0;
	let candidateSum = 0;
	const byScenario = {};
	for (const pair of pairs) {
		const b = runTokens(pair.baseline);
		const c = runTokens(pair.candidate);
		if (!b || !c) continue;
		baselineSum += b.processed_total_tokens;
		candidateSum += c.processed_total_tokens;
		byScenario[pair.scenario] ??= { baseline: 0, candidate: 0, pairs: 0 };
		byScenario[pair.scenario].baseline += b.processed_total_tokens;
		byScenario[pair.scenario].candidate += c.processed_total_tokens;
		byScenario[pair.scenario].pairs += 1;
	}
	const ratio = baselineSum > 0 ? candidateSum / baselineSum : null;
	return { baselineSum, candidateSum, ratio, byScenario };
}

export function bootstrapUpperBound(pairs, seed, draws, confidence) {
	const clusters = new Map();
	for (const pair of pairs) {
		const b = runTokens(pair.baseline);
		const c = runTokens(pair.candidate);
		if (!b || !c) continue;
		if (!clusters.has(pair.scenario)) clusters.set(pair.scenario, []);
		clusters.get(pair.scenario).push({
			baseline: b.processed_total_tokens,
			candidate: c.processed_total_tokens,
		});
	}
	const clusterList = [...clusters.entries()].sort(([a], [b]) =>
		a < b ? -1 : 1,
	);
	if (clusterList.length === 0) return null;
	const rand = mulberry32(seed);
	const values = [];
	for (let draw = 0; draw < draws; draw += 1) {
		let bSum = 0;
		let cSum = 0;
		for (let i = 0; i < clusterList.length; i += 1) {
			const index = Math.floor(rand() * clusterList.length);
			for (const pair of clusterList[index][1]) {
				bSum += pair.baseline;
				cSum += pair.candidate;
			}
		}
		values.push(bSum > 0 ? cSum / bSum : Number.POSITIVE_INFINITY);
	}
	values.sort((a, b) => a - b);
	const rank = Math.ceil(confidence * values.length);
	return values[Math.min(rank, values.length) - 1];
}

export function verifySamples(manifest, samples) {
	const gates = [];
	const {
		problems: pairProblems,
		pairs,
		excludedInfraPairs,
		superseded,
	} = pairSamples(manifest, samples);
	gates.push({
		gate: "sample_structure",
		passed: pairProblems.length === 0,
		problems: pairProblems,
	});
	const problems = [...pairProblems];
	if (pairs.length > 0) {
		for (const found of [
			...oracleProblems(manifest, pairs),
			...conformanceProblems(pairs),
			...otelProblems(pairs),
		]) {
			problems.push(found);
		}
	}
	const ratio = ratioReport(pairs);
	const ratioGatePass =
		ratio.ratio != null &&
		ratio.ratio <= (manifest.targets?.ratio_max ?? GATE_TARGET);
	gates.push({
		gate: "ratio",
		passed: ratioGatePass,
		value: ratio.ratio,
		detail:
			ratio.ratio == null ? "no computable ratio" : `R=${ratio.ratio.toFixed(4)}`,
	});
	const bound = bootstrapUpperBound(
		pairs,
		manifest.seed,
		manifest.bootstrap?.draws ?? 10000,
		manifest.bootstrap?.confidence ?? 0.95,
	);
	const boundMax = manifest.targets?.upper_bound_max ?? GATE_TARGET;
	gates.push({
		gate: "bootstrap_upper_bound",
		passed: bound != null && bound <= boundMax,
		value: bound,
		detail:
			bound == null
				? "no computable bootstrap bound"
				: `upper95=${bound.toFixed(4)} <= ${boundMax}`,
	});
	const allPassed = gates.every((g) => g.passed) && problems.length === 0;
	return {
		passed: allPassed,
		pairs_included: pairs.length,
		excluded_infra_pairs: excludedInfraPairs,
		superseded_samples: superseded,
		ratio: ratio.ratio,
		baseline_total_tokens: ratio.baselineSum,
		candidate_total_tokens: ratio.candidateSum,
		by_scenario: ratio.byScenario,
		bootstrap_upper_bound: bound,
		gates,
		problems,
	};
}

export function verifyFromFiles(manifest, samplesDir) {
	return verifySamples(manifest, loadSamples(samplesDir));
}
