import { writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import {
	buildInventory,
	dryRunReport,
	loadManifest,
	pairOrderFor,
	summarizeInventory,
} from "./claude-agent-benchmark.mjs";

const ROOT_DIR = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

export function usage() {
	return `Usage: claude-agent-benchmark [dry-run|inventory] [--manifest path] [--json]

Commands:
  dry-run         Print the frozen process budget without network access.
  inventory       Print the process inventory; --json includes every process.
  run-probes      SPENDS TOKENS after the documented approval checkpoint.
  run-calibration SPENDS TOKENS after the documented approval checkpoint.`;
}

export function parseArgs(args) {
	const options = {
		command: "dry-run",
		manifest: join(ROOT_DIR, "claude/benchmarks/token-budget/manifest.v2.json"),
		json: false,
		arms: [],
		routes: [],
		reps: 3,
		outDir: join(ROOT_DIR, ".workflow/claude-token-budget/samples"),
	};
	for (let index = 0; index < args.length; index += 1) {
		const arg = args[index];
		if (["dry-run", "inventory", "run-probes", "run-calibration"].includes(arg)) {
			options.command = arg;
		} else if (arg === "--json") {
			options.json = true;
		} else if (["--manifest", "--arms", "--routes", "--reps", "--out"].includes(arg)) {
			const value = args[index + 1];
			if (!value) throw new Error(`${arg} requires a value`);
			index += 1;
			if (arg === "--manifest") options.manifest = value;
			if (arg === "--arms") options.arms = splitList(value);
			if (arg === "--routes") options.routes = splitList(value);
			if (arg === "--reps") options.reps = Number(value);
			if (arg === "--out") options.outDir = value;
		} else if (arg === "-h" || arg === "--help") {
			options.help = true;
		} else {
			throw new Error(`unknown argument: ${arg}`);
		}
	}
	if (!Number.isInteger(options.reps) || options.reps < 1) {
		throw new Error("--reps requires a positive integer");
	}
	return options;
}

function splitList(value) {
	return value.split(",").map((entry) => entry.trim()).filter(Boolean);
}

function renderDryRun(report) {
	const inv = report.inventory;
	return [
		"claude-agent-benchmark dry-run (no network calls made)",
		`  manifest:            v${report.manifest_version} declared ${report.declared_at} @ ${report.revision}`,
		`  nominal processes:   ${report.budget.nominal_processes}`,
		`    pilot:             ${inv.by_stage.pilot ?? 0}`,
		`    calibration:       ${inv.by_stage.calibration ?? 0} (4 routes x 3 reps x 3 arms, excluded from KPI)`,
		`    cold diagnostics:  ${inv.by_stage.cold_diag ?? 0} (excluded from KPI)`,
		`    warmups:           ${inv.by_stage.warmup ?? 0} (B-C-C-B, excluded from KPI)`,
		`    measures:          ${inv.by_stage.measure ?? 0} (12 scenarios x 3 reps x 2 arms, counted)`,
		`  counted in KPI:      ${inv.counted_in_kpi}`,
		`  replay budget:       ${report.budget.max_replay_pairs} pairs (${report.budget.replay_pair_processes} processes)`,
		`  absolute cap:        ${report.budget.absolute_cap} paid processes (refuses 129th)`,
		`  headroom after max replays: ${report.budget.headroom_after_max_replays}`,
		`  max tokens estimate: ${report.estimate.estimated_max_total_tokens} (${report.estimate.per_process_p95_tokens} p95/process)`,
		`  max cost estimate:   $${report.estimate.estimated_max_usd} (secondary, blended rate)`,
		`  seed:                ${report.seed}`,
		`  gates:               R<=${report.gates.ratio_max}, bootstrap95<=${report.gates.upper_bound_max}, otel<${report.gates.otel_reconciliation_max}`,
		"  approval:            procedural human checkpoint — no paid run before explicit budget approval (PLAN.md)",
	].join("\n");
}

async function runPaid(options, manifest, rootDir, output, runModule) {
	const ledgerFile = join(rootDir, ".workflow/claude-token-budget/paid-processes.json");
	if (options.command === "run-probes") {
		const tuples = [
			{ role: "scout", model: "sonnet", effort: "low", maxTurns: 16 },
			{ role: "worker", model: "opus", effort: "low", maxTurns: 24 },
			{ role: "reviewer", model: "fable", effort: "medium", maxTurns: 24 },
			{ role: "adversary", model: "fable", effort: "low", maxTurns: 24 },
		];
		const probes = tuples.map((tuple) => {
			const sample = runModule.runProbe({
				manifest,
				repoRoot: rootDir,
				workDir: join(options.outDir, "work", `probe-${tuple.role}`),
				outFile: join(options.outDir, "probes", `role-${tuple.role}.json`),
				ledgerFile,
				...tuple,
			});
			output(`probe ${tuple.role}: ok=${sample.ok} models=${sample.model_usage_keys.join(",") || "none"} canonical=${sample.canonical_models.map((model) => model.canonical).join(",") || "none"} turns=${sample.num_turns}`);
			return sample;
		});
		const writeProbe = runModule.runProbe({
			manifest,
			repoRoot: rootDir,
			workDir: join(options.outDir, "work/probe-write"),
			outFile: join(options.outDir, "probes/write-refusal.json"),
			ledgerFile,
			role: "reviewer",
			model: "sonnet",
			effort: "low",
			maxTurns: 16,
		});
		output(`probe write-refusal: ok=${writeProbe.ok} pwned_created=${writeProbe.pwned_created}`);
		output(JSON.stringify({ probes: probes.length + 1, all_ok: probes.every((probe) => probe.ok) && writeProbe.ok }, null, 2));
		return 0;
	}

	const samples = runModule.runCalibration({
		manifest,
		repoRoot: rootDir,
		fixturesRoot: join(rootDir, "claude/benchmarks/token-budget/fixtures"),
		ledgerFile,
		outDir: options.outDir,
		arms: options.arms.length ? options.arms : ["baseline", "candidate_a", "candidate_b"],
		routes: options.routes.length ? options.routes : manifest.calibration.routes,
		reps: options.reps,
		onProgress: (sample) => output(`[calibration] ${sample.arm}/${sample.route}/rep${sample.rep} ok=${sample.ok} oracle=${sample.oracle.passed} tokens=${sample.processed_total_tokens} (${Math.round(sample.duration_ms / 1000)}s)`),
	});
	const selection = runModule.selectArm(samples, manifest);
	writeFileSync(join(options.outDir, "calibration-selection.json"), `${JSON.stringify(selection, null, 2)}\n`);
	output(JSON.stringify(selection, null, 2));
	return 0;
}

export async function main(args, dependencies = {}) {
	const output = dependencies.output ?? ((line) => console.log(line));
	const error = dependencies.error ?? ((line) => console.error(line));
	let options;
	try {
		options = parseArgs(args);
	} catch (cause) {
		error(cause instanceof Error ? cause.message : String(cause));
		error(usage());
		return 2;
	}
	if (options.help) {
		output(usage());
		return 0;
	}
	const rootDir = dependencies.rootDir ?? ROOT_DIR;
	const manifest = loadManifest(options.manifest);
	if (options.command === "run-probes" || options.command === "run-calibration") {
		const runModule = dependencies.runModule ?? await import("./claude-bench-run.mjs");
		return runPaid(options, manifest, rootDir, output, runModule);
	}
	const processes = buildInventory(manifest);
	if (options.command === "inventory") {
		output(JSON.stringify({
			processes,
			summary: summarizeInventory(processes),
			pair_orders: manifest.scenario_order.map((scenario, index) => ({
				scenario,
				rep_orders: [1, 2, 3].map((rep) => ({ rep, order: pairOrderFor(manifest, index, rep) })),
			})),
		}, null, 2));
		return 0;
	}
	const report = dryRunReport(manifest, processes);
	output(options.json ? JSON.stringify(report, null, 2) : renderDryRun(report));
	return 0;
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
	process.exitCode = await main(process.argv.slice(2));
}
