#!/usr/bin/env node

import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { existsSync, lstatSync, mkdirSync, readFileSync, readdirSync, realpathSync, statSync, writeFileSync } from "node:fs";
import { basename, dirname, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import {
	compareDocuments,
	fingerprintArtifact,
} from "./skill-eval.mjs";
import {
	fingerprintEvaluatorBundle,
	fingerprintEvaluatorFile,
	hashManifestBytes,
	isSha256,
} from "./evaluator-bundle.mjs";
import { normalizeEvents, piEventCoverage, campaignUsage } from "./harness-token-usage.mjs";

const REQUIRED_CATEGORIES = new Set([
	"answer",
	"planning",
	"implementation",
	"review",
	"failure_diagnosis",
	"self_improvement",
	"protected_route",
]);
const RUNTIME_KEYS = ["runner", "provider", "model", "effort", "runtime_fingerprint"];
const OFFLINE_SEAMS = new Set(["no_op", "context_selection", "skill_tool_routing", "failure_triage"]);
const COUNT_KEYS = [
	"input_tokens",
	"output_tokens",
	"cached_input_tokens",
	"cache_write_input_tokens",
	"total_tokens",
];
const SECRET_LIKE = /(?:-----BEGIN [A-Z ]+ PRIVATE KEY-----|\b(?:api[_-]?key|access[_-]?token|client[_-]?secret|password)\s*[:=]|\bsk-[A-Za-z0-9_-]{12,})/i;

const isCount = (value) => Number.isSafeInteger(value) && value >= 0;
const isMoney = (value) => typeof value === "number" && Number.isFinite(value) && value >= 0;
const isNonEmptyString = (value) => typeof value === "string" && value.length > 0;
const LIVE_EFFORTS = new Set(["off", "minimal", "low", "medium", "high", "xhigh", "max"]);

function fail(message) {
	throw new Error(message);
}

export function validateCampaignManifest(manifest) {
	const contract = manifest?.campaign_contract;
	if (!contract || contract.schema_version !== 1) fail("campaign_contract.schema_version must be 1");
	if (contract.final_repetitions !== 3) fail("campaign_contract.final_repetitions must be 3");
	if (contract.target_savings_percent !== 30 || contract.stretch_savings_percent !== 50) {
		fail("campaign savings thresholds must remain target=30 and stretch=50");
	}
	if (contract.max_offline_hypotheses !== 4 || contract.max_live_candidates !== 2) {
		fail("campaign budgets must remain four offline hypotheses and two live candidates");
	}
	if (contract.execution_population !== "private_ignored") {
		fail("campaign execution population must remain private_ignored");
	}
	if (contract.public_manifest_is_sealed !== false) {
		fail("the public structural manifest must not claim sealed isolation");
	}
	const categories = new Set();
	for (const task of manifest?.tasks ?? []) {
		if (!REQUIRED_CATEGORIES.has(task.category)) fail(`unsupported task category: ${task.category ?? "missing"}`);
		if (typeof task.protected !== "boolean") fail(`task ${task.id ?? "unknown"} needs protected boolean`);
		categories.add(task.category);
	}
	for (const category of REQUIRED_CATEGORIES) {
		if (!categories.has(category)) fail(`campaign category is empty: ${category}`);
	}
	const runtimeArtifact = manifest.runtime_artifact;
	if (!runtimeArtifact || !Array.isArray(runtimeArtifact.paths) || runtimeArtifact.paths.length === 0 || !Array.isArray(runtimeArtifact.excludes)) {
		fail("runtime_artifact paths and excludes are required");
	}
	for (const path of [...runtimeArtifact.paths, ...runtimeArtifact.excludes]) {
		if (!isNonEmptyString(path) || path.startsWith("/") || path === ".." || path.startsWith("../") || path.includes("/../")) {
			fail(`runtime_artifact path is unsafe: ${path ?? "missing"}`);
		}
	}
	return contract;
}

function validateCost(value, status, label, { allowNotIncurred = false, calls } = {}) {
	if (status === "measured") {
		if (!isMoney(value)) fail(`${label} must be numeric when cost_status is measured`);
		return;
	}
	if (status === "unavailable") {
		if (value !== null) fail(`${label} must be null when cost_status is unavailable`);
		return;
	}
	if (allowNotIncurred && status === "not_incurred") {
		if (value !== 0 || calls !== 0) fail(`${label} can be not_incurred only for zero calls and zero cost`);
		return;
	}
	fail(`${label.replace(/\.cost_usd$/, "")}.cost_status is invalid`);
}

function validateUsage(usage, label, {allowIncomplete=false}={}) {
	if(allowIncomplete && usage?.measured===false && usage.provenance==="provider_receipt" && usage.total_tokens===null &&
		usage.known_usage && Array.isArray(usage.measurement_errors) && usage.measurement_errors.length) return usage;
	if (usage?.measured !== true || usage?.provenance !== "provider_receipt") {
		fail(`${label} needs measured provider_receipt usage`);
	}
	for (const key of COUNT_KEYS) {
		if (!isCount(usage[key])) fail(`${label}.${key} must be a non-negative integer`);
	}
	if (usage.total_tokens !== usage.input_tokens + usage.output_tokens) {
		fail(`${label}.total_tokens must equal input_tokens + output_tokens`);
	}
	if (usage.total_tokens === 0) fail(`${label}.total_tokens cannot be a zero-only provider receipt`);
	validateCost(usage.cost_usd, usage.cost_status, `${label}.cost_usd`);
	return usage;
}

function validateJev(jev, label) {
	for (const key of ["calls", "input_tokens", "output_tokens", "total_tokens", "latency_ms", "abstentions", "escalations", "retries"]) {
		if (!isCount(jev?.[key])) fail(`${label}.${key} must be a non-negative integer`);
	}
	if (jev.total_tokens !== jev.input_tokens + jev.output_tokens) {
		fail(`${label}.total_tokens must equal input_tokens + output_tokens`);
	}
	validateCost(jev.cost_usd, jev.cost_status, `${label}.cost_usd`, { allowNotIncurred: true, calls: jev.calls });
	if (jev.retries !== 0) fail(`${label}.retries must remain zero`);
	return jev;
}

function validateRun(manifest, manifestSha, evaluatorBundleSha, run, arm) {
	if (run?.schema_version !== 1) fail(`${arm} schema_version must be 1`);
	if (run.arm !== arm) fail(`${arm} arm mismatch`);
	if (run.campaign_id !== manifest.manifest_id) fail(`${arm} campaign_id drift`);
	if (run.manifest_sha256 !== manifestSha) fail(`${arm} manifest_sha256 drift`);
	if (run.evaluator_bundle_sha256 !== evaluatorBundleSha) fail(`${arm} evaluator_bundle_sha256 drift`);
	if (!isSha256(run.artifact_fingerprint)) fail(`${arm} artifact_fingerprint is invalid`);
	if (!isSha256(run.population_fingerprint)) fail(`${arm} population_fingerprint is invalid`);
	for (const key of RUNTIME_KEYS) {
		if (!isNonEmptyString(run.runtime?.[key])) fail(`${arm} runtime.${key} is required`);
	}
	if (run.runtime.candidate_enabled !== (arm === "candidate")) {
		fail(`${arm} runtime.candidate_enabled is invalid`);
	}
	const repetitions = run.repetitions;
	if (!Array.isArray(repetitions) || repetitions.length !== manifest.campaign_contract.final_repetitions) {
		fail(`${arm} must contain exactly ${manifest.campaign_contract.final_repetitions} repetitions`);
	}
	const expectedTasks = new Map(manifest.tasks.map((task) => [task.id, task]));
	for (const [index, repetition] of repetitions.entries()) {
		if (repetition.repetition !== index + 1) fail(`${arm} repetitions must be ordered 1..3`);
		if (!Array.isArray(repetition.tasks) || repetition.tasks.length !== expectedTasks.size) {
			fail(`${arm} repetition ${index + 1} task population mismatch`);
		}
		const seen = new Set();
		for (const task of repetition.tasks) {
			const declared = expectedTasks.get(task.task_id);
			if (!declared || seen.has(task.task_id)) fail(`${arm} repetition ${index + 1} has unknown or duplicate task`);
			seen.add(task.task_id);
			if (typeof task.passed !== "boolean") fail(`${arm}/${task.task_id} needs boolean passed`);
			if (task.protected !== declared.protected) fail(`${arm}/${task.task_id} protected flag drift`);
			if (declared.protected && task.passed !== true) fail(`${arm}/${task.task_id} protected route failed`);
			validateUsage(task.traditional_llm, `${arm}/${task.task_id}/traditional_llm`);
			validateJev(task.jev, `${arm}/${task.task_id}/jev`);
			if (!isCount(task.latency_ms)) fail(`${arm}/${task.task_id}.latency_ms must be measured`);
		}
	}
	return run;
}

function sumTasks(run, selector) {
	return run.repetitions.map((repetition) =>
		repetition.tasks.reduce((total, task) => total + selector(task), 0));
}

function passVector(repetition) {
	return repetition.tasks.map((task) => `${task.task_id}:${task.passed}`).join("|");
}

function aggregateCost(tasks, selector) {
	const entries = tasks.map(selector);
	if (entries.some((entry) => entry.cost_status === "unavailable")) {
		return { cost_usd: null, cost_status: "unavailable" };
	}
	return {
		cost_usd: entries.reduce((sum, entry) => sum + entry.cost_usd, 0),
		cost_status: entries.some((entry) => entry.cost_status === "measured") ? "measured" : "not_incurred",
	};
}

function toSkillEvalResult(manifest, run, manifestSha, evaluatorBundleSha) {
	return {
		schema_version: 2,
		manifest_id: manifest.manifest_id,
		manifest_sha256: manifestSha,
		evaluator_sha256: manifest.evaluator.sha256,
		evaluator_bundle_sha256: evaluatorBundleSha,
		artifact_fingerprint: run.artifact_fingerprint,
		outcomes: manifest.tasks.map((task) => ({
			task_id: task.id,
			passed: run.repetitions.every((repetition) =>
				repetition.tasks.find((entry) => entry.task_id === task.id)?.passed === true),
		})),
		measurement: {
			population: manifest.objective.measurement_population,
			metric: "total_tokens",
			value: sumTasks(run, (task) => task.traditional_llm.total_tokens).reduce((a, b) => a + b, 0),
			sample_count: run.repetitions.length * manifest.tasks.length,
		},
	};
}

export function compareCampaignDocuments({ manifest, manifestSha, evaluatorBundleSha, evaluatorFileSha, baseline, candidate }) {
	const contract = validateCampaignManifest(manifest);
	if([baseline,candidate].some(run=>run?.status==="non_comparable" || run?.repetitions?.some(rep=>rep.tasks?.some(task=>task.traditional_llm?.measured===false))))
		return {schema_version:1,status:"non_comparable",verdict:"inconclusive",manifest_id:manifest.manifest_id,
			manifest_sha256:manifestSha,repetitions:[],reasons:["incomplete_provider_evidence"],promotion:false};
	validateRun(manifest, manifestSha, evaluatorBundleSha, baseline, "baseline");
	validateRun(manifest, manifestSha, evaluatorBundleSha, candidate, "candidate");
	if (baseline.population_fingerprint !== candidate.population_fingerprint) fail("baseline and candidate population drift");
	for (const key of RUNTIME_KEYS) {
		if (baseline.runtime[key] !== candidate.runtime[key]) fail(`baseline and candidate runtime.${key} drift`);
	}
	for (let index = 0; index < contract.final_repetitions; index += 1) {
		const baselineIds = baseline.repetitions[index].tasks.map((task) => task.task_id).join("|");
		const candidateIds = candidate.repetitions[index].tasks.map((task) => task.task_id).join("|");
		if (baselineIds !== candidateIds) fail(`repetition ${index + 1} task order drift`);
	}

	const strict = compareDocuments(
		manifest,
		manifestSha,
		toSkillEvalResult(manifest, baseline, manifestSha, evaluatorBundleSha),
		toSkillEvalResult(manifest, candidate, manifestSha, evaluatorBundleSha),
		evaluatorBundleSha,
		evaluatorFileSha,
	);
	const reasons = [...strict.reasons];
	for (const arm of [baseline, candidate]) {
		const vectors = arm.repetitions.map(passVector);
		if (new Set(vectors).size !== 1) reasons.push(`${arm.arm}_quality_vector_unstable`);
	}
	for (let index = 0; index < contract.final_repetitions; index += 1) {
		for (const baselineTask of baseline.repetitions[index].tasks) {
			const candidateTask = candidate.repetitions[index].tasks.find((task) => task.task_id === baselineTask.task_id);
			if (baselineTask.passed && !candidateTask.passed) reasons.push(`quality_regression:${baselineTask.task_id}:rep${index + 1}`);
		}
	}
	const baselineTokens = sumTasks(baseline, (task) => task.traditional_llm.total_tokens);
	const candidateTokens = sumTasks(candidate, (task) => task.traditional_llm.total_tokens);
	const repetitions = baselineTokens.map((value, index) => {
		const savingsPercent = value === 0 ? null : ((value - candidateTokens[index]) / value) * 100;
		if (savingsPercent === null) reasons.push(`baseline_zero_tokens:rep${index + 1}`);
		else if (savingsPercent < contract.target_savings_percent) reasons.push(`target_not_met:rep${index + 1}`);
		return { repetition: index + 1, baseline_tokens: value, candidate_tokens: candidateTokens[index], savings_percent: savingsPercent };
	});
	const uniqueReasons = [...new Set(reasons)];
	const allTasks = (run) => run.repetitions.flatMap((rep) => rep.tasks);
	const jev = (run) => ({
		calls: sumTasks(run, (task) => task.jev.calls).reduce((a, b) => a + b, 0),
		total_tokens: sumTasks(run, (task) => task.jev.total_tokens).reduce((a, b) => a + b, 0),
		...aggregateCost(allTasks(run), (task) => task.jev),
		latency_ms: sumTasks(run, (task) => task.jev.latency_ms).reduce((a, b) => a + b, 0),
		abstentions: sumTasks(run, (task) => task.jev.abstentions).reduce((a, b) => a + b, 0),
		escalations: sumTasks(run, (task) => task.jev.escalations).reduce((a, b) => a + b, 0),
	});
	return {
		schema_version: 1,
		status: "comparable",
		verdict: uniqueReasons.length === 0 ? "accepted" : "rejected",
		manifest_id: manifest.manifest_id,
		manifest_sha256: manifestSha,
		population_fingerprint: baseline.population_fingerprint,
		strict_evaluator: strict,
		repetitions,
		target_savings_percent: contract.target_savings_percent,
		stretch_savings_percent: contract.stretch_savings_percent,
		stretch_met: uniqueReasons.length === 0 && repetitions.every((row) => row.savings_percent >= contract.stretch_savings_percent),
		traditional_llm: {
			baseline: aggregateCost(allTasks(baseline), (task) => task.traditional_llm),
			candidate: aggregateCost(allTasks(candidate), (task) => task.traditional_llm),
		},
		jev: { baseline: jev(baseline), candidate: jev(candidate) },
		reasons: uniqueReasons,
	};
}

function hashJson(value) {
	return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function validateLiveConfig(config) {
	const allowed = new Set([
		"schema_version", "arm", "runner", "provider", "model", "effort", "repetitions",
		"timeout_seconds", "max_cost_usd", "billing_mode", "candidate_enabled", "retry_policy",
	]);
	for (const key of Object.keys(config ?? {})) {
		if (!allowed.has(key)) fail(`live config contains unsupported or sensitive field: ${key}`);
	}
	if (config?.schema_version !== 1 || config.arm !== "baseline" || config.runner !== "pi") {
		fail("live config must select schema_version 1, baseline arm and pi runner");
	}
	for (const key of ["provider", "model", "effort"]) {
		if (!isNonEmptyString(config[key]) || config[key] !== config[key].trim() || /[\s\0]/.test(config[key])) {
			fail(`live config ${key} is invalid`);
		}
	}
	if (config.model.includes("/") && !config.model.startsWith(`${config.provider}/`)) {
		fail("live config model provider prefix contradicts provider");
	}
	if (!LIVE_EFFORTS.has(config.effort)) fail("live config effort is unsupported by Pi");
	if (config.repetitions !== 3) fail("live baseline must contain exactly three repetitions");
	if (!Number.isSafeInteger(config.timeout_seconds) || config.timeout_seconds < 1 || config.timeout_seconds > 3600) {
		fail("live config timeout_seconds must be between 1 and 3600");
	}
	if (typeof config.max_cost_usd !== "number" || !Number.isFinite(config.max_cost_usd) || config.max_cost_usd < 0) {
		fail("live config max_cost_usd must be a non-negative explicit cap");
	}
	if (!new Set(["metered", "subscription"]).has(config.billing_mode)) fail("live config billing_mode is invalid");
	if (config.billing_mode === "subscription" && config.max_cost_usd !== 0) {
		fail("subscription billing_mode requires max_cost_usd 0");
	}
	if (config.candidate_enabled !== false) fail("baseline live config must keep candidate_enabled false");
	if (config.retry_policy !== "none") fail("live config retry_policy must be none");
	return config;
}

export function buildLiveDryRunPlan({ manifest, manifestSha, population, populationFingerprint, state, config, root = "." }) {
	const contract = validateCampaignManifest(manifest);
	if (fingerprintEvaluatorBundle(root, manifest.evaluator.bundle.paths) !== manifest.evaluator.bundle.sha256) {
		fail("evaluator bundle does not match manifest");
	}
	if (fingerprintEvaluatorFile(root, manifest.evaluator.path) !== manifest.evaluator.sha256) {
		fail("evaluator file does not match manifest");
	}
	validatePrivatePopulation(manifest, manifestSha, population, root);
	validateLiveConfig(config);
	if (!isSha256(populationFingerprint)) fail("private population fingerprint is invalid");
	if (state?.private_population_fingerprint !== populationFingerprint) fail("campaign state population fingerprint drift");
	if (state?.offline_validation !== "passed") fail("offline validation must pass before a live baseline dry-run");
	if (state.baseline_runtime_artifact?.status !== "frozen" || state.baseline_runtime_artifact.candidate_enabled !== false || !isSha256(state.baseline_runtime_artifact.fingerprint)) {
		fail("candidate-off baseline runtime artifact must be frozen before a live dry-run");
	}
	if (state?.candidate_runtime_enabled !== false) fail("candidate runtime must remain disabled for baseline");
	if ((state.live_candidates ?? 0) !== 0) fail("baseline dry-run requires zero live candidates");
	const checkpointAuthorized = state.provider_checkpoint === "authorized";
	const argvPrefix = [
		"pi", "--provider", config.provider, "--model", config.model, "--thinking", config.effort,
		"--mode", "json", "--print", "--no-session", "--approve", "--",
	];
	const cells = [];
	for (let repetition = 1; repetition <= contract.final_repetitions; repetition += 1) {
		for (const task of population.tasks) {
			cells.push({
				cell_id: `baseline-r${repetition}-${task.id}`,
				repetition,
				task_id: task.id,
				split: task.split,
				protected: task.protected,
				source_kind: task.source.kind,
				prompt_sha256: createHash("sha256").update(task.source.kind === "private_inline" ? task.source.prompt : readFileSync(resolve(root, task.source.path, "prompt.md"))).digest("hex"),
				argv_prefix: argvPrefix,
				prompt_delivery: "private_positional_argument_not_rendered",
			});
		}
	}
	return {
		schema_version: 1,
		mode: "dry_run_no_provider_egress",
		status: checkpointAuthorized ? "ready_for_explicit_live_command" : "awaiting_provider_authorization",
		executable: checkpointAuthorized,
		campaign_id: manifest.manifest_id,
		manifest_sha256: manifestSha,
		population_fingerprint: populationFingerprint,
		config_fingerprint: hashJson(config),
		runtime: {
			runner: config.runner,
			provider: config.provider,
			model: config.model,
			effort: config.effort,
			candidate_enabled: false,
			retry_policy: "none",
			timeout_seconds: config.timeout_seconds,
			max_cost_usd: config.max_cost_usd,
			billing_mode: config.billing_mode,
		},
		call_budget: { cells: cells.length, repetitions: contract.final_repetitions, tasks_per_repetition: population.tasks.length },
		cells,
	};
}

function privateOutputPath(root, outputPath) {
	const privateRoot = resolve(root, ".workflow/jev-autonomous-efficiency/private");
	const privateStat = lstatSync(privateRoot);
	if (!privateStat.isDirectory() || privateStat.isSymbolicLink() || realpathSync(privateRoot) !== privateRoot) {
		fail("private campaign directory must be a real directory, not a symlink");
	}
	const output = resolve(outputPath);
	const rel = relative(privateRoot, output);
	if (!rel || rel === ".." || rel.startsWith(`..${sep}`) || rel.startsWith(sep) || dirname(output) !== privateRoot) {
		fail("live output must be a new direct child of the private campaign directory");
	}
	if (existsSync(output)) fail("live output path already exists; refusing overwrite or resume");
	return output;
}

function existingPrivateOutputPath(root, outputPath) {
	const privateRoot = resolve(root, ".workflow/jev-autonomous-efficiency/private");
	const privateStat = lstatSync(privateRoot);
	if (!privateStat.isDirectory() || privateStat.isSymbolicLink() || realpathSync(privateRoot) !== privateRoot) fail("private campaign directory must be a real directory, not a symlink");
	const output = resolve(outputPath);
	const rel = relative(privateRoot, output);
	if (!rel || rel === ".." || rel.startsWith(`..${sep}`) || rel.startsWith(sep) || dirname(output) !== privateRoot) fail("resume output must be an existing direct child of the private campaign directory");
	const stat = lstatSync(output);
	if (!stat.isDirectory() || stat.isSymbolicLink() || realpathSync(output) !== output) fail("resume output must be a real directory, not a symlink");
	return output;
}

function excludedRuntimePath(path, excludes) {
	return excludes.some((excluded) => path === excluded || path.startsWith(`${excluded}/`));
}

function copyRuntimeEntry(root, output, path, excludes) {
	if (excludedRuntimePath(path, excludes)) return;
	const source = resolve(root, path);
	const stat = lstatSync(source);
	if (stat.isSymbolicLink()) fail(`runtime artifact source cannot be a symlink: ${path}`);
	const destination = resolve(output, path);
	if (stat.isDirectory()) {
		mkdirSync(destination, { recursive: true });
		for (const entry of readdirSync(source, { withFileTypes: true }).sort((left, right) => left.name.localeCompare(right.name))) {
			copyRuntimeEntry(root, output, `${path}/${entry.name}`, excludes);
		}
		return;
	}
	if (!stat.isFile()) fail(`runtime artifact source must be a file or directory: ${path}`);
	mkdirSync(dirname(destination), { recursive: true });
	writeFileSync(destination, readFileSync(source));
}

export function snapshotRuntimeArtifact({ manifest, manifestSha, candidateEnabled, outputPath, root = "." }) {
	validateCampaignManifest(manifest);
	if (!isSha256(manifestSha)) fail("runtime artifact manifest_sha256 is invalid");
	if (typeof candidateEnabled !== "boolean") fail("runtime artifact candidateEnabled must be boolean");
	const output = privateOutputPath(root, outputPath);
	for (const path of manifest.runtime_artifact.paths) {
		copyRuntimeEntry(resolve(root), output, path, manifest.runtime_artifact.excludes);
	}
	writeFileSync(resolve(output, "runtime-state.json"), `${JSON.stringify({
		schema_version: 1,
		manifest_id: manifest.manifest_id,
		manifest_sha256: manifestSha,
		candidate_enabled: candidateEnabled,
		source_paths: manifest.runtime_artifact.paths,
		excluded_paths: manifest.runtime_artifact.excludes,
	}, null, 2)}\n`);
	return { output, artifact_fingerprint: fingerprintArtifact(output), candidate_enabled: candidateEnabled };
}

function validateRuntimeArtifact(manifest, manifestSha, artifactPath, candidateEnabled) {
	const artifact = resolve(artifactPath);
	const artifactStat = lstatSync(artifact);
	if (!artifactStat.isDirectory() || artifactStat.isSymbolicLink()) fail("live runtime artifact must be a real directory");
	const metadata = readJson(resolve(artifact, "runtime-state.json"), "runtime artifact state");
	if (metadata.schema_version !== 1 || metadata.manifest_id !== manifest.manifest_id || metadata.manifest_sha256 !== manifestSha || metadata.candidate_enabled !== candidateEnabled) {
		fail("live runtime artifact state drift");
	}
	if (JSON.stringify(metadata.source_paths) !== JSON.stringify(manifest.runtime_artifact.paths) || JSON.stringify(metadata.excluded_paths) !== JSON.stringify(manifest.runtime_artifact.excludes)) {
		fail("live runtime artifact inventory drift");
	}
	return fingerprintArtifact(artifact);
}

function parseJsonLines(value) {
	return value.split(/\r?\n/).filter((line) => line.trim()).map((line, index) => {
		try {
			return JSON.parse(line);
		} catch (error) {
			fail(`Pi JSON output line ${index + 1} is invalid: ${error.message}`);
		}
	});
}

const piCoverage = piEventCoverage;

function exactObjectMatch(actual, required) {
	return Object.entries(required).every(([key, value]) =>
		value && typeof value === "object" && !Array.isArray(value)
			? actual?.[key] && exactObjectMatch(actual[key], value)
			: actual?.[key] === value);
}

function gradeInline(task, finalText) {
	if (task.grader.kind === "deterministic_text_contract") {
		const normalized = finalText.toLowerCase();
		return task.grader.required_concepts.every((concept) => normalized.includes(concept.toLowerCase()));
	}
	try {
		const cleaned = finalText.trim().replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "");
		return exactObjectMatch(JSON.parse(cleaned), task.grader.required);
	} catch {
		return false;
	}
}

function prepareHarnessCell(root, task, worktree) {
	const harnessTask = basename(task.source.path);
	const script = 'set -euo pipefail; HARNESS_ROOT="$1"; source "$1/scripts/lib/etabli-harness-eval.sh"; harness_prepare_worktree "$2" "$3"';
	const prepared = spawnSync("bash", ["-c", script, "jev-live-prepare", root, harnessTask, worktree], { encoding: "utf8" });
	if (prepared.status !== 0) fail(`failed to prepare harness task ${harnessTask}: ${prepared.stderr || prepared.stdout}`);
	return harnessTask;
}

function gradeHarnessCell(root, taskId, worktree, transcript, runnerExit) {
	const graded = spawnSync(resolve(root, "scripts/etabli-harness-eval"), [
		"grade", "--task", taskId, "--worktree", worktree, "--transcript", transcript,
		"--runner", "pi", "--runner-exit", String(runnerExit),
	], { encoding: "utf8" });
	if (graded.status !== 0) fail(`harness grader failed for ${taskId}: ${graded.stderr || graded.stdout}`);
	try {
		return JSON.parse(graded.stdout).pass === true;
	} catch (error) {
		fail(`harness grader output is invalid for ${taskId}: ${error.message}`);
	}
}

export function baselineChildEnvironment(env) {
	const childEnv = { ...env, PI_SKIP_VERSION_CHECK: "1" };
	delete childEnv.TYPESAFE_API_KEY;
	return childEnv;
}

export function runPiBaselineCell({ root, task, cell, config, output, env }) {
	const cellDirectory = resolve(output, cell.cell_id);
	const worktree = resolve(cellDirectory, "worktree");
	mkdirSync(cellDirectory);
	let harnessTask = null;
	if (task.source.kind === "existing_harness_task") harnessTask = prepareHarnessCell(root, task, worktree);
	else mkdirSync(worktree);
	const prompt = task.source.kind === "private_inline"
		? task.source.prompt
		: readFileSync(resolve(root, task.source.path, "prompt.md"), "utf8");
	const argv = [...cell.argv_prefix.slice(1), prompt];
	const childEnv = baselineChildEnvironment(env);
	const started = Date.now();
	const completed = spawnSync(cell.argv_prefix[0], argv, {
		cwd: worktree,
		env: childEnv,
		encoding: "utf8",
		timeout: config.timeout_seconds * 1000,
		maxBuffer: 32 * 1024 * 1024,
	});
	const latency = Date.now() - started;
	writeFileSync(resolve(cellDirectory,"exit.json"),JSON.stringify({exit_code:completed.status??1,latency_ms:latency}));
	writeFileSync(resolve(cellDirectory, "events.jsonl"), completed.stdout ?? "");
	writeFileSync(resolve(cellDirectory, "stderr.txt"), completed.stderr ?? "");
	const events = parseJsonLines(completed.stdout ?? "");
	const coverage = piCoverage(events);
	if (coverage.retry.status !== "not_triggered") fail(`${cell.cell_id} observed a provider retry`);
	const normalized = normalizeEvents("pi", events, { exitCode: completed.status ?? 1, coverage });
	writeFileSync(resolve(cellDirectory, "normalized.json"), `${JSON.stringify(normalized, null, 2)}\n`);
	const expectedModel = config.model.includes("/") ? config.model : `${config.provider}/${config.model}`;
	if (!normalized.models.includes(expectedModel)) fail(`${cell.cell_id} effective model does not match ${expectedModel}`);
	const transcript = resolve(cellDirectory, "transcript.txt");
	writeFileSync(transcript, normalized.final_text);
	const passed = harnessTask
		? gradeHarnessCell(root, harnessTask, worktree, transcript, completed.status ?? 1)
		: gradeInline(task, normalized.final_text);
	const result = {
		task_id: task.id,
		protected: task.protected,
		passed: passed && normalized.transport_success===true,
		latency_ms: latency,
		traditional_llm: campaignUsage(normalized),
		jev: { calls: 0, input_tokens: 0, output_tokens: 0, total_tokens: 0, cost_usd: 0, cost_status: "not_incurred", latency_ms: 0, abstentions: 0, escalations: 0, retries: 0 },
	};
	writeFileSync(resolve(cellDirectory,"cell-result.json"),`${JSON.stringify(result,null,2)}\n`);
	return result;
}

export function loadCompletedBaselineCell({ root, task, cell, config, resumeOutput }) {
	const cellDirectory = resolve(resumeOutput, cell.cell_id);
	if (!existsSync(cellDirectory)) return null;
	const cellStat = lstatSync(cellDirectory);
	if (!cellStat.isDirectory() || cellStat.isSymbolicLink() || realpathSync(cellDirectory) !== cellDirectory) fail(`${cell.cell_id} resume cell must be a real directory`);
	const eventsPath = resolve(cellDirectory, "events.jsonl");
	const normalizedPath = resolve(cellDirectory, "normalized.json");
	const transcript = resolve(cellDirectory, "transcript.txt");
	for (const path of [eventsPath, normalizedPath, transcript]) {
		if (!existsSync(path) || !lstatSync(path).isFile() || lstatSync(path).isSymbolicLink()) fail(`${cell.cell_id} resume evidence is incomplete`);
	}
	const events = parseJsonLines(readFileSync(eventsPath, "utf8"));
	const coverage = piCoverage(events);
	if (coverage.retry.status !== "not_triggered") fail(`${cell.cell_id} resume evidence observed a provider retry`);
	const exitPath=resolve(cellDirectory,"exit.json");
	if(existsSync(exitPath)&&(!lstatSync(exitPath).isFile()||lstatSync(exitPath).isSymbolicLink()))fail(`${cell.cell_id} invalid resume exit evidence`);
	const exitEvidence=existsSync(exitPath)?JSON.parse(readFileSync(exitPath,"utf8")):{exit_code:0};
	if(!Number.isSafeInteger(exitEvidence.exit_code))fail(`${cell.cell_id} invalid resume exit code`);
	const normalized = normalizeEvents("pi", events, {exitCode:exitEvidence.exit_code,coverage});
	const stored = JSON.parse(readFileSync(normalizedPath, "utf8"));
	if(hashJson(normalized)!==hashJson(stored))fail(`${cell.cell_id} resume normalization drift`);

	const expectedModel = config.model.includes("/") ? config.model : `${config.provider}/${config.model}`;
	if (!normalized.models?.includes(expectedModel)) fail(`${cell.cell_id} resume model does not match ${expectedModel}`);
	if (readFileSync(transcript, "utf8") !== normalized.final_text) fail(`${cell.cell_id} resume transcript drift`);
	const sessionStarted = Date.parse(events.find((event) => event.type === "session")?.timestamp ?? "");
	if (!Number.isFinite(sessionStarted)) fail(`${cell.cell_id} resume session timestamp is missing`);
	const latency = Math.max(0, Math.round(statSync(eventsPath).mtimeMs - sessionStarted));
	const passed = task.source.kind === "private_inline"
		? gradeInline(task, normalized.final_text)
		: gradeHarnessCell(root, basename(task.source.path), resolve(cellDirectory, "worktree"), transcript, 0);
	return {
		task_id: task.id, protected: task.protected, passed:passed && normalized.transport_success===true, latency_ms: latency,
		traditional_llm: campaignUsage(normalized),
		jev: { calls: 0, input_tokens: 0, output_tokens: 0, total_tokens: 0, cost_usd: 0, cost_status: "not_incurred", latency_ms: 0, abstentions: 0, escalations: 0, retries: 0 },
	};
}

export function executeLiveBaseline({ manifest, manifestSha, population, populationFingerprint, state, config, artifactPath, outputPath, resumeOutputPath, root = ".", env = process.env, cellExecutor = runPiBaselineCell }) {
	const plan = buildLiveDryRunPlan({ manifest, manifestSha, population, populationFingerprint, state, config, root });
	if (!plan.executable) fail("provider checkpoint is not authorized");
	if (env.ETABLI_JEV_EFFICIENCY_LIVE !== "1") fail("ETABLI_JEV_EFFICIENCY_LIVE=1 is required for provider execution");
	const artifactFingerprint = validateRuntimeArtifact(manifest, manifestSha, artifactPath, false);
	if (state.baseline_runtime_artifact?.fingerprint !== artifactFingerprint) fail("campaign state baseline runtime artifact drift");
	const output = privateOutputPath(root, outputPath);
	const resumeOutput = resumeOutputPath ? existingPrivateOutputPath(root, resumeOutputPath) : null;
	const executionIdentity={schema_version:1,manifest_sha256:manifestSha,population_fingerprint:populationFingerprint,
		artifact_fingerprint:artifactFingerprint,config_fingerprint:plan.config_fingerprint};
	if(resumeOutput) {
		const identityPath=resolve(resumeOutput,"execution-identity.json");
		if(!existsSync(identityPath)||!lstatSync(identityPath).isFile()||lstatSync(identityPath).isSymbolicLink()||
			hashJson(JSON.parse(readFileSync(identityPath,"utf8")))!==hashJson(executionIdentity))fail("resume execution identity is missing or stale");
	}
	mkdirSync(output);
	writeFileSync(resolve(output,"execution-identity.json"),JSON.stringify(executionIdentity),{mode:0o600,flag:"wx"});
	let observedCost = 0;
	const repetitions = [];
	let incomplete=false;
	collection: for (let repetition = 1; repetition <= config.repetitions; repetition += 1) {
		const tasks = [];
		for (const task of population.tasks) {
			const cell = plan.cells.find((entry) => entry.repetition === repetition && entry.task_id === task.id);
			const result = resumeOutput
				? loadCompletedBaselineCell({ root: resolve(root), task, cell, config, resumeOutput }) ?? cellExecutor({ root: resolve(root), task, cell, config, output, env })
				: cellExecutor({ root: resolve(root), task, cell, config, output, env });
			validateUsage(result.traditional_llm, `${cell.cell_id}/traditional_llm`, {allowIncomplete:true});
			validateJev(result.jev, `${cell.cell_id}/jev`);
			if (typeof result.passed !== "boolean" || result.protected !== task.protected || !isCount(result.latency_ms)) {
				fail(`${cell.cell_id} returned an invalid deterministic grade`);
			}
			if(result.traditional_llm.measured===false) {
				tasks.push(result);repetitions.push({repetition,tasks});incomplete=true;break collection;
			}
			if (task.protected && !result.passed) fail(`${cell.cell_id} protected route failed`);
			if (config.billing_mode === "metered" && result.traditional_llm.cost_status !== "measured") {
				fail(`${cell.cell_id} cannot enforce the metered cost cap without provider cost telemetry`);
			}
			if (config.billing_mode === "metered" && result.traditional_llm.cost_status === "measured") observedCost += result.traditional_llm.cost_usd;
			if (config.billing_mode === "metered" && observedCost > config.max_cost_usd) fail(`live baseline exceeded max_cost_usd after ${cell.cell_id}`);
			tasks.push(result);
		}
		repetitions.push({ repetition, tasks });
	}
	const result = {
		schema_version: 1,
		arm: "baseline",
		...(incomplete?{status:"non_comparable",stop_reason:"incomplete_provider_evidence"}:{}),
		campaign_id: manifest.manifest_id,
		manifest_sha256: manifestSha,
		evaluator_bundle_sha256: manifest.evaluator.bundle.sha256,
		artifact_fingerprint: artifactFingerprint,
		population_fingerprint: populationFingerprint,
		runtime: {
			runner: config.runner,
			provider: config.provider,
			model: config.model,
			effort: config.effort,
			runtime_fingerprint: hashJson({ runner: config.runner, provider: config.provider, model: config.model, effort: config.effort, candidate_enabled: false }),
			candidate_enabled: false,
		},
		repetitions,
	};
	if(!incomplete)validateRun(manifest, manifestSha, manifest.evaluator.bundle.sha256, result, "baseline");
	writeFileSync(resolve(output, "baseline.json"), `${JSON.stringify(result, null, 2)}\n`);
	return result;
}

export function decideCampaign(manifest, state) {
	const contract = validateCampaignManifest(manifest);
	if (!state || typeof state !== "object") return { decision: "stop", reason: "invalid_state" };
	if (state.terminal) return { decision: "stop", reason: `terminal_${state.terminal}` };
	if ((state.offline_hypotheses ?? 0) > contract.max_offline_hypotheses) return { decision: "stop", reason: "offline_hypothesis_budget_exhausted" };
	if ((state.live_candidates ?? 0) > contract.max_live_candidates) return { decision: "stop", reason: "live_candidate_budget_exhausted" };
	if (!isSha256(state.private_population_fingerprint)) return { decision: "await_private_population", reason: "private_population_not_frozen" };
	if (state.offline_validation !== "passed") return { decision: "run_offline_campaign", reason: "offline_validation_missing" };
	if (state.baseline_runtime_artifact?.status !== "frozen" || state.baseline_runtime_artifact.candidate_enabled !== false || !isSha256(state.baseline_runtime_artifact.fingerprint)) {
		return { decision: "snapshot_baseline_artifact", reason: "candidate_off_runtime_artifact_required" };
	}
	if (state.provider_checkpoint !== "authorized") return { decision: "await_checkpoint", reason: "provider_authorization_required" };
	if (state.candidate_runtime_enabled === true && state.baseline?.status !== "accepted") return { decision: "stop", reason: "candidate_enabled_before_baseline" };
	if (state.baseline?.status !== "accepted" || state.baseline.candidate_enabled !== false || !isSha256(state.baseline.result_fingerprint)) return { decision: "run_baseline", reason: "candidate_off_baseline_required" };
	if (!isSha256(state.observation_fingerprint)) return { decision: "observe", reason: "sanitized_observation_required" };
	if (!state.diagnosis) return { decision: "diagnose_with_jev", reason: "jev_diagnosis_required" };
	if (state.diagnosis.producer !== "jev" || state.diagnosis.valid !== true || !isSha256(state.diagnosis.receipt_fingerprint)) return { decision: "deterministic_fallback", reason: "invalid_jev_diagnosis" };
	if (state.diagnosis.abstained === true) return { decision: "escalate_to_llm", reason: "jev_abstained" };
	if (!state.deduplication || !isSha256(state.deduplication.evidence_fingerprint)) return { decision: "deduplicate", reason: "candidate_deduplication_required" };
	if (state.deduplication.status === "duplicate") return { decision: "reject_candidate", reason: "candidate_duplicate" };
	if (state.deduplication.status !== "unique") return { decision: "stop", reason: "invalid_deduplication_status" };
	if (!isSha256(state.proposal_fingerprint)) return { decision: "propose_candidate", reason: "bounded_proposal_required" };
	if (state.plan_status !== "READY" || !isSha256(state.plan_fingerprint) || state.adversary_verdict !== "GO" || !isSha256(state.adversary_fingerprint)) return { decision: "await_ready_gate", reason: "ready_plan_and_adversary_required" };
	if (state.implementation_status !== "verified" || !isSha256(state.implementation_fingerprint)) return { decision: "implement_bounded_candidate", reason: "candidate_implementation_missing" };
	if (!state.comparison || !isSha256(state.comparison.receipt_fingerprint)) return { decision: "evaluate_candidate", reason: "paired_comparison_required" };
	if (state.comparison.verdict !== "accepted") return { decision: "rollback_required", reason: "candidate_rejected" };
	if (!state.final_validation) return { decision: "run_final_validation", reason: "three_repetitions_required" };
	if (state.final_validation.verdict !== "accepted" || state.final_validation.repetitions !== 3 || !isSha256(state.final_validation.receipt_fingerprint) || state.final_validation.target_savings_percent < contract.target_savings_percent || state.final_validation.protected_preservation_percent !== 100 || state.final_validation.quality_vectors_stable !== true) return { decision: "rollback_required", reason: "final_validation_rejected" };
	return { decision: "completion_ready", reason: "safe_target_verified" };
}

export function rankOfflineHypotheses(manifest, input) {
	validateCampaignManifest(manifest);
	if (input?.schema_version !== 1 || input.manifest_id !== manifest.manifest_id) fail("offline input manifest binding is invalid");
	if (!isSha256(input.population_fingerprint)) fail("offline population_fingerprint is invalid");
	if (!Array.isArray(input.hypotheses) || input.hypotheses.length === 0 || input.hypotheses.length > manifest.campaign_contract.max_offline_hypotheses) {
		fail("offline hypotheses must contain between one and four candidates");
	}
	const expected = new Map(manifest.tasks.map((task) => [task.id, task]));
	const hypothesisIds = new Set();
	const ranked = input.hypotheses.map((hypothesis) => {
		if (!isNonEmptyString(hypothesis.id) || hypothesisIds.has(hypothesis.id)) fail("offline hypothesis ids must be unique");
		hypothesisIds.add(hypothesis.id);
		if (!OFFLINE_SEAMS.has(hypothesis.seam)) fail(`unsupported offline seam: ${hypothesis.seam ?? "missing"}`);
		if (!Array.isArray(hypothesis.results) || hypothesis.results.length !== expected.size) fail(`offline hypothesis ${hypothesis.id} population mismatch`);
		const seen = new Set();
		let accepted = 0;
		let abstentions = 0;
		let escalations = 0;
		const reasons = [];
		for (const result of hypothesis.results) {
			const task = expected.get(result.task_id);
			if (!task || seen.has(result.task_id)) fail(`offline hypothesis ${hypothesis.id} has unknown or duplicate task`);
			seen.add(result.task_id);
			if (result.provider_mode !== "synthetic_fixture") fail(`${hypothesis.id}/${result.task_id} must use synthetic_fixture`);
			if (result.candidate_runtime_enabled !== false) fail(`${hypothesis.id}/${result.task_id} enabled installed candidate runtime`);
			if (result.attempts !== 1) fail(`${hypothesis.id}/${result.task_id} must use one attempt without retry`);
			if (!["accepted", "abstained", "unavailable", "malformed"].includes(result.jev_status)) fail(`${hypothesis.id}/${result.task_id} has invalid Jev status`);
			if (typeof result.quality_passed !== "boolean" || typeof result.protected_preserved !== "boolean") fail(`${hypothesis.id}/${result.task_id} needs deterministic grader outcomes`);
			if (!result.quality_passed) reasons.push(`quality_failed:${result.task_id}`);
			if (task.protected && !result.protected_preserved) reasons.push(`protected_route_failed:${result.task_id}`);
			if (result.jev_status === "accepted") {
				accepted += 1;
				if (result.fallback !== "none") reasons.push(`unexpected_fallback:${result.task_id}`);
			} else {
				if (result.jev_status === "abstained") abstentions += 1;
				if (!["deterministic", "traditional_llm"].includes(result.fallback)) reasons.push(`missing_fallback:${result.task_id}`);
				if (result.fallback === "traditional_llm") escalations += 1;
			}
		}
		return {
			id: hypothesis.id,
			seam: hypothesis.seam,
			eligible: reasons.length === 0,
			accepted,
			abstentions,
			escalations,
			reasons,
		};
	}).sort((left, right) =>
		Number(right.eligible) - Number(left.eligible) ||
		right.accepted - left.accepted ||
		left.escalations - right.escalations ||
		left.id.localeCompare(right.id));
	return {
		schema_version: 1,
		status: "offline_only_no_runtime_savings_claim",
		population_fingerprint: input.population_fingerprint,
		hypotheses_evaluated: ranked.length,
		ranking: ranked,
		next: ranked.some((entry) => entry.eligible) ? "freeze_private_population_then_request_provider_checkpoint" : "reject_all_offline_hypotheses",
	};
}

export function validatePrivatePopulation(manifest, manifestSha, population, root = ".") {
	validateCampaignManifest(manifest);
	if (population?.schema_version !== 1 || population.population_id !== manifest.objective.measurement_population) fail("private population id is invalid");
	if (population.manifest_id !== manifest.manifest_id || population.manifest_sha256 !== manifestSha) fail("private population manifest binding drift");
	if (population.status !== "frozen_validation" || population.sealed_held_out !== false) fail("private validation population must be frozen and explicitly non-sealed");
	if (population.held_out_policy !== "adaptive_after_first_candidate_decision") fail("private held-out policy is invalid");
	if (population.privacy !== "ignored_private_no_secrets") fail("private population privacy label is invalid");
	if (!Array.isArray(population.tasks) || population.tasks.length !== manifest.tasks.length) fail("private population task count mismatch");
	for (let index = 0; index < manifest.tasks.length; index += 1) {
		const declared = manifest.tasks[index];
		const task = population.tasks[index];
		if (task?.id !== declared.id || task.category !== declared.category || task.split !== declared.split || task.protected !== declared.protected) {
			fail(`private population task drift at index ${index}`);
		}
		if (task.source?.kind === "existing_harness_task") {
			if (!/^tests\/fixtures\/harness-v1\/tasks\/[a-z0-9-]+$/.test(task.source.path ?? "")) fail(`${task.id} has unsafe harness source path`);
			if (!isSha256(task.source.artifact_fingerprint) || fingerprintArtifact(resolve(root, task.source.path)) !== task.source.artifact_fingerprint) fail(`${task.id} harness artifact fingerprint drift`);
			if (task.grader?.kind !== "existing_oracle" || task.grader.path !== `${task.source.path}/oracle.sh`) fail(`${task.id} existing oracle binding drift`);
		} else if (task.source?.kind === "private_inline") {
			if (!isNonEmptyString(task.source.prompt) || task.source.prompt.length > 2000 || SECRET_LIKE.test(task.source.prompt)) fail(`${task.id} private prompt is invalid or secret-like`);
			if (task.grader?.kind === "deterministic_text_contract") {
				if (!Array.isArray(task.grader.required_concepts) || task.grader.required_concepts.length === 0 || !task.grader.required_concepts.every(isNonEmptyString)) fail(`${task.id} text grader is invalid`);
			} else if (task.grader?.kind === "deterministic_json_contract") {
				if (!task.grader.required || typeof task.grader.required !== "object" || Array.isArray(task.grader.required)) fail(`${task.id} JSON grader is invalid`);
			} else fail(`${task.id} private grader kind is unsupported`);
		} else fail(`${task.id} source kind is unsupported`);
	}
	return {
		schema_version: 1,
		status: "frozen_validation",
		population_id: population.population_id,
		task_count: population.tasks.length,
		splits: Object.fromEntries(["held_in", "held_out", "safety"].map((split) => [split, population.tasks.filter((task) => task.split === split).length])),
		sealed_held_out: false,
	};
}

function parseArgs(argv) {
	const [command, ...rest] = argv;
	const options = {};
	for (let index = 0; index < rest.length; index += 1) {
		const key = rest[index];
		if (!key.startsWith("--") || !rest[index + 1]) fail("invalid arguments");
		options[key.slice(2)] = rest[++index];
	}
	return { command, options };
}

function readJson(path, label) {
	try {
		return JSON.parse(readFileSync(resolve(path), "utf8"));
	} catch (error) {
		fail(`${label} is not valid JSON: ${error.message}`);
	}
}

function usage() {
	return "Usage: jev-efficiency-campaign compare --manifest PATH --baseline PATH --candidate PATH --baseline-artifact DIR --candidate-artifact DIR [--evaluator-root DIR]\n       jev-efficiency-campaign validate-population --manifest PATH --population PATH [--evaluator-root DIR]\n       jev-efficiency-campaign rank-offline --manifest PATH --input PATH\n       jev-efficiency-campaign snapshot-live-artifact --manifest PATH --output DIR --candidate-enabled true|false [--evaluator-root DIR]\n       jev-efficiency-campaign dry-run-live --manifest PATH --population PATH --state PATH --config PATH [--evaluator-root DIR]\n       jev-efficiency-campaign run-live-baseline --manifest PATH --population PATH --state PATH --config PATH --artifact DIR --output DIR [--resume-output DIR] [--evaluator-root DIR]\n       jev-efficiency-campaign next --manifest PATH --state PATH";
}

function main() {
	try {
		const { command, options } = parseArgs(process.argv.slice(2));
		if (command === "validate-population") {
			if (!options.manifest || !options.population) fail(usage());
			const manifestBytes = readFileSync(resolve(options.manifest));
			const populationBytes = readFileSync(resolve(options.population));
			const result = validatePrivatePopulation(JSON.parse(manifestBytes), hashManifestBytes(manifestBytes), JSON.parse(populationBytes), resolve(options["evaluator-root"] ?? "."));
			process.stdout.write(`${JSON.stringify({ ...result, population_fingerprint: hashManifestBytes(populationBytes) }, null, 2)}\n`);
			return;
		}
		if (command === "rank-offline") {
			if (!options.manifest || !options.input) fail(usage());
			process.stdout.write(`${JSON.stringify(rankOfflineHypotheses(readJson(options.manifest, "manifest"), readJson(options.input, "input")), null, 2)}\n`);
			return;
		}
		if (command === "next") {
			if (!options.manifest || !options.state) fail(usage());
			process.stdout.write(`${JSON.stringify(decideCampaign(readJson(options.manifest, "manifest"), readJson(options.state, "state")), null, 2)}\n`);
			return;
		}
		if (command === "snapshot-live-artifact") {
			for (const key of ["manifest", "output", "candidate-enabled"]) {
				if (!options[key]) fail(`--${key} is required`);
			}
			if (!["true", "false"].includes(options["candidate-enabled"])) fail("--candidate-enabled must be true or false");
			const manifestBytes = readFileSync(resolve(options.manifest));
			const result = snapshotRuntimeArtifact({
				manifest: JSON.parse(manifestBytes),
				manifestSha: hashManifestBytes(manifestBytes),
				candidateEnabled: options["candidate-enabled"] === "true",
				outputPath: resolve(options.output),
				root: resolve(options["evaluator-root"] ?? "."),
			});
			process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
			return;
		}
		if (command === "dry-run-live") {
			for (const key of ["manifest", "population", "state", "config"]) {
				if (!options[key]) fail(`--${key} is required`);
			}
			const manifestBytes = readFileSync(resolve(options.manifest));
			const populationBytes = readFileSync(resolve(options.population));
			const population = JSON.parse(populationBytes);
			const result = buildLiveDryRunPlan({
				manifest: JSON.parse(manifestBytes),
				manifestSha: hashManifestBytes(manifestBytes),
				population,
				populationFingerprint: hashManifestBytes(populationBytes),
				state: readJson(options.state, "state"),
				config: readJson(options.config, "config"),
				root: resolve(options["evaluator-root"] ?? "."),
			});
			process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
			return;
		}
		if (command === "run-live-baseline") {
			for (const key of ["manifest", "population", "state", "config", "artifact", "output"]) {
				if (!options[key]) fail(`--${key} is required`);
			}
			const manifestBytes = readFileSync(resolve(options.manifest));
			const populationBytes = readFileSync(resolve(options.population));
			const root = resolve(options["evaluator-root"] ?? ".");
			const result = executeLiveBaseline({
				manifest: JSON.parse(manifestBytes),
				manifestSha: hashManifestBytes(manifestBytes),
				population: JSON.parse(populationBytes),
				populationFingerprint: hashManifestBytes(populationBytes),
				state: readJson(options.state, "state"),
				config: readJson(options.config, "config"),
				artifactPath: resolve(options.artifact),
				outputPath: resolve(options.output),
				resumeOutputPath: options["resume-output"] ? resolve(options["resume-output"]) : undefined,
				root,
			});
			process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
			return;
		}
		if (command !== "compare") fail(usage());
		for (const key of ["manifest", "baseline", "candidate", "baseline-artifact", "candidate-artifact"]) {
			if (!options[key]) fail(`--${key} is required`);
		}
		const manifestBytes = readFileSync(resolve(options.manifest));
		const manifest = JSON.parse(manifestBytes.toString("utf8"));
		const root = resolve(options["evaluator-root"] ?? ".");
		const bundleSha = fingerprintEvaluatorBundle(root, manifest.evaluator.bundle.paths);
		const fileSha = fingerprintEvaluatorFile(root, manifest.evaluator.path);
		if (bundleSha !== manifest.evaluator.bundle.sha256) fail("evaluator bundle does not match manifest");
		if (fileSha !== manifest.evaluator.sha256) fail("evaluator file does not match manifest");
		const baseline = readJson(options.baseline, "baseline");
		const candidate = readJson(options.candidate, "candidate");
		if (baseline.artifact_fingerprint !== fingerprintArtifact(options["baseline-artifact"])) fail("baseline artifact fingerprint mismatch");
		if (candidate.artifact_fingerprint !== fingerprintArtifact(options["candidate-artifact"])) fail("candidate artifact fingerprint mismatch");
		const result = compareCampaignDocuments({
			manifest,
			manifestSha: hashManifestBytes(manifestBytes),
			evaluatorBundleSha: bundleSha,
			evaluatorFileSha: fileSha,
			baseline,
			candidate,
		});
		process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
		process.exitCode = result.verdict === "accepted" ? 0 : 1;
	} catch (error) {
		process.stdout.write(`${JSON.stringify({ schema_version: 1, status: "non_comparable", verdict: "rejected", reasons: [error.message] }, null, 2)}\n`);
		process.exitCode = 2;
	}
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) main();
