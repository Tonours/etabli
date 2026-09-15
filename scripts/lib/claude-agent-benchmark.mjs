import {
	mkdirSync,
	readFileSync,
	writeFileSync,
	renameSync,
	existsSync,
} from "node:fs";
import { dirname, join } from "node:path";

export const NOMINAL_TOTAL = 115;
export const REPLAY_PAIR_PROCESSES = 12;

export function loadManifest(path) {
	let raw;
	let manifest;
	try {
		raw = readFileSync(path, "utf8");
		manifest = JSON.parse(raw);
	} catch (error) {
		throw new Error(
			`unreadable benchmark manifest ${path}: ${error instanceof Error ? error.message : String(error)} — fix the JSON syntax or pass --manifest <path> pointing at manifest.v2.json`,
		);
	}
	assertManifest(manifest);
	return manifest;
}

function assertManifest(manifest) {
	const problems = [];
	if (manifest.manifest_version !== 2)
		problems.push(`manifest_version must be 2, got ${manifest.manifest_version}`);
	if (!Number.isInteger(manifest.seed)) problems.push("seed must be an integer");
	if (!manifest.budget || manifest.budget.absolute_cap !== 128)
		problems.push("budget.absolute_cap must be 128");
	if (manifest.budget?.nominal_processes !== NOMINAL_TOTAL)
		problems.push(
			`budget.nominal_processes must be ${NOMINAL_TOTAL} (1 pilot + 36 calibration + 2 cold + 4 warmups + 72 measures)`,
		);
	if (manifest.budget?.max_replay_pairs !== 6)
		problems.push("budget.max_replay_pairs must be 6");
	const order = manifest.scenario_order;
	if (!Array.isArray(order) || order.length !== 12)
		problems.push("scenario_order must list exactly 12 holdout scenarios");
	if (new Set(order || []).size !== 12)
		problems.push("scenario_order must not repeat scenarios");
	if (!manifest.arms?.baseline) problems.push("arms.baseline is required");
	for (const arm of ["candidate_a", "candidate_b"]) {
		if (!manifest.arms?.[arm]) problems.push(`arms.${arm} is required`);
	}
	if (!manifest.arms?.baseline) {
		throw new ManifestInvalid(problems);
	}
	if (problems.length > 0) throw new ManifestInvalid(problems);
	return manifest;
}

export class ManifestInvalid extends Error {
	constructor(problems) {
		super(
			`invalid manifest — fix these fields in manifest.v2.json: ${problems.join("; ")}`,
		);
		this.name = "ManifestInvalid";
	}
}

export function holdoutScenarios(manifest) {
	return manifest.scenario_order;
}

export function pairOrderFor(manifest, scenarioIndex, rep) {
	const half = scenarioIndex < 6 ? "first_half" : "second_half";
	return manifest.pair_orders[half][rep - 1];
}

export function buildInventory(manifest) {
	const processes = [];
	const push = (stage, arm, scenario, rep, counted) => {
		processes.push({ stage, arm, scenario, rep, counted });
	};
	push("pilot", "baseline", "pilot", 1, false);
	const routes = manifest.calibration.routes;
	const reps = manifest.calibration.reps;
	for (const route of routes) {
		for (const arm of ["baseline", "candidate_a", "candidate_b"]) {
			for (let rep = 1; rep <= reps; rep += 1) {
				push("calibration", arm, `${route}`, rep, false);
			}
		}
	}
	for (const arm of ["candidate_a", "candidate_b"]) {
		push("cold_diag", arm, "cold", 1, false);
	}
	manifest.stages.warmup_order.forEach((arm, index) => {
		push("warmup", arm, "warmup", index + 1, false);
	});
	holdoutScenarios(manifest).forEach((scenario, scenarioIndex) => {
		const half = scenarioIndex < 6 ? "first_half" : "second_half";
		for (let rep = 1; rep <= 3; rep += 1) {
			const order = manifest.pair_orders[half][rep - 1];
			for (const arm of order) {
				push("measure", arm, scenario, rep, true);
			}
		}
	});
	return processes;
}

export function summarizeInventory(processes) {
	const byStage = {};
	for (const p of processes) {
		byStage[p.stage] = (byStage[p.stage] ?? 0) + 1;
	}
	const counted = processes.filter((p) => p.counted).length;
	return {
		total: processes.length,
		counted_in_kpi: counted,
		excluded_from_kpi: processes.length - counted,
		by_stage: byStage,
	};
}

export function estimateMaxCost(manifest, processes) {
	const p95 = manifest.estimate.baseline_p95_processed_tokens;
	const rate = manifest.estimate.blended_usd_per_mtok;
	const estimatedMaxTokens = processes.length * p95;
	return {
		per_process_p95_tokens: p95,
		estimated_max_total_tokens: estimatedMaxTokens,
		estimated_max_usd: Number(
			((estimatedMaxTokens / 1_000_000) * rate).toFixed(2),
		),
		note:
			"prices are a secondary estimate from the frozen p95 baseline; tokens remain the primary KPI",
	};
}

export class BudgetExceeded extends Error {
	constructor(attempted, launched, cap) {
		super(
			`paid process budget exceeded: refusing launch ${launched + 1}..${launched + attempted} (cap ${cap}) — replay at most ${REPLAY_PAIR_PROCESSES / 2} pairs or raise the cap explicitly in PLAN.md and manifest.v2.json before relaunching`,
		);
		this.name = "BudgetExceeded";
	}
}

export function paidProcessStatePath(repoRoot) {
	return join(
		repoRoot,
		".workflow",
		"claude-token-budget",
		"paid-processes.json",
	);
}

export function loadPaidProcessState(stateFile) {
	if (!existsSync(stateFile)) return { launched: 0, events: [] };
	let state;
	try {
		state = JSON.parse(readFileSync(stateFile, "utf8"));
	} catch (error) {
		throw new Error(
			`paid process ledger ${stateFile} is unreadable: ${error instanceof Error ? error.message : String(error)} — delete the benchmark run directory and restart the stage`,
		);
	}
	if (!Number.isInteger(state.launched) || state.launched < 0) {
		throw new Error(
			`paid process ledger ${stateFile} is corrupt (launched must be a non-negative integer) — delete the benchmark run directory and restart the stage`,
		);
	}
	return state;
}

export function registerPaidProcesses(stateFile, count, cap, meta = {}) {
	const state = loadPaidProcessState(stateFile);
	if (state.launched + count > cap) {
		throw new BudgetExceeded(count, state.launched, cap);
	}
	const next = {
		launched: state.launched + count,
		events: [...state.events, { ts: new Date().toISOString(), count, ...meta }],
	};
	mkdirSync(dirname(stateFile), { recursive: true });
	const tmp = `${stateFile}.tmp`;
	writeFileSync(tmp, `${JSON.stringify(next, null, 2)}\n`);
	renameSync(tmp, stateFile);
	return next;
}

export function dryRunReport(manifest, processes) {
	const summary = summarizeInventory(processes);
	const estimate = estimateMaxCost(manifest, processes);
	const replayHeadroom =
		manifest.budget.absolute_cap -
		manifest.budget.nominal_processes -
		REPLAY_PAIR_PROCESSES;
	return {
		manifest_version: manifest.manifest_version,
		declared_at: manifest.declared_at,
		revision: manifest.revision,
		inventory: summary,
		budget: {
			nominal_processes: manifest.budget.nominal_processes,
			absolute_cap: manifest.budget.absolute_cap,
			max_replay_pairs: manifest.budget.max_replay_pairs,
			replay_pair_processes: REPLAY_PAIR_PROCESSES,
			headroom_after_max_replays: replayHeadroom,
		},
		estimate,
		gates: {
			ratio_max: manifest.targets.ratio_max,
			upper_bound_max: manifest.targets.upper_bound_max,
			otel_reconciliation_max: manifest.targets.otel_reconciliation_max,
		},
		seed: manifest.seed,
		scenario_order: manifest.scenario_order,
		network_calls: 0,
	};
}
