import { statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { loadManifest } from "./claude-agent-benchmark.mjs";
import { verifyFromFiles } from "./claude-token-budget-verify.mjs";

const ROOT_DIR = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

export function usage() {
	return "Usage: claude-token-budget verify [--manifest path] <samples-dir>";
}

export function parseArgs(args) {
	let manifest = join(ROOT_DIR, "claude/benchmarks/token-budget/manifest.v2.json");
	let samplesDir = "";
	for (let index = 0; index < args.length; index += 1) {
		const arg = args[index];
		if (arg === "verify") continue;
		if (arg === "--manifest") {
			manifest = args[index + 1] ?? "";
			if (!manifest) throw new Error("--manifest requires a path");
			index += 1;
		} else if (arg === "-h" || arg === "--help") {
			return { help: true, manifest, samplesDir };
		} else if (arg.startsWith("-")) {
			throw new Error(`unknown option: ${arg}`);
		} else if (!samplesDir) {
			samplesDir = arg;
		} else {
			throw new Error(`unexpected argument: ${arg}`);
		}
	}
	return { help: false, manifest, samplesDir };
}

export function renderReport(report) {
	const lines = [
		`claude-token-budget verify: ${report.passed ? "PASS" : "FAIL"}`,
		`  pairs included:     ${report.pairs_included}/36`,
		`  infra exclusions:   ${report.excluded_infra_pairs.length}${report.excluded_infra_pairs.length ? ` (${report.excluded_infra_pairs.join(", ")})` : ""}`,
		`  superseded samples: ${report.superseded_samples.length}`,
	];
	if (report.ratio != null) {
		lines.push(`  R:                  ${report.ratio.toFixed(4)}`);
		lines.push(`  baseline total:     ${report.baseline_total_tokens}`);
		lines.push(`  candidate total:    ${report.candidate_total_tokens}`);
	}
	if (report.bootstrap_upper_bound != null) {
		lines.push(`  bootstrap upper95:  ${report.bootstrap_upper_bound.toFixed(4)}`);
	}
	for (const gate of report.gates) {
		lines.push(`  gate ${gate.gate}: ${gate.passed ? "ok" : "FAIL"}${gate.detail ? ` (${gate.detail})` : ""}`);
	}
	return lines.join("\n");
}

export function main(args, dependencies = {}) {
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
	if (!options.samplesDir) {
		error("missing <samples-dir>");
		error(usage());
		return 2;
	}
	let samplesDirIsDirectory = false;
	try {
		samplesDirIsDirectory = statSync(options.samplesDir).isDirectory();
	} catch {}
	if (!samplesDirIsDirectory) {
		error(`samples dir not found: ${options.samplesDir} — pass the directory containing the paired run samples`);
		return 2;
	}
	const report = (dependencies.verifyFromFiles ?? verifyFromFiles)(
		(dependencies.loadManifest ?? loadManifest)(options.manifest),
		options.samplesDir,
	);
	output(renderReport(report));
	for (const problem of report.problems) error(`  - ${problem}`);
	if (!report.passed) {
		error("Remediation: fix each listed problem (or replay excluded pairs within the budget), then rerun verify. Do not weaken the manifest gates.");
		return 1;
	}
	return 0;
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
	process.exitCode = main(process.argv.slice(2));
}
